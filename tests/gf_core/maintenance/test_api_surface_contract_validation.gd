## 验证 API Surface Contract 的可执行校验规则。
extends GutTest


# --- 常量 ---

const VALID_FULL_EXAMPLE_PATH: String = "res://tests/gf_core/fixtures/api_surface/valid_full_example.gd"
const SOURCE_ROOT: String = "res://addons/gf"
const MIGRATION_MARKER: String = "# @api_surface_migration partial"
const PLACEHOLDER_SINCE_VERSION: String = "1.0.0"
const DOC_RENDER_SEPARATOR: String = "[br]"
const SECTION_PREFIX: String = "# --- "
const SECTION_SUFFIX: String = " ---"
const API_TAGS: Array[String] = [
	"public",
	"protected",
	"framework_internal",
	"layer_internal",
]
const PUBLIC_API_TAGS: Array[String] = [
	"public",
	"protected",
]
const INTERNAL_API_TAGS: Array[String] = [
	"framework_internal",
	"layer_internal",
	"private",
]
const CLASS_KINDS: Array[String] = [
	"class_name",
	"class",
]
const VALID_CATEGORIES: Array[String] = [
	"runtime_service",
	"runtime_handle",
	"domain_model",
	"resource_definition",
	"value_object",
	"protocol",
	"event_contract",
	"editor_api",
	"tool_api",
	"internal_helper",
]
const RAW_STRUCTURAL_TYPES: Array[String] = [
	"Dictionary",
	"Array",
	"Variant",
]
const BUILTIN_TYPES: Array[String] = [
	"bool",
	"int",
	"float",
	"String",
	"StringName",
	"Node",
	"Object",
	"Resource",
	"RefCounted",
	"void",
]
const PROTECTED_SECTION_MARKERS: Array[String] = [
	"虚方法",
	"可重写",
	"hook",
	"hooks",
	"protected",
	"virtual",
]
const NODE_COMPATIBLE_BASE_TYPES: Array[String] = [
	"Node",
	"Node2D",
	"Node3D",
	"Control",
	"CanvasItem",
	"Window",
	"EditorPlugin",
	"EditorInspectorPlugin",
	"EditorExportPlugin",
	"EditorImportPlugin",
	"EditorProperty",
	"EditorResourcePicker",
	"Container",
	"BoxContainer",
	"HBoxContainer",
	"VBoxContainer",
	"TabContainer",
	"Panel",
	"PanelContainer",
	"Button",
	"Label",
	"LineEdit",
	"TextureRect",
	"Area2D",
	"Area3D",
	"CharacterBody2D",
	"CharacterBody3D",
	"Camera2D",
	"Camera3D",
	"Marker2D",
	"Marker3D",
	"AudioStreamPlayer",
	"Timer",
	"AnimationPlayer",
]
const CANONICAL_SECTION_ORDER: Array[String] = [
	"信号",
	"枚举",
	"常量",
	"导出变量",
	"公共变量",
	"私有变量",
	"@onready 变量",
	"Godot 生命周期方法",
	"Godot 回调方法",
	"GF 生命周期方法",
	"公共方法",
	"可重写钩子 / 虚方法",
	"框架内部方法",
	"层内方法",
	"私有/辅助方法",
	"信号处理函数",
	"内部类",
]
const SECTION_NAME_ALIASES: Dictionary = {
	"虚方法": "可重写钩子 / 虚方法",
	"可重写钩子": "可重写钩子 / 虚方法",
}
const GODOT_CALLBACK_NAMES: Dictionary = {
	"_draw": true,
	"_enter_tree": true,
	"_exit_tree": true,
	"_get": true,
	"_get_property_list": true,
	"_gui_input": true,
	"_input": true,
	"_notification": true,
	"_physics_process": true,
	"_process": true,
	"_ready": true,
	"_set": true,
	"_shortcut_input": true,
	"_to_string": true,
	"_unhandled_input": true,
	"_unhandled_key_input": true,
	"_validate_property": true,
}
const GF_VARIANT_ACCESS = preload("res://addons/gf/kernel/core/gf_variant_access.gd")


# --- 测试用例 ---

func test_full_valid_example_satisfies_api_surface_contract() -> void:
	var issues: Array[String] = _collect_api_surface_issues(_read_text(VALID_FULL_EXAMPLE_PATH), VALID_FULL_EXAMPLE_PATH)

	assert_eq(issues, [], "完整 API Surface 正例应满足严格契约：\n%s" % _join_lines(issues))


func test_gf_source_files_satisfy_or_mark_api_surface_migration() -> void:
	var script_paths: Array[String] = _collect_gdscript_files(SOURCE_ROOT)
	assert_gt(script_paths.size(), 0, "API Surface 源码扫描必须能发现 addons/gf 下的脚本。")
	var type_visibility: Dictionary = _collect_all_type_visibility(script_paths)
	var type_inheritance: Dictionary = _collect_all_type_inheritance(script_paths)
	var issues: Array[String] = []
	for path: String in script_paths:
		issues.append_array(_collect_api_surface_issues_with_type_visibility(_read_text(path), path, type_visibility, type_inheritance))

	assert_eq(
		issues,
		[],
		"GF 源码必须满足 API Surface Contract；未完成迁移的历史文件必须保留 %s，完成后必须移除：\n%s" % [
			MIGRATION_MARKER,
			_join_lines(issues),
		]
	)


func test_gf_source_does_not_use_placeholder_since_version() -> void:
	var script_paths: Array[String] = _collect_gdscript_files(SOURCE_ROOT)
	var issues: Array[String] = []
	for path: String in script_paths:
		issues.append_array(_collect_placeholder_since_issues(_read_text(path), path))

	assert_eq(
		issues,
		[],
		"GF 源码不应继续使用迁移占位 @since %s；历史迁移完成后的 API 以当前发布版本起算：\n%s" % [
			PLACEHOLDER_SINCE_VERSION,
			_join_lines(issues),
		]
	)


func test_gf_source_api_doc_tags_use_godot_render_separator() -> void:
	var script_paths: Array[String] = _collect_gdscript_files(SOURCE_ROOT)
	var issues: Array[String] = []
	for path: String in script_paths:
		issues.append_array(_collect_doc_tag_render_separator_issues(_read_text(path), path))

	assert_eq(
		issues,
		[],
		"GF API 文档的人读说明和机器标签之间应使用 %s 分隔，避免 Godot 悬停文档粘连：\n%s" % [
			DOC_RENDER_SEPARATOR,
			_join_lines(issues),
		]
	)


func test_private_doc_comments_are_rejected() -> void:
	var source: String = """
## 私有方法不应进入 API 文档。
##
## @api private
func _normalize() -> void:
	pass
"""

	_assert_invalid(source, "private members must not use ##")


func test_public_function_requires_doc_comment() -> void:
	var source: String = """
class_name GFInvalidMissingDoc
extends RefCounted

func configure(value: int) -> bool:
	return value > 0
"""

	_assert_invalid(source, "missing API doc")


func test_public_function_params_and_return_must_match_signature() -> void:
	var source: String = """
## 示例类型。
##
## @api public
## @category protocol
## @since 1.0.0
class_name GFInvalidParamDocs
extends RefCounted

## 配置值。
##
## @api public
## @param wrong_name: 错误参数名。
func configure(value: int) -> bool:
	return value > 0
"""

	_assert_invalid(source, "missing @param for 'value'")
	_assert_invalid(source, "missing @return")


func test_protected_api_requires_underscore_and_hook_section() -> void:
	var source: String = """
## 示例类型。
##
## @api public
## @category protocol
## @since 1.0.0
class_name GFInvalidProtectedSection
extends RefCounted

# --- 公共方法 ---

## 公开区里的 protected 方法是违规的。
##
## @api protected
## @return: 值。
func build_value() -> int:
	return 1
"""

	_assert_invalid(source, "protected API must use an underscore name")
	_assert_invalid(source, "protected API must be placed in a hook or virtual section")


func test_dictionary_signature_requires_schema() -> void:
	var source: String = """
## 示例类型。
##
## @api public
## @category protocol
## @since 1.0.0
class_name GFInvalidMissingSchema
extends RefCounted

# --- 公共方法 ---

## 构建数据。
##
## @api public
## @param payload: 载荷。
## @return: 输出载荷。
func build(payload: Dictionary) -> Dictionary:
	return payload
"""

	_assert_invalid(source, "missing @schema for 'payload'")
	_assert_invalid(source, "missing @schema for return")


func test_options_dictionary_parameter_requires_schema() -> void:
	var source: String = """
## 示例类型。
##
## @api public
## @category protocol
## @since 1.0.0
class_name GFInvalidOptionsSchema
extends RefCounted

# --- 公共方法 ---

## 执行操作。
##
## @api public
## @param options: 可选参数。
func run(options: Dictionary = {}) -> void:
	pass
"""

	_assert_invalid(source, "missing @schema for 'options'")


func test_public_signature_cannot_expose_internal_types() -> void:
	var source: String = """
## 内部令牌。
##
## @api framework_internal
class GFInternalToken:
	extends RefCounted

## 示例类型。
##
## @api public
## @category protocol
## @since 1.0.0
class_name GFInvalidInternalExposure
extends RefCounted

# --- 公共方法 ---

## 获取内部令牌。
##
## @api public
## @return: 内部令牌。
func get_token() -> GFInternalToken:
	return GFInternalToken.new()
"""

	_assert_invalid(source, "public API exposes internal type GFInternalToken")


func test_public_signature_cannot_expose_internal_types_from_other_files() -> void:
	var internal_source: String = """
## 跨文件内部令牌。
##
## @api framework_internal
class_name GFCrossFileInternalToken
extends RefCounted
"""
	var public_source: String = """
## 示例类型。
##
## @api public
## @category protocol
## @since 1.0.0
class_name GFInvalidCrossFileInternalExposure
extends RefCounted

# --- 公共方法 ---

## 获取内部令牌。
##
## @api public
## @return: 内部令牌。
func get_token() -> GFCrossFileInternalToken:
	return null
"""
	var type_visibility: Dictionary = _collect_type_visibility(_parse_declarations(internal_source, "res://addons/gf/kernel/core/gf_cross_file_internal_token.gd"))
	var issues: Array[String] = _collect_api_surface_issues_with_type_visibility(
		public_source,
		"res://addons/gf/kernel/core/gf_invalid_cross_file_internal_exposure.gd",
		type_visibility
	)

	assert_true(
		_issues_contain(issues, "public API exposes internal type GFCrossFileInternalToken"),
		"公开 API 不得暴露跨文件内部类型，实际问题：\n%s" % _join_lines(issues)
	)


func test_public_and_protected_signatures_cannot_expose_private_script_constants() -> void:
	var source: String = """
const _RESOURCE_BROKER_SCRIPT = preload("res://addons/gf/standard/utilities/assets/gf_resource_broker.gd")

## 示例类型。
##
## @api public
## @category protocol
## @since 1.0.0
class_name GFInvalidPrivateScriptExposure
extends RefCounted

# --- 公共方法 ---

## 设置资源代理。
##
## @api public
## @param broker: 资源代理。
func set_broker(broker: _RESOURCE_BROKER_SCRIPT) -> void:
	pass

# --- 可重写钩子 / 虚方法 ---

## 获取资源代理。
##
## @api protected
## @return: 资源代理。
func _get_broker() -> _RESOURCE_BROKER_SCRIPT:
	return null
"""

	_assert_invalid(source, "set_broker public API exposes internal type _RESOURCE_BROKER_SCRIPT")
	_assert_invalid(source, "_get_broker public API exposes internal type _RESOURCE_BROKER_SCRIPT")


func test_private_script_constant_types_remain_allowed_inside_internal_method_bodies() -> void:
	var source: String = """
const _RESOURCE_BROKER_SCRIPT = preload("res://addons/gf/standard/utilities/assets/gf_resource_broker.gd")

## 示例类型。
##
## @api public
## @category runtime_service
## @since 1.0.0
class_name GFValidPrivateScriptImplementation
extends RefCounted

# --- 公共方法 ---

## 创建公开类型的资源代理。
##
## @api public
## @return: 资源代理。
func make_broker() -> GFResourceBroker:
	var broker: _RESOURCE_BROKER_SCRIPT = _RESOURCE_BROKER_SCRIPT.new()
	return broker

# --- 私有/辅助方法 ---

func _make_private_broker(value: _RESOURCE_BROKER_SCRIPT) -> _RESOURCE_BROKER_SCRIPT:
	var local_broker: _RESOURCE_BROKER_SCRIPT = value
	return local_broker
"""

	var issues: Array[String] = _collect_api_surface_issues(source, "<inline>")
	assert_eq(
		issues,
		[],
		"私有 script constant 可用于实现体和普通内部方法，但不得进入公开签名：\n%s" % _join_lines(issues)
	)


func test_layer_internal_requires_layer_tag() -> void:
	var source: String = """
## 示例类型。
##
## @api public
## @category protocol
## @since 1.0.0
class_name GFInvalidLayerInternal
extends RefCounted

# --- 层内方法 ---

## 恢复层内状态。
##
## @api layer_internal
func restore_state() -> void:
	pass
"""

	_assert_invalid(source, "layer_internal API must declare @layer")


func test_layer_tag_must_match_source_path() -> void:
	var source: String = """
## 示例类型。
##
## @api public
## @category protocol
## @since 1.0.0
class_name GFInvalidLayerPath
extends RefCounted

# --- 层内方法 ---

## 恢复层内状态。
##
## @api layer_internal
## @layer kernel/core
func restore_state() -> void:
	pass
"""
	var issues: Array[String] = _collect_api_surface_issues(source, "res://addons/gf/standard/common/gf_invalid_layer_path.gd")
	assert_true(
		_issues_contain(issues, "does not match source path"),
		"@layer 必须和源码路径匹配，实际问题：\n%s" % _join_lines(issues)
	)


func test_public_class_requires_category_and_since() -> void:
	var source: String = """
## 缺少分类和版本。
##
## @api public
class_name GFInvalidPublicClassHeader
extends RefCounted
"""

	_assert_invalid(source, "public class must declare @category")
	_assert_invalid(source, "public class must declare @since")


func test_migration_marker_allows_incomplete_file_during_migration() -> void:
	var source: String = """
# @api_surface_migration partial
class_name GFMarkedIncompleteAPI
extends RefCounted

func configure(value: int) -> bool:
	return value > 0
"""

	var issues: Array[String] = _collect_api_surface_issues(source, "<inline>")
	assert_eq(issues, [], "迁移标记允许历史文件暂时保留未完成项。")


func test_migration_marker_must_be_removed_after_file_is_complete() -> void:
	var source: String = """
# @api_surface_migration partial
## 已完成的公开类型。
##
## @api public
## @category protocol
## @since 1.0.0
class_name GFMarkedCompleteAPI
extends RefCounted

# --- 公共方法 ---

## 配置值。
##
## @api public
## @param value: 输入值。
## @return: 是否接受。
func configure(value: int) -> bool:
	return value > 0
"""

	_assert_invalid(source, "stale API surface migration marker")


func test_doc_comment_migration_marker_does_not_suppress_contract_errors() -> void:
	var source: String = """
## @api_surface_migration partial
class_name GFInvalidDocMarker
extends RefCounted

func configure(value: int) -> bool:
	return value > 0
"""

	_assert_invalid(source, "missing API doc")


func test_declarations_inside_multiline_strings_are_ignored() -> void:
	var source: String = """
## 模板生成器。
##
## @api public
## @category editor_api
## @since 1.0.0
class_name GFTemplateSource
extends RefCounted

# --- 公共方法 ---

## 构建模板文本。
##
## @api public
## @return: 模板文本。
func build() -> String:
	var template: String = \"\"\"## Generated: TODO.
class_name GFIgnoredGeneratedClass
extends RefCounted

func generated_without_docs() -> void:
	pass
\"\"\"
	return template
"""

	var issues: Array[String] = _collect_api_surface_issues(source, "<inline>")
	assert_eq(issues, [], "多行字符串中的模板声明不应参与 API Surface 校验：\n%s" % _join_lines(issues))


func test_doc_comments_must_bind_to_declarations() -> void:
	var source: String = """
## 悬空脚本文档不会绑定到任何 API。

# --- 公共方法 ---

func _private_helper() -> void:
	pass
"""

	_assert_invalid(source, "orphan API doc comment")


func test_unknown_documented_api_construct_is_rejected_until_contract_supports_it() -> void:
	var source: String = """
## 假设未来语言新增的声明形态。
##
## @api public
record FutureData:
	pass
"""

	_assert_invalid(source, "documented API construct is not supported")


func test_onready_requires_node_compatible_base_type() -> void:
	var source: String = """
## 非 Node 类型。
##
## @api public
## @category runtime_service
## @since 1.0.0
class_name GFInvalidOnreadyOwner
extends RefCounted

# --- @onready 变量 ---

@onready var _owner_node: Node = null
"""

	_assert_invalid(source, "@onready requires a Node-compatible base type")


func test_public_top_level_api_requires_class_name() -> void:
	var source: String = """
extends RefCounted

# --- 公共方法 ---

## 公开函数不能挂在匿名脚本上。
##
## @api public
func run() -> void:
	pass
"""

	_assert_invalid(source, "public top-level API requires class_name")


func test_api_sections_must_use_canonical_names_and_order() -> void:
	var invalid_name_source: String = """
## 示例类型。
##
## @api public
## @category protocol
## @since 1.0.0
class_name GFInvalidSectionName
extends RefCounted

# --- 获取方法 ---

## 获取值。
##
## @api public
## @return: 值。
func get_value() -> int:
	return 1
"""
	var invalid_order_source: String = """
## 示例类型。
##
## @api public
## @category protocol
## @since 1.0.0
class_name GFInvalidSectionOrder
extends RefCounted

# --- 公共方法 ---

## 获取值。
##
## @api public
## @return: 值。
func get_value() -> int:
	return 1

# --- 常量 ---

## 默认值。
##
## @api public
const DEFAULT_VALUE: int = 1
"""

	_assert_invalid(invalid_name_source, "unknown API section")
	_assert_invalid(invalid_order_source, "API section order")


func test_nested_structural_types_require_schema() -> void:
	var source: String = """
## 示例类型。
##
## @api public
## @category protocol
## @since 1.0.0
class_name GFInvalidNestedSchema
extends RefCounted

# --- 公共方法 ---

## 获取记录。
##
## @api public
## @return: 记录列表。
func get_records() -> Array[Dictionary]:
	return []
"""

	_assert_invalid(source, "missing @schema for return")


func test_public_enum_values_require_doc_comments() -> void:
	var source: String = """
## 示例类型。
##
## @api public
## @category protocol
## @since 1.0.0
class_name GFInvalidEnumDocs
extends RefCounted

# --- 枚举 ---

## 模式。
##
## @api public
enum Mode {
	FAST,
}
"""

	_assert_invalid(source, "public enum value 'FAST' missing doc comment")


# --- 私有/辅助方法 ---

func _assert_invalid(source: String, expected_fragment: String) -> void:
	var issues: Array[String] = _collect_api_surface_issues(source, "<inline>")
	assert_true(
		_issues_contain(issues, expected_fragment),
		"应包含违规片段 '%s'，实际问题：\n%s" % [expected_fragment, _join_lines(issues)]
	)


func _collect_api_surface_issues(source: String, path: String) -> Array[String]:
	var declarations: Array[Dictionary] = _parse_declarations(source, path)
	var type_visibility: Dictionary = _collect_type_visibility(declarations)
	var type_inheritance: Dictionary = _collect_file_type_inheritance(source)
	return _collect_api_surface_issues_with_type_visibility(source, path, type_visibility, type_inheritance)


func _collect_api_surface_issues_with_type_visibility(
	source: String,
	path: String,
	type_visibility: Dictionary,
	type_inheritance: Dictionary = {}
) -> Array[String]:
	var declarations: Array[Dictionary] = _parse_declarations(source, path)
	var allows_top_level_public_api: bool = _has_top_level_class_name(declarations)
	if not allows_top_level_public_api:
		allows_top_level_public_api = _is_node_compatible_type(_collect_top_level_extends(source), type_inheritance)
	var strict_issues: Array[String] = []
	strict_issues.append_array(_collect_file_structure_issues(source, path, type_inheritance))
	for declaration: Dictionary in declarations:
		strict_issues.append_array(_collect_declaration_issues(declaration, type_visibility, allows_top_level_public_api))

	if _source_has_migration_marker(source):
		if strict_issues.is_empty():
			return ["%s stale API surface migration marker; remove %s" % [path, MIGRATION_MARKER]]
		return []
	return strict_issues


func _source_has_migration_marker(source: String) -> bool:
	var lines: PackedStringArray = source.split("\n")
	for raw_line: String in lines:
		if _trim_cr(raw_line).strip_edges() == MIGRATION_MARKER:
			return true
	return false


func _collect_placeholder_since_issues(source: String, path: String) -> Array[String]:
	var issues: Array[String] = []
	var lines: PackedStringArray = source.split("\n")
	for line_index: int in range(lines.size()):
		var line: String = _trim_cr(String(lines[line_index])).strip_edges()
		if not line.begins_with("##"):
			continue
		if _doc_body(line) == "@since %s" % PLACEHOLDER_SINCE_VERSION:
			issues.append("%s:%d @since %s is a migration placeholder; use the current GF release version" % [
				path,
				line_index + 1,
				PLACEHOLDER_SINCE_VERSION,
			])
	return issues


func _collect_doc_tag_render_separator_issues(source: String, path: String) -> Array[String]:
	var issues: Array[String] = []
	var lines: PackedStringArray = source.split("\n")
	for line_index: int in range(1, lines.size()):
		var raw_line: String = _trim_cr(String(lines[line_index]))
		var trimmed: String = raw_line.strip_edges()
		if not trimmed.begins_with("## @"):
			continue

		var previous_line: String = _trim_cr(String(lines[line_index - 1]))
		var previous_trimmed: String = previous_line.strip_edges()
		if not previous_trimmed.begins_with("##"):
			continue
		if _get_indent_level(previous_line) != _get_indent_level(raw_line):
			continue

		var previous_body: String = _doc_body(previous_trimmed).strip_edges()
		if previous_body.is_empty() or previous_body == DOC_RENDER_SEPARATOR:
			continue
		if previous_body.ends_with(DOC_RENDER_SEPARATOR):
			continue

		issues.append("%s:%d API doc tag should be preceded by %s for Godot tooltip rendering" % [
			path,
			line_index + 1,
			DOC_RENDER_SEPARATOR,
		])
	return issues


func _collect_gdscript_files(root_path: String) -> Array[String]:
	var result: Array[String] = []
	_collect_gdscript_files_recursive(root_path, result)
	result.sort()
	return result


func _collect_gdscript_files_recursive(root_path: String, result: Array[String]) -> void:
	var dir: DirAccess = DirAccess.open(root_path)
	if dir == null:
		return

	var _list_dir_begin_result_798: Variant = dir.list_dir_begin()
	var entry: String = dir.get_next()
	while not entry.is_empty():
		var child_path: String = root_path.path_join(entry)
		if dir.current_is_dir():
			if not entry.begins_with("."):
				_collect_gdscript_files_recursive(child_path, result)
		elif entry.ends_with(".gd"):
			result.append(child_path)
		entry = dir.get_next()
	dir.list_dir_end()


func _collect_all_type_visibility(script_paths: Array[String]) -> Dictionary:
	var result: Dictionary = {}
	for path: String in script_paths:
		var declarations: Array[Dictionary] = _parse_declarations(_read_text(path), path)
		var file_visibility: Dictionary = _collect_type_visibility(declarations)
		for type_name: String in file_visibility.keys():
			result[type_name] = file_visibility[type_name]
	return result


func _collect_all_type_inheritance(script_paths: Array[String]) -> Dictionary:
	var result: Dictionary = {}
	for path: String in script_paths:
		var file_inheritance: Dictionary = _collect_file_type_inheritance(_read_text(path))
		for type_name: String in file_inheritance.keys():
			result[type_name] = file_inheritance[type_name]
	return result


func _collect_file_type_inheritance(source: String) -> Dictionary:
	var type_name: String = _collect_top_level_class_name(source)
	var base_type: String = _collect_top_level_extends(source)
	if type_name.is_empty() or base_type.is_empty():
		return {}
	return {
		type_name: base_type,
	}


func _collect_file_structure_issues(source: String, path: String, type_inheritance: Dictionary = {}) -> Array[String]:
	var issues: Array[String] = []
	issues.append_array(_collect_orphan_doc_issues(source, path))
	issues.append_array(_collect_section_issues(source, path))
	issues.append_array(_collect_onready_issues(source, path, type_inheritance))
	return issues


func _collect_orphan_doc_issues(source: String, path: String) -> Array[String]:
	var issues: Array[String] = []
	var lines: PackedStringArray = source.split("\n")
	var doc_start_by_indent: Dictionary = {}
	var doc_has_api_by_indent: Dictionary = {}
	var function_body_indent: int = -1
	var enum_body_indent: int = -1
	var multiline_string_delimiter: String = ""
	var skip_until_line: int = -1

	for line_index: int in range(lines.size()):
		if line_index <= skip_until_line:
			continue

		var raw_line: String = _trim_cr(String(lines[line_index]))
		var trimmed: String = raw_line.strip_edges()
		var indent: int = _get_indent_level(raw_line)
		var was_in_multiline_string: bool = not multiline_string_delimiter.is_empty()
		multiline_string_delimiter = _update_multiline_string_delimiter(raw_line, multiline_string_delimiter)
		if was_in_multiline_string:
			continue

		if function_body_indent != -1:
			if trimmed.is_empty():
				continue
			if indent > function_body_indent:
				continue
			function_body_indent = -1

		if enum_body_indent != -1:
			if trimmed.is_empty():
				continue
			if indent > enum_body_indent:
				continue
			enum_body_indent = -1

		if trimmed.begins_with("##"):
			if not doc_start_by_indent.has(indent):
				doc_start_by_indent[indent] = line_index + 1
				doc_has_api_by_indent[indent] = false
			if _doc_body(trimmed).begins_with("@api"):
				doc_has_api_by_indent[indent] = true
			continue

		if trimmed.is_empty():
			continue

		var section_name: String = _parse_section_name(trimmed)
		if not section_name.is_empty():
			if doc_start_by_indent.has(indent):
				_append_unbound_doc_issue(
					issues,
					path,
					GF_VARIANT_ACCESS.get_option_int(doc_start_by_indent, indent, 0),
					GF_VARIANT_ACCESS.get_option_bool(doc_has_api_by_indent, indent, false)
				)
				var _erase_result_904: Variant = doc_start_by_indent.erase(indent)
				var _erase_result_905: Variant = doc_has_api_by_indent.erase(indent)
			continue

		var signature: Dictionary = _collect_declaration_signature(lines, line_index)
		var declaration: Dictionary = _parse_declaration(GF_VARIANT_ACCESS.get_option_string(signature, "text", ""))
		if not declaration.is_empty():
			var _erase_result_911: Variant = doc_start_by_indent.erase(indent)
			var _erase_result_912: Variant = doc_has_api_by_indent.erase(indent)
			if GF_VARIANT_ACCESS.get_option_string(declaration, "kind") == "func":
				function_body_indent = indent
			elif GF_VARIANT_ACCESS.get_option_string(declaration, "kind") == "enum":
				enum_body_indent = indent
			skip_until_line = GF_VARIANT_ACCESS.get_option_int(signature, "end_line", line_index)
			continue

		if doc_start_by_indent.has(indent):
			_append_unbound_doc_issue(
				issues,
				path,
				GF_VARIANT_ACCESS.get_option_int(doc_start_by_indent, indent, 0),
				GF_VARIANT_ACCESS.get_option_bool(doc_has_api_by_indent, indent, false)
			)
			var _erase_result_927: Variant = doc_start_by_indent.erase(indent)
			var _erase_result_928: Variant = doc_has_api_by_indent.erase(indent)

	for indent_variant: Variant in doc_start_by_indent.keys():
		_append_unbound_doc_issue(
			issues,
			path,
			GF_VARIANT_ACCESS.get_option_int(doc_start_by_indent, indent_variant, 0),
			GF_VARIANT_ACCESS.get_option_bool(doc_has_api_by_indent, indent_variant, false)
		)
	return issues


func _append_unbound_doc_issue(issues: Array[String], path: String, line: int, has_api_tag: bool) -> void:
	if has_api_tag:
		issues.append("%s:%d documented API construct is not supported by API Surface Contract" % [path, line])
	else:
		issues.append("%s:%d orphan API doc comment must bind to a declaration" % [path, line])


func _collect_onready_issues(source: String, path: String, type_inheritance: Dictionary) -> Array[String]:
	var issues: Array[String] = []
	var base_type: String = _collect_top_level_extends(source)
	var lines: PackedStringArray = source.split("\n")
	var multiline_string_delimiter: String = ""
	for line_index: int in range(lines.size()):
		var raw_line: String = _trim_cr(String(lines[line_index]))
		var trimmed: String = raw_line.strip_edges()
		var was_in_multiline_string: bool = not multiline_string_delimiter.is_empty()
		multiline_string_delimiter = _update_multiline_string_delimiter(raw_line, multiline_string_delimiter)
		if was_in_multiline_string:
			continue

		if not trimmed.begins_with("@onready "):
			continue
		if _get_indent_level(raw_line) != 0:
			continue
		if _is_node_compatible_type(base_type, type_inheritance):
			continue
		issues.append("%s:%d @onready requires a Node-compatible base type, got '%s'" % [
			path,
			line_index + 1,
			base_type if not base_type.is_empty() else "<none>",
		])
	return issues


func _collect_section_issues(source: String, path: String) -> Array[String]:
	var issues: Array[String] = []
	var lines: PackedStringArray = source.split("\n")
	var last_order_by_indent: Dictionary = {}
	var multiline_string_delimiter: String = ""
	for line_index: int in range(lines.size()):
		var raw_line: String = _trim_cr(String(lines[line_index]))
		var trimmed: String = raw_line.strip_edges()
		var was_in_multiline_string: bool = not multiline_string_delimiter.is_empty()
		multiline_string_delimiter = _update_multiline_string_delimiter(raw_line, multiline_string_delimiter)
		if was_in_multiline_string:
			continue

		if trimmed.begins_with(SECTION_PREFIX):
			var section_name: String = _parse_section_name(trimmed)
			if section_name.is_empty():
				issues.append("%s:%d malformed API section header" % [path, line_index + 1])
				continue

			var canonical_name: String = _canonical_section_name(section_name)
			var order: int = CANONICAL_SECTION_ORDER.find(canonical_name)
			if order == -1:
				issues.append("%s:%d unknown API section '%s'" % [path, line_index + 1, section_name])
				continue

			var indent: int = _get_indent_level(raw_line)
			var last_order: int = -1
			if last_order_by_indent.has(indent):
				last_order = GF_VARIANT_ACCESS.get_option_int(last_order_by_indent, indent, -1)
			if order < last_order:
				issues.append("%s:%d API section order places '%s' after a later section" % [path, line_index + 1, section_name])
			last_order_by_indent[indent] = order
			continue

		var signature: Dictionary = _collect_declaration_signature(lines, line_index)
		var declaration: Dictionary = _parse_declaration(GF_VARIANT_ACCESS.get_option_string(signature, "text", ""))
		if declaration.is_empty():
			continue
		var kind: String = GF_VARIANT_ACCESS.get_option_string(declaration, "kind", "")
		if kind == "class" or kind == "class_name":
			var declaration_indent: int = _get_indent_level(raw_line)
			for indent_variant: Variant in last_order_by_indent.keys():
				if GF_VARIANT_ACCESS.to_int(indent_variant) > declaration_indent:
					var _erase_result_1017: Variant = last_order_by_indent.erase(indent_variant)
	return issues


func _collect_top_level_class_name(source: String) -> String:
	return _collect_top_level_declaration_identifier(source, "class_name ")


func _collect_top_level_extends(source: String) -> String:
	return _collect_top_level_declaration_identifier(source, "extends ")


func _collect_top_level_declaration_identifier(source: String, prefix: String) -> String:
	var lines: PackedStringArray = source.split("\n")
	var multiline_string_delimiter: String = ""
	for raw_line: String in lines:
		var line: String = _trim_cr(raw_line)
		var trimmed: String = line.strip_edges()
		var was_in_multiline_string: bool = not multiline_string_delimiter.is_empty()
		multiline_string_delimiter = _update_multiline_string_delimiter(line, multiline_string_delimiter)
		if was_in_multiline_string:
			continue
		if _get_indent_level(line) != 0:
			continue
		if trimmed.begins_with(prefix):
			return _read_identifier(trimmed.substr(prefix.length()).strip_edges())
	return ""


func _is_node_compatible_type(type_name: String, type_inheritance: Dictionary, visited: Dictionary = {}) -> bool:
	if type_name.is_empty():
		return false
	if NODE_COMPATIBLE_BASE_TYPES.has(type_name):
		return true
	if visited.has(type_name):
		return false
	visited[type_name] = true
	if not type_inheritance.has(type_name):
		return false
	return _is_node_compatible_type(GF_VARIANT_ACCESS.get_option_string(type_inheritance, type_name), type_inheritance, visited)


func _canonical_section_name(section_name: String) -> String:
	var normalized: String = section_name.strip_edges()
	normalized = normalized.replace("（", "(").replace("）", ")")
	var paren_index: int = normalized.find("(")
	if paren_index != -1:
		normalized = normalized.substr(0, paren_index).strip_edges()
	if SECTION_NAME_ALIASES.has(normalized):
		return GF_VARIANT_ACCESS.get_option_string(SECTION_NAME_ALIASES, normalized)
	return normalized


func _parse_declarations(source: String, path: String) -> Array[Dictionary]:
	var lines: PackedStringArray = source.split("\n")
	var declarations: Array[Dictionary] = []
	var doc_lines_by_indent: Dictionary = {}
	var section_by_indent: Dictionary = {}
	var function_body_indent: int = -1
	var enum_body_indent: int = -1
	var multiline_string_delimiter: String = ""
	var skip_until_line: int = -1

	for line_index: int in range(lines.size()):
		if line_index <= skip_until_line:
			continue

		var raw_line: String = _trim_cr(String(lines[line_index]))
		var trimmed: String = raw_line.strip_edges()
		var indent: int = _get_indent_level(raw_line)
		var was_in_multiline_string: bool = not multiline_string_delimiter.is_empty()
		multiline_string_delimiter = _update_multiline_string_delimiter(raw_line, multiline_string_delimiter)
		if was_in_multiline_string:
			continue

		if function_body_indent != -1:
			if trimmed.is_empty():
				continue
			if indent > function_body_indent:
				continue
			function_body_indent = -1

		if enum_body_indent != -1:
			if trimmed.is_empty():
				continue
			if indent > enum_body_indent:
				continue
			enum_body_indent = -1

		if trimmed.begins_with("##"):
			var docs: Array = []
			if doc_lines_by_indent.has(indent):
				docs = GF_VARIANT_ACCESS.get_option_array(doc_lines_by_indent, indent, [])
			docs.append(trimmed)
			doc_lines_by_indent[indent] = docs
			continue

		if trimmed.is_empty():
			continue

		var section_name: String = _parse_section_name(trimmed)
		if not section_name.is_empty():
			section_by_indent[indent] = section_name
			var _erase_result_1120: Variant = doc_lines_by_indent.erase(indent)
			continue

		var signature: Dictionary = _collect_declaration_signature(lines, line_index)
		var declaration: Dictionary = _parse_declaration(GF_VARIANT_ACCESS.get_option_string(signature, "text", ""))
		if not declaration.is_empty():
			var docs: Array = []
			if doc_lines_by_indent.has(indent):
				docs = GF_VARIANT_ACCESS.get_option_array(doc_lines_by_indent, indent, [])
			declaration["path"] = path
			declaration["line"] = line_index + 1
			declaration["indent"] = indent
			declaration["section"] = _get_section_for_indent(section_by_indent, indent)
			declaration["docs"] = docs.duplicate()
			declaration["api"] = _parse_tag_value(docs, "api")
			declaration["category"] = _parse_tag_value(docs, "category")
			declaration["layer"] = _parse_tag_value(docs, "layer")
			declaration["has_since"] = _has_tag(docs, "since")
			declaration["has_return_doc"] = _has_tag(docs, "return")
			declaration["doc_params"] = _parse_named_tags(docs, "param")
			declaration["schemas"] = _parse_named_tags(docs, "schema")
			if GF_VARIANT_ACCESS.get_option_string(declaration, "kind") == "enum":
				declaration["enum_values"] = _collect_enum_values(lines, line_index, indent)
			else:
				declaration["enum_values"] = []
			declarations.append(declaration)
			var _erase_result_1146: Variant = doc_lines_by_indent.erase(indent)
			var declaration_kind: String = GF_VARIANT_ACCESS.get_option_string(declaration, "kind")
			if declaration_kind == "class" or declaration_kind == "class_name":
				for section_indent_variant: Variant in section_by_indent.keys():
					if GF_VARIANT_ACCESS.to_int(section_indent_variant) > indent:
						var _erase_result_1150: Variant = section_by_indent.erase(section_indent_variant)

			if declaration_kind == "func":
				function_body_indent = indent
			elif declaration_kind == "enum":
				enum_body_indent = indent
			skip_until_line = GF_VARIANT_ACCESS.get_option_int(signature, "end_line", line_index)
			continue

		var _erase_result_1159: Variant = doc_lines_by_indent.erase(indent)

	return declarations


func _collect_enum_values(lines: PackedStringArray, enum_line: int, enum_indent: int) -> Array[Dictionary]:
	var values: Array[Dictionary] = []
	var doc_line: int = -1
	for line_index: int in range(enum_line + 1, lines.size()):
		var raw_line: String = _trim_cr(String(lines[line_index]))
		var trimmed: String = raw_line.strip_edges()
		if trimmed.is_empty():
			continue
		var indent: int = _get_indent_level(raw_line)
		if indent <= enum_indent:
			break
		if trimmed.begins_with("##"):
			if doc_line == -1:
				doc_line = line_index + 1
			continue
		if trimmed.begins_with("#"):
			continue
		if trimmed == "}" or trimmed == "},":
			break

		var without_comma: String = trimmed.trim_suffix(",").strip_edges()
		var assignment_index: int = _find_top_level_character(without_comma, "=")
		if assignment_index != -1:
			without_comma = without_comma.substr(0, assignment_index).strip_edges()
		var value_name: String = _read_identifier(without_comma)
		if not value_name.is_empty():
			values.append({
				"name": value_name,
				"line": line_index + 1,
				"has_doc": doc_line != -1,
			})
		doc_line = -1
	return values


func _collect_declaration_signature(lines: PackedStringArray, start_line: int) -> Dictionary:
	var text: String = _trim_cr(String(lines[start_line])).strip_edges()
	var end_line: int = start_line
	if not _can_have_multiline_signature(text):
		return {
			"text": text,
			"end_line": end_line,
		}

	var requires_colon: bool = text.begins_with("func ") or text.begins_with("static func ")
	var paren_depth: int = _get_parenthesis_delta(text)
	if paren_depth <= 0 and (not requires_colon or text.ends_with(":")):
		return {
			"text": text,
			"end_line": end_line,
		}

	for next_line: int in range(start_line + 1, lines.size()):
		var next_text: String = _trim_cr(String(lines[next_line])).strip_edges()
		text += " " + next_text
		paren_depth += _get_parenthesis_delta(next_text)
		end_line = next_line
		if paren_depth <= 0 and (not requires_colon or next_text.ends_with(":")):
			break

	return {
		"text": text,
		"end_line": end_line,
	}


func _can_have_multiline_signature(text: String) -> bool:
	return (
		text.begins_with("func ")
		or text.begins_with("static func ")
		or text.begins_with("signal ")
	)


func _get_parenthesis_delta(text: String) -> int:
	var delta: int = 0
	for index: int in range(text.length()):
		var character: String = text[index]
		if character == "(":
			delta += 1
		elif character == ")":
			delta -= 1
	return delta


func _update_multiline_string_delimiter(line: String, current_delimiter: String) -> String:
	if not current_delimiter.is_empty():
		if line.find(current_delimiter) != -1:
			return ""
		return current_delimiter

	var double_index: int = line.find("\"\"\"")
	var single_index: int = line.find("'''")
	var delimiter: String = ""
	var start_index: int = -1
	if double_index != -1 and (single_index == -1 or double_index < single_index):
		delimiter = "\"\"\""
		start_index = double_index
	elif single_index != -1:
		delimiter = "'''"
		start_index = single_index

	if delimiter.is_empty():
		return ""
	if line.find(delimiter, start_index + delimiter.length()) != -1:
		return ""
	return delimiter


func _parse_declaration(trimmed: String) -> Dictionary:
	if trimmed.begins_with("class_name "):
		return {
			"kind": "class_name",
			"name": _read_identifier(trimmed.substr("class_name ".length()).strip_edges()),
			"type": "",
			"params": [],
			"return_type": "",
		}

	if trimmed.begins_with("class "):
		return {
			"kind": "class",
			"name": _read_identifier(trimmed.substr("class ".length()).strip_edges()),
			"type": "",
			"params": [],
			"return_type": "",
		}

	if trimmed.begins_with("signal "):
		return _parse_signal_declaration(trimmed)

	if trimmed.begins_with("enum "):
		return {
			"kind": "enum",
			"name": _read_identifier(trimmed.substr("enum ".length()).strip_edges()),
			"type": "",
			"params": [],
			"return_type": "",
		}

	if trimmed.begins_with("const "):
		return _parse_value_declaration(trimmed.substr("const ".length()).strip_edges(), "const")

	var var_index: int = trimmed.find("var ")
	if trimmed.begins_with("var ") or var_index != -1:
		return _parse_value_declaration(trimmed.substr(var_index + "var ".length()).strip_edges(), "var")

	if trimmed.begins_with("func ") or trimmed.begins_with("static func "):
		return _parse_function_declaration(trimmed)

	return {}


func _parse_signal_declaration(trimmed: String) -> Dictionary:
	var signature: String = trimmed.substr("signal ".length()).strip_edges()
	var open_index: int = signature.find("(")
	var close_index: int = signature.rfind(")")
	var signal_name: String = signature
	var params: Array[Dictionary] = []
	if open_index != -1:
		signal_name = signature.substr(0, open_index).strip_edges()
		if close_index > open_index:
			params = _parse_params(signature.substr(open_index + 1, close_index - open_index - 1))
	return {
		"kind": "signal",
		"name": signal_name,
		"type": "",
		"params": params,
		"return_type": "",
	}


func _parse_value_declaration(signature: String, kind: String) -> Dictionary:
	var default_index: int = _find_top_level_character(signature, "=")
	var without_default: String = signature
	if default_index != -1:
		without_default = signature.substr(0, default_index).strip_edges()

	var type_name: String = ""
	var member_name: String = without_default
	var type_index: int = _find_top_level_character(without_default, ":")
	if type_index != -1:
		member_name = without_default.substr(0, type_index).strip_edges()
		type_name = without_default.substr(type_index + 1).strip_edges()

	return {
		"kind": kind,
		"name": _read_identifier(member_name),
		"type": type_name,
		"params": [],
		"return_type": "",
	}


func _parse_function_declaration(trimmed: String) -> Dictionary:
	var signature: String = trimmed
	if signature.begins_with("static func "):
		signature = signature.substr("static func ".length()).strip_edges()
	else:
		signature = signature.substr("func ".length()).strip_edges()

	var open_index: int = signature.find("(")
	var close_index: int = signature.rfind(")")
	var function_name: String = signature
	var params: Array[Dictionary] = []
	if open_index != -1:
		function_name = signature.substr(0, open_index).strip_edges()
		if close_index > open_index:
			params = _parse_params(signature.substr(open_index + 1, close_index - open_index - 1))

	var return_type: String = ""
	var arrow_index: int = signature.find("->")
	if arrow_index != -1:
		var return_text: String = signature.substr(arrow_index + "->".length()).strip_edges()
		var colon_index: int = return_text.rfind(":")
		if colon_index != -1:
			return_text = return_text.substr(0, colon_index).strip_edges()
		return_type = return_text

	return {
		"kind": "func",
		"name": function_name,
		"type": "",
		"params": params,
		"return_type": return_type,
	}


func _parse_params(params_text: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if params_text.strip_edges().is_empty():
		return result

	for raw_part: String in _split_top_level_arguments(params_text):
		var part: String = raw_part.strip_edges()
		if part.is_empty():
			continue

		var default_index: int = _find_top_level_character(part, "=")
		var without_default: String = part
		if default_index != -1:
			without_default = part.substr(0, default_index).strip_edges()

		var type_name: String = ""
		var param_name: String = without_default
		var type_index: int = _find_top_level_character(without_default, ":")
		if type_index != -1:
			param_name = without_default.substr(0, type_index).strip_edges()
			type_name = without_default.substr(type_index + 1).strip_edges()

		result.append({
			"name": _read_identifier(param_name),
			"type": type_name,
		})
	return result


func _collect_type_visibility(declarations: Array[Dictionary]) -> Dictionary:
	var result: Dictionary = {}
	for declaration: Dictionary in declarations:
		var kind: String = GF_VARIANT_ACCESS.get_option_string(declaration, "kind", "")
		var type_declaration_name: String = GF_VARIANT_ACCESS.get_option_string(declaration, "name", "")
		if (
			kind == "const"
			and type_declaration_name.begins_with("_")
			and type_declaration_name.ends_with("_SCRIPT")
		):
			result[type_declaration_name] = "private"
			continue
		if not CLASS_KINDS.has(kind) and kind != "enum":
			continue

		var api: String = GF_VARIANT_ACCESS.get_option_string(declaration, "api", "")
		if not api.is_empty():
			result[type_declaration_name] = api
		elif type_declaration_name.begins_with("_"):
			result[type_declaration_name] = "private"
	return result


func _collect_declaration_issues(declaration: Dictionary, type_visibility: Dictionary, allows_top_level_public_api: bool) -> Array[String]:
	var issues: Array[String] = []
	var declaration_name: String = GF_VARIANT_ACCESS.get_option_string(declaration, "name", "")
	var kind: String = GF_VARIANT_ACCESS.get_option_string(declaration, "kind", "")
	var api: String = GF_VARIANT_ACCESS.get_option_string(declaration, "api", "")
	var docs: Array = GF_VARIANT_ACCESS.get_option_array(declaration, "docs", [])
	var location: String = _format_location(declaration)
	var is_private: bool = _is_private_declaration(declaration)

	if not api.is_empty() and not API_TAGS.has(api):
		issues.append("%s %s has invalid @api '%s'" % [location, declaration_name, api])

	if api == "private" or (is_private and not docs.is_empty()):
		issues.append("%s %s private members must not use ## or @api private" % [location, declaration_name])

	if not docs.is_empty() and api.is_empty():
		issues.append("%s %s doc comment missing @api" % [location, declaration_name])

	if docs.is_empty() and _declaration_requires_api_doc(declaration):
		issues.append("%s %s missing API doc" % [location, declaration_name])

	if PUBLIC_API_TAGS.has(api) and GF_VARIANT_ACCESS.get_option_int(declaration, "indent", 0) == 0 and kind != "class_name" and not allows_top_level_public_api:
		issues.append("%s %s public top-level API requires class_name or Node-compatible singleton script" % [location, declaration_name])

	if api == "layer_internal" and GF_VARIANT_ACCESS.get_option_string(declaration, "layer", "").is_empty():
		issues.append("%s %s layer_internal API must declare @layer" % [location, declaration_name])

	var layer: String = GF_VARIANT_ACCESS.get_option_string(declaration, "layer", "")
	if not layer.is_empty() and not _layer_matches_source_path(layer, GF_VARIANT_ACCESS.get_option_string(declaration, "path", "")):
		issues.append("%s %s @layer '%s' does not match source path" % [location, declaration_name, layer])

	if api == "protected":
		if not kind == "func" or not declaration_name.begins_with("_"):
			issues.append("%s %s protected API must use an underscore name" % [location, declaration_name])
		if not _section_has_marker(GF_VARIANT_ACCESS.get_option_string(declaration, "section", ""), PROTECTED_SECTION_MARKERS):
			issues.append("%s %s protected API must be placed in a hook or virtual section" % [location, declaration_name])

	if CLASS_KINDS.has(kind) and api == "public":
		var category: String = GF_VARIANT_ACCESS.get_option_string(declaration, "category", "")
		if category.is_empty():
			issues.append("%s %s public class must declare @category" % [location, declaration_name])
		elif not VALID_CATEGORIES.has(category):
			issues.append("%s %s uses unknown @category '%s'" % [location, declaration_name, category])
		if not GF_VARIANT_ACCESS.get_option_bool(declaration, "has_since", false):
			issues.append("%s %s public class must declare @since" % [location, declaration_name])

	if not api.is_empty() and (kind == "func" or kind == "signal"):
		issues.append_array(_collect_param_doc_issues(declaration))

	if not api.is_empty() and kind == "func":
		issues.append_array(_collect_return_doc_issues(declaration))

	if not api.is_empty():
		issues.append_array(_collect_schema_issues(declaration))

	if PUBLIC_API_TAGS.has(api):
		issues.append_array(_collect_internal_type_exposure_issues(declaration, type_visibility))

	if kind == "enum" and PUBLIC_API_TAGS.has(api):
		issues.append_array(_collect_enum_value_doc_issues(declaration))

	return issues


func _collect_param_doc_issues(declaration: Dictionary) -> Array[String]:
	var issues: Array[String] = []
	var location: String = _format_location(declaration)
	var declaration_name: String = GF_VARIANT_ACCESS.get_option_string(declaration, "name", "")
	var actual_params: PackedStringArray = PackedStringArray()
	var params: Array = GF_VARIANT_ACCESS.get_option_array(declaration, "params", [])
	for param: Dictionary in params:
		var _append_result_1508: Variant = actual_params.append(GF_VARIANT_ACCESS.get_option_string(param, "name", ""))

	var documented_params: PackedStringArray = GF_VARIANT_ACCESS.get_option_packed_string_array(declaration, "doc_params", PackedStringArray())
	for actual_param: String in actual_params:
		if not documented_params.has(actual_param):
			issues.append("%s %s missing @param for '%s'" % [location, declaration_name, actual_param])

	for documented_param: String in documented_params:
		if not actual_params.has(documented_param):
			issues.append("%s %s documents unknown @param '%s'" % [location, declaration_name, documented_param])

	if issues.is_empty() and not _packed_string_arrays_equal(actual_params, documented_params):
		issues.append("%s %s @param order should be [%s] but was [%s]" % [
			location,
			declaration_name,
			", ".join(actual_params),
			", ".join(documented_params),
		])
	return issues


func _collect_return_doc_issues(declaration: Dictionary) -> Array[String]:
	var return_type: String = GF_VARIANT_ACCESS.get_option_string(declaration, "return_type", "")
	if return_type.is_empty():
		return ["%s %s missing return type" % [_format_location(declaration), GF_VARIANT_ACCESS.get_option_string(declaration, "name", "")]]
	if return_type == "void":
		return []
	if GF_VARIANT_ACCESS.get_option_bool(declaration, "has_return_doc", false):
		return []
	return ["%s %s missing @return" % [_format_location(declaration), GF_VARIANT_ACCESS.get_option_string(declaration, "name", "")]]


func _collect_schema_issues(declaration: Dictionary) -> Array[String]:
	var issues: Array[String] = []
	var kind: String = GF_VARIANT_ACCESS.get_option_string(declaration, "kind", "")
	var schemas: PackedStringArray = GF_VARIANT_ACCESS.get_option_packed_string_array(declaration, "schemas", PackedStringArray())
	var location: String = _format_location(declaration)
	var declaration_name: String = GF_VARIANT_ACCESS.get_option_string(declaration, "name", "")

	if kind == "func" or kind == "signal":
		var params: Array = GF_VARIANT_ACCESS.get_option_array(declaration, "params", [])
		for param: Dictionary in params:
			var param_name: String = GF_VARIANT_ACCESS.get_option_string(param, "name", "")
			if _type_requires_schema(GF_VARIANT_ACCESS.get_option_string(param, "type", "")) and not schemas.has(param_name):
				issues.append("%s %s missing @schema for '%s'" % [location, declaration_name, param_name])

	if kind == "func" and _type_requires_schema(GF_VARIANT_ACCESS.get_option_string(declaration, "return_type", "")) and not schemas.has("return"):
		issues.append("%s %s missing @schema for return" % [location, declaration_name])

	if (kind == "var" or kind == "const") and _type_requires_schema(GF_VARIANT_ACCESS.get_option_string(declaration, "type", "")) and not schemas.has(declaration_name):
		issues.append("%s %s missing @schema for '%s'" % [location, declaration_name, declaration_name])

	return issues


func _collect_enum_value_doc_issues(declaration: Dictionary) -> Array[String]:
	var issues: Array[String] = []
	var enum_values: Array = GF_VARIANT_ACCESS.get_option_array(declaration, "enum_values", [])
	for enum_value: Dictionary in enum_values:
		if GF_VARIANT_ACCESS.get_option_bool(enum_value, "has_doc", false):
			continue
		issues.append("%s:%d %s public enum value '%s' missing doc comment" % [
			GF_VARIANT_ACCESS.get_option_string(declaration, "path", ""),
			GF_VARIANT_ACCESS.get_option_int(enum_value, "line", 0),
			GF_VARIANT_ACCESS.get_option_string(declaration, "name", ""),
			GF_VARIANT_ACCESS.get_option_string(enum_value, "name", ""),
		])
	return issues


func _collect_internal_type_exposure_issues(declaration: Dictionary, type_visibility: Dictionary) -> Array[String]:
	var issues: Array[String] = []
	var location: String = _format_location(declaration)
	var declaration_name: String = GF_VARIANT_ACCESS.get_option_string(declaration, "name", "")

	for type_name: String in _collect_referenced_types(declaration):
		if not type_visibility.has(type_name):
			continue
		var visibility: String = GF_VARIANT_ACCESS.get_option_string(type_visibility, type_name, "")
		if INTERNAL_API_TAGS.has(visibility):
			issues.append("%s %s public API exposes internal type %s" % [location, declaration_name, type_name])
	return issues


func _collect_referenced_types(declaration: Dictionary) -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	var kind: String = GF_VARIANT_ACCESS.get_option_string(declaration, "kind", "")
	if kind == "func" or kind == "signal":
		var params: Array = GF_VARIANT_ACCESS.get_option_array(declaration, "params", [])
		for param: Dictionary in params:
			_append_type_names(result, GF_VARIANT_ACCESS.get_option_string(param, "type", ""))
	if kind == "func":
		_append_type_names(result, GF_VARIANT_ACCESS.get_option_string(declaration, "return_type", ""))
	if kind == "var" or kind == "const":
		_append_type_names(result, GF_VARIANT_ACCESS.get_option_string(declaration, "type", ""))
	return result


func _append_type_names(result: PackedStringArray, type_text: String) -> void:
	for type_name: String in _extract_type_names(type_text):
		if type_name.is_empty() or BUILTIN_TYPES.has(type_name):
			continue
		if RAW_STRUCTURAL_TYPES.has(type_name):
			continue
		if not result.has(type_name):
			var _append_result_1613: Variant = result.append(type_name)


func _extract_type_names(type_text: String) -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	var current: String = ""
	for index: int in range(type_text.length()):
		var character: String = type_text[index]
		if _is_identifier_character(character):
			current += character
			continue
		if not current.is_empty():
			var _append_result_1625: Variant = result.append(current)
			current = ""
	if not current.is_empty():
		var _append_result_1628: Variant = result.append(current)
	return result


func _type_requires_schema(type_text: String) -> bool:
	var trimmed: String = type_text.strip_edges()
	if trimmed.is_empty():
		return false
	if RAW_STRUCTURAL_TYPES.has(trimmed):
		return true
	if trimmed.begins_with("Array[") and trimmed.ends_with("]"):
		var inner: String = trimmed.substr("Array[".length(), trimmed.length() - "Array[".length() - 1).strip_edges()
		return _type_requires_schema(inner)
	if trimmed.begins_with("Dictionary["):
		return true
	return false


func _layer_matches_source_path(layer: String, path: String) -> bool:
	var normalized_layer: String = layer.strip_edges()
	var normalized_path: String = path.replace("\\", "/")
	normalized_path = normalized_path.trim_prefix("res://")
	if not normalized_path.begins_with("addons/gf/"):
		return true
	normalized_path = normalized_path.trim_prefix("addons/gf/")
	if normalized_layer == "plugin":
		return normalized_path == "plugin.gd"
	if normalized_path == normalized_layer + ".gd":
		return true
	return normalized_path.begins_with(normalized_layer + "/")


func _has_top_level_class_name(declarations: Array[Dictionary]) -> bool:
	for declaration: Dictionary in declarations:
		if (
			GF_VARIANT_ACCESS.get_option_string(declaration, "kind") == "class_name"
			and GF_VARIANT_ACCESS.get_option_int(declaration, "indent") == 0
		):
			return true
	return false


func _declaration_requires_api_doc(declaration: Dictionary) -> bool:
	var kind: String = GF_VARIANT_ACCESS.get_option_string(declaration, "kind", "")
	if not ["class_name", "class", "signal", "enum", "const", "var", "func"].has(kind):
		return false
	return not _is_private_declaration(declaration)


func _is_private_declaration(declaration: Dictionary) -> bool:
	var declaration_name: String = GF_VARIANT_ACCESS.get_option_string(declaration, "name", "")
	var api: String = GF_VARIANT_ACCESS.get_option_string(declaration, "api", "")
	if api == "protected":
		return false
	if declaration_name == "_init" and not api.is_empty():
		return false
	if declaration_name.begins_with("_"):
		return true
	if GF_VARIANT_ACCESS.get_option_string(declaration, "kind", "") == "func" and GODOT_CALLBACK_NAMES.has(declaration_name):
		return true
	return false


func _parse_tag_value(docs: Array, tag_name: String) -> String:
	var prefix: String = "@%s" % tag_name
	for raw_line: Variant in docs:
		var body: String = _doc_body(GF_VARIANT_ACCESS.to_text(raw_line))
		if body == prefix:
			return ""
		if not body.begins_with(prefix + " "):
			continue
		var rest: String = body.substr(prefix.length() + 1).strip_edges()
		return _read_identifier_or_token(rest)
	return ""


func _has_tag(docs: Array, tag_name: String) -> bool:
	var prefix: String = "@%s" % tag_name
	for raw_line: Variant in docs:
		var body: String = _doc_body(GF_VARIANT_ACCESS.to_text(raw_line))
		if body == prefix or body.begins_with(prefix + " ") or body.begins_with(prefix + ":"):
			return true
	return false


func _parse_named_tags(docs: Array, tag_name: String) -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	var prefix: String = "@%s " % tag_name
	for raw_line: Variant in docs:
		var body: String = _doc_body(GF_VARIANT_ACCESS.to_text(raw_line))
		if not body.begins_with(prefix):
			continue
		var parsed_tag_name: String = _read_identifier(body.substr(prefix.length()).strip_edges())
		if not parsed_tag_name.is_empty():
			var _append_result_1719: Variant = result.append(parsed_tag_name)
	return result


func _doc_body(line: String) -> String:
	var trimmed: String = line.strip_edges()
	if not trimmed.begins_with("##"):
		return trimmed
	return trimmed.substr(2).strip_edges()


func _parse_section_name(line: String) -> String:
	var trimmed: String = line.strip_edges()
	if not trimmed.begins_with(SECTION_PREFIX):
		return ""
	if not trimmed.ends_with(SECTION_SUFFIX):
		return ""
	var start_index: int = SECTION_PREFIX.length()
	var content_length: int = trimmed.length() - SECTION_PREFIX.length() - SECTION_SUFFIX.length()
	if content_length <= 0:
		return ""
	return trimmed.substr(start_index, content_length).strip_edges()


func _get_section_for_indent(section_by_indent: Dictionary, indent: int) -> String:
	var current_indent: int = indent
	while current_indent >= 0:
		if section_by_indent.has(current_indent):
			return GF_VARIANT_ACCESS.get_option_string(section_by_indent, current_indent)
		current_indent -= 1
	return ""


func _get_indent_level(line: String) -> int:
	var result: int = 0
	for index: int in range(line.length()):
		var character: String = line[index]
		if character == "\t":
			result += 1
		elif character == " ":
			result += 1
		else:
			break
	return result


func _read_identifier(text: String) -> String:
	var result: String = ""
	for index: int in range(text.length()):
		var character: String = text[index]
		if _is_identifier_character(character):
			result += character
			continue
		break
	return result


func _read_identifier_or_token(text: String) -> String:
	var result: String = ""
	for index: int in range(text.length()):
		var character: String = text[index]
		if character == " " or character == "\t" or character == ":" or character == "{":
			break
		result += character
	return result.strip_edges()


func _is_identifier_character(character: String) -> bool:
	return (
		(character >= "A" and character <= "Z")
		or (character >= "a" and character <= "z")
		or (character >= "0" and character <= "9")
		or character == "_"
	)


func _split_top_level_arguments(args_text: String) -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	var start_index: int = 0
	for index: int in range(args_text.length()):
		if args_text[index] == "," and _is_top_level_character(args_text, index):
			var _append_result_1800: Variant = result.append(args_text.substr(start_index, index - start_index))
			start_index = index + 1
	var _append_result_1802: Variant = result.append(args_text.substr(start_index))
	return result


func _find_top_level_character(text: String, target: String) -> int:
	for index: int in range(text.length()):
		if text[index] == target and _is_top_level_character(text, index):
			return index
	return -1


func _is_top_level_character(text: String, target_index: int) -> bool:
	var parenthesis_depth: int = 0
	var bracket_depth: int = 0
	var brace_depth: int = 0
	var in_string: bool = false
	var string_quote: String = ""
	for index: int in range(target_index):
		var character: String = text[index]
		if in_string:
			if character == string_quote:
				in_string = false
			continue
		if character == "\"" or character == "'":
			in_string = true
			string_quote = character
		elif character == "(":
			parenthesis_depth += 1
		elif character == ")":
			parenthesis_depth -= 1
		elif character == "[":
			bracket_depth += 1
		elif character == "]":
			bracket_depth -= 1
		elif character == "{":
			brace_depth += 1
		elif character == "}":
			brace_depth -= 1
	return parenthesis_depth == 0 and bracket_depth == 0 and brace_depth == 0


func _section_has_marker(section_name: String, markers: Array[String]) -> bool:
	var lower_section: String = section_name.to_lower()
	for marker: String in markers:
		if lower_section.contains(marker.to_lower()):
			return true
	return false


func _packed_string_arrays_equal(left: PackedStringArray, right: PackedStringArray) -> bool:
	if left.size() != right.size():
		return false
	for index: int in range(left.size()):
		if left[index] != right[index]:
			return false
	return true


func _issues_contain(issues: Array[String], fragment: String) -> bool:
	for issue: String in issues:
		if issue.contains(fragment):
			return true
	return false


func _format_location(declaration: Dictionary) -> String:
	return "%s:%d" % [
		GF_VARIANT_ACCESS.get_option_string(declaration, "path", ""),
		GF_VARIANT_ACCESS.get_option_int(declaration, "line", 0),
	]


func _read_text(path: String) -> String:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	assert_not_null(file, "应能读取文件：%s" % path)
	if file == null:
		return ""
	var text: String = file.get_as_text()
	file.close()
	return text


func _trim_cr(text: String) -> String:
	if text.ends_with("\r"):
		return text.substr(0, text.length() - 1)
	return text


func _join_lines(lines: Array[String]) -> String:
	var packed: PackedStringArray = PackedStringArray()
	for line: String in lines:
		var _append_result_1893: Variant = packed.append(line)
	return "\n".join(packed)
