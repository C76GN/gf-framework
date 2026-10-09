## 验证 API Surface Contract 的可执行校验规则。
extends GutTest


# --- 常量 ---

const VALID_FULL_EXAMPLE_PATH: String = "res://tests/gf_core/fixtures/api_surface/valid_full_example.gd"
const SOURCE_ROOT: String = "res://addons/gf"
const PROJECT_LAYOUT_STRICT_ROOT: String = "res://addons/gf/tools/project_layout/"
const PROJECT_LAYOUT_ANALYZER_PATH: String = "res://addons/gf/tools/project_layout/gf_project_layout_analyzer.gd"
const ASSET_METADATA_UTILITY_PATH: String = "res://addons/gf/extensions/asset_metadata/runtime/gf_asset_metadata_utility.gd"
const GF_AUTOLOAD_OWNER_PATH: String = "res://addons/gf/kernel/core/gf.gd"
const GF_AUTOLOAD_OWNER_KIND: String = "autoload"
const GF_AUTOLOAD_OWNER_NAME: String = "Gf"
const GF_AUTOLOAD_OWNER_BASE_TYPE: String = "Node"
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
	"private",
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
const INTERNAL_SECTION_ENFORCED_ROOTS: Array[String] = [
	"res://addons/gf/kernel/base/",
	"res://addons/gf/kernel/core/",
	"res://addons/gf/extensions/dialogue/",
	PROJECT_LAYOUT_STRICT_ROOT,
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
const CONTRACT_SOURCES = preload("res://tests/gf_core/maintenance/helpers/gf_comment_contract_sources.gd")
const GUT_TEST_SCRIPT = preload("res://addons/gut/test.gd")
const GUT_COLLECTOR_SCRIPT = preload("res://addons/gut/test_collector.gd")


# --- 测试用例 ---

func test_full_valid_example_satisfies_api_surface_contract() -> void:
	var issues: Array[String] = _collect_api_surface_issues(_read_text(VALID_FULL_EXAMPLE_PATH), VALID_FULL_EXAMPLE_PATH)

	assert_eq(issues, [], "完整 API Surface 正例应满足严格契约：\n%s" % _join_lines(issues))


func test_gf_source_and_template_files_satisfy_api_surface_contract() -> void:
	var script_paths: Array[String] = _collect_gdscript_files(SOURCE_ROOT)
	assert_gt(script_paths.size(), 0, "API Surface 源码扫描必须能发现 addons/gf 下的脚本。")
	assert_true(
		script_paths.has(PROJECT_LAYOUT_ANALYZER_PATH),
		"API Surface 全源扫描必须直接读取 live addons/gf 树，并覆盖尚未进入 Git index 的新增 GF 源码。"
	)
	var type_visibility: Dictionary = _collect_all_type_visibility(script_paths)
	var type_inheritance: Dictionary = _collect_all_type_inheritance(script_paths)
	var sources: Dictionary = {}
	for path: String in script_paths:
		sources[path] = _read_text(path)
	var contract_owners: Dictionary = _collect_contract_owners(sources)
	var issues: Array[String] = []
	for path: String in script_paths:
		issues.append_array(_collect_api_surface_issues_with_type_visibility(_read_text(path), path, type_visibility, type_inheritance, contract_owners))

	assert_eq(
		issues,
		[],
		"GF 源码与模板必须满足 API Surface Contract，不允许迁移或覆盖率债务豁免：\n%s" % _join_lines(issues)
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


func test_released_asset_metadata_api_keeps_historical_since_baseline() -> void:
	var expected_since_by_symbol: Dictionary = {
		"write_object_metadata": "3.17.0",
		"has_object_metadata": "3.17.0",
		"collect_node_tree": "3.17.0",
		"collect_node_tree_dicts": "3.17.0",
		"build_node_tree_report": "3.17.0",
		"METADATA_STATE_ABSENT": "8.0.0",
		"METADATA_STATE_EMPTY": "8.0.0",
		"METADATA_STATE_VALID": "8.0.0",
		"get_object_metadata_state": "8.0.0",
	}
	var actual_since_by_symbol: Dictionary = {}
	for declaration: Dictionary in _parse_declarations(
		_read_text(ASSET_METADATA_UTILITY_PATH),
		ASSET_METADATA_UTILITY_PATH
	):
		var symbol_name: String = GF_VARIANT_ACCESS.get_option_string(declaration, "name")
		if not expected_since_by_symbol.has(symbol_name):
			continue
		actual_since_by_symbol[symbol_name] = _parse_tag_value(
			GF_VARIANT_ACCESS.get_option_array(declaration, "docs"),
			"since"
		)

	assert_eq(
		actual_since_by_symbol,
		expected_since_by_symbol,
		"已发布符号的 @since 必须表示首次公开契约基线，不能被后续行为增强版本改写。"
	)


func test_object_pool_lease_migration_preserves_released_api_since_versions() -> void:
	var expected_since_by_path: Dictionary = {
		"res://addons/gf/extensions/combat/projectiles/gf_projectile_emitter_2d.gd": {
			"object_pool_utility": "3.17.0",
		},
		"res://addons/gf/extensions/combat/projectiles/gf_projectile_emitter_3d.gd": {
			"object_pool_utility": "3.17.0",
		},
		"res://addons/gf/standard/utilities/nodes/gf_object_pool_utility.gd": {
			"max_available_per_scene": "3.17.0",
			"dispose": "3.17.0",
			"get_debug_snapshot": "3.17.0",
			"acquire": "8.0.0",
			"prewarm": "8.0.0",
		},
		"res://addons/gf/standard/utilities/nodes/gf_object_pool_prewarm_result.gd": {
			"Status": "11.0.0",
		},
	}
	for path: String in expected_since_by_path:
		var expected_since_by_symbol: Dictionary = GF_VARIANT_ACCESS.get_option_dictionary(expected_since_by_path, path)
		var actual_since_by_symbol: Dictionary = {}
		for declaration: Dictionary in _parse_declarations(_read_text(path), path):
			var symbol_name: String = GF_VARIANT_ACCESS.get_option_string(declaration, "name")
			if GF_VARIANT_ACCESS.get_option_int(declaration, "indent") != 0 or not expected_since_by_symbol.has(symbol_name):
				continue
			actual_since_by_symbol[symbol_name] = _parse_tag_value(
				GF_VARIANT_ACCESS.get_option_array(declaration, "docs"),
				"since"
			)

		assert_eq(
			actual_since_by_symbol,
			expected_since_by_symbol,
			"租约迁移不能把已发布 API 的历史 @since 改成 unreleased：%s" % path
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


func test_private_doc_comments_allow_partial_contracts() -> void:
	var source: String = """
extends Node

# --- 私有变量 ---

## 缓存仅供本文件复用。
## [br]
## @api private
var _cache: Dictionary = {}

# --- Godot 生命周期方法 ---

## 构造时接收缓存选项。
## [br]
## @api private
func _init(options: Dictionary = {}) -> void:
	pass

# --- Godot 回调方法 ---

## 由引擎通知缓存失效。
## [br]
## @api private
func _notification(what: int) -> void:
	pass

# --- 私有/辅助方法 ---

## 只复制需要隔离的请求字段。
## [br]
## @api private
## [br]
## @param options: 当前批次的复制选项。
## [br]
## @schema options: 复制选项字典。
func _normalize(value: Variant, options: Dictionary, fallback: Variant) -> Dictionary:
	return {}

## 返回调用者提供的原值，不复制或保留它。
## [br]
## @api private
func _undocumented(value: Variant) -> Variant:
	return value

# --- 内部类 ---

## 临时游标不参与持久化。
## [br]
## @api private
class _Cursor:
	extends RefCounted
"""
	var issues: Array[String] = _collect_api_surface_issues(source, VALID_FULL_EXAMPLE_PATH)
	assert_eq(issues, [], "私有文档允许只记录必要参数，不强制 since/category/return/schema：\n%s" % _join_lines(issues))


func test_private_doc_comments_require_explicit_single_visibility_and_prose() -> void:
	var source: String = "# --- 私有/辅助方法 ---\n\n%s\nfunc _normalize() -> void:\n\tpass\n"
	for docs: String in [
		"## 维护约束。",
		"## 维护约束。\n## @api private\n## @api private",
		"## 维护约束。\n## @api private\n## @api public",
		"## 维护约束。\n## @api private extra",
		"## 维护约束。\n## @api private\n## @api: public",
		"## 维护约束。\n## @api unknown",
	]:
		_assert_invalid(source % docs, "exactly one valid @api")
	_assert_invalid(source % "## [br]\n## @api private", "private doc must contain explanatory prose")
	_assert_invalid(source % "## 维护约束。\n## @api public", "private members must declare @api private")


func test_private_documentation_supports_member_kinds_and_callback_sections() -> void:
	var source: String = """
extends Node

# --- 信号 ---

## 通知本文件内的批次消费者。
## @api private
## @param payload: 当前批次的值。
signal _changed(serial: int, payload: Dictionary)

# --- 枚举 ---

## 只表示本地工作阶段。
## @api private
enum _Phase {
	IDLE,
	RUNNING,
}

# --- 常量 ---

## 调试窗口的固定容量。
## @api private
const _LIMIT: int = 16

# --- 导出变量 ---

## 编辑器填写，仅供本节点使用。
## @api private
@export var _source: Resource

# --- 私有变量 ---

## 清理后丢弃本批状态。
## @api private
## @schema _state: 以批次编号索引的临时字段。
var _state: Dictionary = {}

# --- @onready 变量 ---

## 就绪后才读取场景树引用。
## @api private
@onready var _parent: Node = get_parent()

# --- Godot 生命周期方法 ---

## 节点就绪后开始接受批次。
## @api private
func _ready() -> void:
	pass

# --- Godot 回调方法 ---

## Inspector 仅处理本工具支持的目标。
## @api private
func _can_handle(object: Object) -> bool:
	return false

# --- 信号处理函数 ---

## 外部信号到达时使本批缓存失效。
## @api private
func _on_changed(payload: Dictionary) -> void:
	pass
"""
	assert_eq(_collect_api_surface_issues(source, VALID_FULL_EXAMPLE_PATH), [], "所有受支持的私有声明按各自语义保留 canonical 分区。")


func test_public_constructor_and_other_api_contracts_keep_complete_validation() -> void:
	var source: String = """
## 公开类型。
## @api public
## @category protocol
## @since 3.17.0
class_name GFPrivateDocConstructor
extends RefCounted

# --- Godot 生命周期方法 ---

## 创建对象。
## @api public
## @param value: 初始值。
func _init(value: int) -> void:
	pass
"""
	assert_eq(_collect_api_surface_issues(source, VALID_FULL_EXAMPLE_PATH), [], "公开构造函数仍使用既有生命周期规则。")
	_assert_invalid(source.replace("## @param value: 初始值。\n", ""), "missing @param for 'value'")
	var internal_source: String = "# --- 框架内部方法 ---\n## 协作入口。\n## @api framework_internal\nfunc run(value: Dictionary) -> Dictionary:\n\treturn value\n"
	_assert_invalid(internal_source, "missing @param for 'value'")
	_assert_invalid(internal_source, "missing @return")
	_assert_invalid(internal_source, "missing @schema for 'value'")


func test_private_visibility_cannot_hide_public_names_or_global_owners() -> void:
	for declaration: String in [
		"func normalize() -> void:\n\tpass",
		"var cache: Dictionary = {}",
		"class Cursor:\n\textends RefCounted",
	]:
		_assert_invalid("## 内部约束。\n## @api private\n" + declaration, "private API must use an underscore name")
	_assert_invalid("## 内部类型。\n## @api private\nclass_name _GlobalCache\nextends RefCounted", "class_name cannot declare @api private")
	_assert_invalid("## 文件说明。\n## @api private\nextends Node", "documented API construct is not supported")
	_assert_invalid("## 悬空说明。\n## @api private", "documented API construct is not supported")


func test_underscore_internal_collaboration_keeps_full_contract_validation() -> void:
	for visibility: String in ["framework_internal", "layer_internal"]:
		var section: String = "框架内部方法" if visibility == "framework_internal" else "层内方法"
		var source: String = """extends RefCounted

# --- %s ---

## 接收协作方传入的批次状态。
## @api %s
## @layer tools/project_layout
## @param state: 当前批次字段。
## @return: 原样返回批次字段。
## @schema state: 调用方持有的批次字典。
## @schema return: 与输入相同的批次字典。
func _accept_state(state: Dictionary) -> Dictionary:
	return state
""" % [section, visibility]
		var path: String = PROJECT_LAYOUT_STRICT_ROOT + "gf_internal_doc_fixture.gd"
		assert_eq(_collect_api_surface_issues(source, path), [], "内部协作可见性不应被下划线前缀覆盖。")
		_assert_invalid(source.replace("## @param state: 当前批次字段。\n", ""), "missing @param for 'state'")
		_assert_invalid(source.replace("## @return: 原样返回批次字段。\n", ""), "missing @return")
		_assert_invalid(source.replace("## @schema state: 调用方持有的批次字典。\n", ""), "missing @schema for 'state'")
		if visibility == "layer_internal":
			_assert_invalid(source.replace("## @layer tools/project_layout\n", ""), "layer_internal API must declare @layer")
		var wrong_section_issues: Array[String] = _collect_api_surface_issues(source.replace(section, "私有/辅助方法"), path)
		assert_false(wrong_section_issues.is_empty(), "内部协作入口仍必须位于相应内部方法分区。")


func test_private_documented_declarations_keep_their_canonical_sections() -> void:
	var cases: Array[Dictionary] = [
		{ "section": "公共方法", "declaration": "func _helper() -> void:\n\tpass" },
		{ "section": "可重写钩子 / 虚方法", "declaration": "func _helper() -> void:\n\tpass" },
		{ "section": "私有/辅助方法", "declaration": "func _init() -> void:\n\tpass" },
		{ "section": "私有/辅助方法", "declaration": "func _ready() -> void:\n\tpass" },
		{ "section": "公共变量", "declaration": "var _cache: Dictionary = {}" },
		{ "section": "私有变量", "declaration": "const _LIMIT: int = 1" },
		{ "section": "私有变量", "declaration": "signal _changed(value: int)" },
		{ "section": "私有变量", "declaration": "enum _State { READY }" },
		{ "section": "私有变量", "declaration": "class _Cache:\n\textends RefCounted" },
	]
	for test_case: Dictionary in cases:
		var source: String = "# --- %s ---\n\n## 维护约束。\n## @api private\n%s" % [test_case["section"], test_case["declaration"]]
		_assert_invalid(source, "private API uses an incompatible section")


func test_private_optional_params_reject_invalid_partial_documentation() -> void:
	var source: String = "# --- 私有/辅助方法 ---\n\n## 维护约束。\n## @api private\n%s\nfunc _normalize(first: int, second: int, third: int) -> void:\n\tpass\n"
	var cases: Dictionary = {
		"## @param missing: 未知参数。": "unknown @param",
		"## @param second:": "non-empty description",
		"## @param second": "non-empty description",
		"## @param": "non-empty description",
		"## @param second: 第二项。\n## @param second: 重复。": "duplicate @param",
		"## @param third: 第三项。\n## @param first: 第一项。": "@param order",
	}
	for docs: String in cases:
		_assert_invalid(source % docs, GF_VARIANT_ACCESS.get_option_string(cases, docs))
	var valid_source: String = source % "## @param first: 第一项。\n## @param third: 第三项。"
	assert_eq(_collect_api_surface_issues(valid_source, VALID_FULL_EXAMPLE_PATH), [], "私有参数子集保持签名中的相对顺序即可。")


func test_private_optional_return_and_schema_tags_are_validated() -> void:
	var source: String = "# --- 私有/辅助方法 ---\n\n## 维护约束。\n## @api private\n%s\nfunc _normalize(value: Dictionary) -> Dictionary:\n\treturn value\n"
	var cases: Dictionary = {
		"## @return:": "non-empty description",
		"## @schema missing: 错误目标。": "unknown @schema target",
		"## @schema value:": "non-empty description",
		"## @schema value": "non-empty description",
		"## @schema": "non-empty description",
		"## @schema value {\n## }": "non-empty description",
		"## @schema value: 第一份。\n## @schema value: 第二份。": "duplicate @schema",
	}
	for docs: String in cases:
		_assert_invalid(source % docs, GF_VARIANT_ACCESS.get_option_string(cases, docs))
	var valid_source: String = source % "## @return: 隔离后的字段。\n## @schema value: {\"type\": \"Dictionary\"}\n## @schema return: 复制后的字段字典。"
	assert_eq(_collect_api_surface_issues(valid_source, VALID_FULL_EXAMPLE_PATH), [], "私有文档支持按需返回值及非空 schema 说明。")
	_assert_invalid((source % "## @return: 不存在的返回值。").replace("-> Dictionary", "-> void"), "@return requires a non-void function")
	_assert_invalid((source % "## @schema return: 不存在的返回值。").replace("-> Dictionary", "-> void"), "unknown @schema target")
	_assert_invalid("# --- 私有变量 ---\n## 维护约束。\n## @api private\n## @return: 不存在的返回值。\nvar _value: int = 0", "@return requires a non-void function")
	_assert_invalid("# --- 私有变量 ---\n## 维护约束。\n## @api private\n## @param value: 不存在的参数。\nvar _value: int = 0", "unknown @param")


func test_documented_private_types_still_cannot_escape_public_signatures() -> void:
	var source: String = """
## 公开类型。
## @api public
## @category protocol
## @since 3.17.0
class_name GFPrivateDocExposure
extends RefCounted

# --- 公共方法 ---

## 获取游标。
## @api public
## @return: 游标。
func get_cursor() -> _Cursor:
	return null

# --- 内部类 ---

## 仅供解析实现保存位置。
## @api private
class _Cursor:
	extends RefCounted
"""
	_assert_invalid(source, "public API exposes internal type _Cursor")



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


func test_internal_functions_cannot_use_public_method_section() -> void:
	var framework_internal_source: String = """
## 示例类型。
##
## @api framework_internal
class_name GFInvalidFrameworkInternalSection
extends RefCounted

# --- 公共方法 ---

## 仅供框架协作。
##
## @api framework_internal
func synchronize() -> void:
	pass
"""
	var layer_internal_source: String = """
## 示例类型。
##
## @api framework_internal
class_name GFInvalidLayerInternalSection
extends RefCounted

# --- 公共方法 ---

## 仅供 kernel/core 层协作。
##
## @api layer_internal
## @layer kernel/core
func synchronize() -> void:
	pass
"""

	_assert_invalid_at_path(
		framework_internal_source,
		"framework_internal API must be placed in a framework internal section",
		"res://addons/gf/tools/project_layout/gf_invalid_framework_internal_section.gd"
	)
	_assert_invalid_at_path(
		layer_internal_source,
		"layer_internal API must be placed in a layer internal section",
		"res://addons/gf/kernel/core/gf_invalid_layer_internal_section.gd"
	)


func test_project_layout_internal_functions_require_exact_internal_sections() -> void:
	var source: String = """
## 示例类型。
##
## @api framework_internal
class_name GFInvalidProjectLayoutInternalSection
extends RefCounted

# --- 私有/辅助方法 ---

## 仅供框架协作。
##
## @api framework_internal
func synchronize() -> void:
	pass
"""

	_assert_invalid_at_path(
		source,
		"framework_internal API must be placed in a framework internal section",
		"res://addons/gf/tools/project_layout/gf_invalid_exact_internal_section.gd"
	)


func test_public_api_docs_cannot_reference_internal_function_calls() -> void:
	var source: String = """
## 示例类型。
##
## @api public
## @category tool_api
## @since 1.0.0
class_name GFInvalidPublicInternalCallDocs
extends RefCounted

# --- 公共方法 ---

## 分析项目；后台线程应先调用 compile_for_worker()。
##
## @api public
func analyze() -> void:
	pass

# --- 框架内部方法 ---

## 编译后台输入。
##
## @api framework_internal
func compile_for_worker() -> void:
	pass
"""

	_assert_invalid_at_path(
		source,
		"public API docs reference internal function 'compile_for_worker'",
		"res://addons/gf/tools/project_layout/gf_invalid_public_internal_call_docs.gd"
	)


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
# --- 常量 ---

## 保留供内部构造与类型收窄使用的脚本资源。
## [br]
## @api private
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

## 返回传入的代理实例，不创建或释放代理。
## [br]
## @api private
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


func test_migration_marker_cannot_suppress_missing_documentation() -> void:
	var source: String = """
# @api_surface_migration partial
class_name GFMarkedIncompleteAPI
extends RefCounted

func configure(value: int) -> bool:
	return value > 0
"""

	var issues: Array[String] = _collect_api_surface_issues(source, "<inline>")
	assert_true(_issues_contain(issues, "missing API doc"), "迁移标记不得隐藏缺失文档。")
	assert_true(_issues_contain(issues, "migration markers are no longer allowed"))


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

	_assert_invalid(source, "migration markers are no longer allowed")


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


func test_property_accessor_locals_are_not_api_declarations() -> void:
	var source: String = """
## 示例类型。
##
## @api public
## @category runtime_service
## @since 1.0.0
class_name GFAccessorLocalSource
extends RefCounted

# --- 公共变量 ---

## 最大玩家数量。
##
## @api public
## @since 1.0.0
var max_players: int = 1:
	set(value):
		var next_max_players: int = maxi(value, 1)
		var previous_max_players: int = max_players
		max_players = next_max_players if next_max_players != previous_max_players else value
"""

	var issues: Array[String] = _collect_api_surface_issues(source, "<inline>")
	assert_eq(issues, [], "属性访问器中的局部变量不应参与 API Surface 校验：\n%s" % _join_lines(issues))


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


func test_controlled_gf_autoload_owner_binds_to_extends() -> void:
	var source: String = """
## Gf: 受控全局入口。
## [br]
## @api public
## [br]
## @api_owner autoload Gf
## [br]
## @category runtime_service
## [br]
## @since 1.0.0
## [br]
## @layer kernel/core
extends Node

# --- 公共方法 ---

## 查询入口状态。
## [br]
## @api public
## [br]
## @return: 入口是否已就绪。
func is_ready() -> bool:
	return true
"""
	var issues: Array[String] = _collect_api_surface_issues(source, GF_AUTOLOAD_OWNER_PATH)

	assert_eq(issues, [], "精确受控 Gf AutoLoad owner 应允许 classless public surface：\n%s" % _join_lines(issues))


func test_api_owner_requires_exact_controlled_identity_path_and_base() -> void:
	var template: String = """
## 受控入口。
## [br]
## @api public
## [br]
## @api_owner %s
## [br]
## @category runtime_service
## [br]
## @since 1.0.0
## [br]
## @layer kernel/core
extends %s
"""
	_assert_invalid_at_path(
		template % ["service Gf", "Node"],
		"unknown or uncontrolled @api_owner 'service Gf'",
		GF_AUTOLOAD_OWNER_PATH
	)
	_assert_invalid_at_path(
		template % ["autoload Other", "Node"],
		"unknown or uncontrolled @api_owner 'autoload Other'",
		GF_AUTOLOAD_OWNER_PATH
	)
	_assert_invalid_at_path(
		template % ["autoload Gf", "Node"],
		"@api_owner autoload Gf is only allowed at",
		"res://addons/gf/kernel/core/other.gd"
	)
	_assert_invalid_at_path(
		template % ["autoload Gf", "Node2D"],
		"@api_owner autoload Gf must bind to top-level extends Node",
		GF_AUTOLOAD_OWNER_PATH
	)


func test_controlled_gf_autoload_owner_requires_exactly_one_public_visibility() -> void:
	var template: String = """
## 受控全局入口。
## [br]
%s
## [br]
## @api_owner autoload Gf
## [br]
## @category runtime_service
## [br]
## @since 1.0.0
## [br]
## @layer kernel/core
extends Node
"""
	var valid_source: String = template % "## @api public"
	assert_eq(_collect_api_surface_issues(valid_source, GF_AUTOLOAD_OWNER_PATH), [], "单一精确 public 标签应保留受控 owner。")
	assert_true(_has_controlled_gf_autoload_owner(valid_source, GF_AUTOLOAD_OWNER_PATH))
	for api_docs: String in [
		"## @api public\n## [br]\n## @api private",
		"## @api public\n## [br]\n## @api public",
		"## @api private\n## [br]\n## @api public",
		"## @api public extra",
		"## @api\tpublic",
		"## @api public\n## [br]\n## @api: private",
		"## @api",
	]:
		var source: String = template % api_docs
		_assert_invalid_at_path(source, "must declare exactly one @api public", GF_AUTOLOAD_OWNER_PATH)
		assert_false(_has_controlled_gf_autoload_owner(source, GF_AUTOLOAD_OWNER_PATH), "含糊的可见性不得授予 classless public owner。")


func test_api_owner_rejects_duplicate_or_orphan_declarations() -> void:
	var duplicate_source: String = """
## 受控入口。
## [br]
## @api public
## [br]
## @api_owner autoload Gf
## [br]
## @api_owner autoload Gf
## [br]
## @category runtime_service
## [br]
## @since 1.0.0
## [br]
## @layer kernel/core
extends Node
"""
	_assert_invalid_at_path(
		duplicate_source,
		"@api_owner must be declared exactly once",
		GF_AUTOLOAD_OWNER_PATH
	)

	var orphan_source: String = """
## 受控入口。
## [br]
## @api public
## [br]
## @api_owner autoload Gf
## [br]
## @category runtime_service
## [br]
## @since 1.0.0
## [br]
## @layer kernel/core
func run() -> void:
	pass
"""
	_assert_invalid_at_path(
		orphan_source,
		"@api_owner autoload Gf must bind to top-level extends Node",
		GF_AUTOLOAD_OWNER_PATH
	)


func test_node_script_without_controlled_owner_remains_classless() -> void:
	var source: String = """
extends Node

# --- 公共方法 ---

## 不能只凭 Node 继承获得公开 owner。
## [br]
## @api public
func run() -> void:
	pass
"""
	_assert_invalid(source, "public top-level API requires class_name or controlled @api_owner autoload Gf")


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


func test_every_private_declaration_requires_documentation() -> void:
	var declarations: Array[String] = [
		"var _state: int = 0",
		"static var _shared: int = 0",
		"@export var _configured: int = 0",
		"@export_range(0, 5)\nvar _bounded: int = 0",
		"const _LIMIT: int = 2",
		"signal _finished(result: bool)",
		"enum _Phase { IDLE, ACTIVE }",
		"func _read() -> int:\n\treturn 1",
		"func _merge(\n\tfirst: int,\n\tsecond: int\n) -> int:\n\treturn first + second",
		"class _State:\n\tpass",
	]
	for declaration: String in declarations:
		var issues: Array[String] = _collect_api_surface_issues("extends RefCounted\n\n" + declaration + "\n", "<private-coverage>")
		assert_true(_issues_contain(issues, "missing API doc"), "所有私有声明都需要维护文档：%s\n%s" % [declaration, _join_lines(issues)])
	var nested_source: String = "extends RefCounted\nclass _Outer:\n\tclass _Inner:\n\t\tstatic var _cache: int = 0\n\t\tfunc _read() -> int:\n\t\t\treturn _cache\n"
	var nested_issues: Array[String] = _collect_api_surface_issues(nested_source, "<classless-nested>")
	for member_name: String in ["_Outer", "_Inner", "_cache", "_read"]:
		assert_true(_issues_contain(nested_issues, member_name + " missing API doc"), "classless 多层内部声明不能漏检：%s" % member_name)


func test_template_sources_participate_in_the_same_contract_scan() -> void:
	var paths: Array[String] = _collect_gdscript_files(SOURCE_ROOT)
	assert_true(paths.has("res://addons/gf/tools/ai_developer/templates/adapters/storage/storage_backend.gd.txt"), "Adapter 模板必须进入源码契约扫描。")
	assert_true(paths.has("res://addons/gf/tools/project_bootstrap/templates/empty_project/integration_snippet.gd.txt"), "函数体片段也必须进入受控模板渲染与扫描。")
	var issues: Array[String] = []
	var missing_paths: Array[String] = CONTRACT_SOURCES.collect_files("res://does-not-exist-comment-contract", issues)
	assert_eq(missing_paths, [])
	assert_false(issues.is_empty(), "枚举失败不能变成空目录成功。")


func test_native_callbacks_require_the_actual_native_base() -> void:
	for method_name: String in ["_ready", "_draw"]:
		var source: String = "extends RefCounted\nfunc %s() -> void:\n\tpass\n" % method_name
		_assert_invalid(source, method_name + " missing API doc")
		var native_base: String = "Node" if method_name == "_ready" else "Node2D"
		var native_issues: Array[String] = _collect_api_surface_issues(source.replace("RefCounted", native_base), "<native>")
		assert_false(_issues_contain(native_issues, "missing API doc"), "原生虚方法按真实基类证明：%s" % _join_lines(native_issues))
	_assert_invalid("extends Node\nstatic func _ready() -> void:\n\tpass\n", "_ready missing API doc")
	_assert_invalid("extends Node\n@warning_ignore(\"unused_parameter\")\nstatic func _ready() -> void:\n\tpass\n", "_ready missing API doc")
	var literal_source: String = "# --- 常量 ---\n## 保留模板原文。\n## [br]\n## @api private\nconst _TEXT: String = \"\"\"\nextends Node\n\"\"\"\nfunc _ready() -> void:\n\tpass\n"
	_assert_invalid(literal_source, "_ready missing API doc")
	var nested_source: String = "extends Node2D\n# --- 内部类 ---\n## 局部状态。\n## [br]\n## @api private\nclass _State:\n\textends RefCounted\n\tfunc _draw() -> void:\n\t\tpass\n"
	_assert_invalid(nested_source, "_draw missing API doc")
	var comment_base: String = "## 局部测试类型。\n## [br]\n## @api framework_internal\nclass_name CommentOnly # example: extends Node\nfunc _ready() -> void:\n\tpass\n"
	_assert_invalid(comment_base, "_ready missing API doc")
	assert_eq(_collect_api_surface_issues("extends RefCounted\nfunc _init() -> void:\n\tpass\n", "<constructor>"), [])


func test_inherited_protected_contract_requires_matching_owner_and_signature() -> void:
	var base_source: String = "## 测试继承协议。\n## [br]\n## @api framework_internal\nclass_name ContractBase\nextends RefCounted\n# --- 可重写钩子 / 虚方法 ---\n## 读取当前值。\n## [br]\n## @api protected\n## [br]\n## @param index: 读取的位置。\n## [br]\n## @return: 当前位置的值。\nfunc _read(index: int) -> int:\n\treturn index\n"
	var child_source: String = "extends \"res://contract/base.gd\"\nfunc _read(index: int) -> int:\n\treturn index\n"
	var sources: Dictionary = {"res://contract/base.gd": base_source, "res://contract/child.gd": child_source}
	var index: Dictionary = _collect_contract_owners(sources)
	var issues: Array[String] = _collect_api_surface_issues_with_type_visibility(child_source, "res://contract/child.gd", {}, {}, index)
	assert_false(_issues_contain(issues, "missing API doc"), "已文档 protected 基类契约可以复用：%s" % _join_lines(issues))
	for invalid_child: String in [child_source.replace("int", "float"), child_source.replace('"res://contract/base.gd"', "RefCounted"), child_source.replace("index", "position"), child_source.replace("index: int", "index: int = 0")]:
		sources["res://contract/child.gd"] = invalid_child
		issues = _collect_api_surface_issues_with_type_visibility(invalid_child, "res://contract/child.gd", {}, {}, _collect_contract_owners(sources))
		assert_true(_issues_contain(issues, "_read missing API doc"), "同名或不匹配签名不能豁免。")
	sources["res://contract/child.gd"] = child_source
	sources["res://contract/base.gd"] = base_source.replace("## @param index: 读取的位置。\n", "")
	issues = _collect_api_surface_issues_with_type_visibility(child_source, "res://contract/child.gd", {}, {}, _collect_contract_owners(sources))
	assert_true(_issues_contain(issues, "_read missing API doc"), "基类不完整的标签不能提供继承证明。")
	sources["res://contract/base.gd"] = base_source.replace("## 读取当前值。\n## [br]\n## @api protected\n## [br]\n## @param index: 读取的位置。\n## [br]\n## @return: 当前位置的值。\n", "")
	issues = _collect_api_surface_issues_with_type_visibility(child_source, "res://contract/child.gd", {}, {}, _collect_contract_owners(sources))
	assert_true(_issues_contain(issues, "_read missing API doc"), "同名基类 helper 和 hook section 都不能代替已文档契约。")
	sources["res://contract/base.gd"] = base_source.replace("index: int", "index: int = 1")
	var different_default: String = child_source.replace("index: int", "index: int = 2")
	sources["res://contract/child.gd"] = different_default
	issues = _collect_api_surface_issues_with_type_visibility(different_default, "res://contract/child.gd", {}, {}, _collect_contract_owners(sources))
	assert_true(_issues_contain(issues, "_read missing API doc"), "不同默认表达式不能沿用完整契约。")
	sources["res://contract/base.gd"] = base_source
	for visibility: String in ["private", "framework_internal", "layer_internal"]:
		for parameter_name: String in ["index", "position"]:
			var downgrade: String = child_source.replace("func _read", "## 覆写读取。\n## [br]\n## @api " + visibility + "\nfunc _read").replace("index", parameter_name)
			sources["res://contract/child.gd"] = downgrade
			issues = _collect_api_surface_issues_with_type_visibility(downgrade, "res://contract/child.gd", {}, {}, _collect_contract_owners(sources))
			assert_true(_issues_contain(issues, "inherited protected API cannot be downgraded"), "参数改名或轻量标签不能降级真实覆写契约。")
	var documented_override: String = child_source.replace("func _read", "# --- 可重写钩子 / 虚方法 ---\n## 在当前实现读取位置。\n## [br]\n## @api protected\n## [br]\n## @param index: 读取位置。\n## [br]\n## @return: 当前值。\nfunc _read")
	sources["res://contract/child.gd"] = documented_override
	issues = _collect_api_surface_issues_with_type_visibility(documented_override, "res://contract/child.gd", {}, {}, _collect_contract_owners(sources))
	assert_eq(issues, [], "classless 只能复述已证明的 inherited protected 契约：%s" % _join_lines(issues))
	for unowned_source: String in [documented_override.replace('"res://contract/base.gd"', "RefCounted"), documented_override.replace("@api protected", "@api public")]:
		sources["res://contract/child.gd"] = unowned_source
		issues = _collect_api_surface_issues_with_type_visibility(unowned_source, "res://contract/child.gd", {}, {}, _collect_contract_owners(sources))
		assert_true(_issues_contain(issues, "requires class_name or controlled"), "既有 protected 关系不能创造新 public owner 或新 protected 入口。")
	sources["res://contract/middle.gd"] = documented_override
	var leaf_source: String = child_source.replace("base.gd", "middle.gd")
	sources["res://contract/child.gd"] = leaf_source
	issues = _collect_api_surface_issues_with_type_visibility(leaf_source, "res://contract/child.gd", {}, {}, _collect_contract_owners(sources))
	assert_eq(issues, [], "多级 classless 继承必须能追溯至原有受控 protected owner。")


func test_template_declarations_use_the_same_visibility_and_parameter_contract() -> void:
	var path: String = "res://contract/template.gd.txt"
	var source: String = "extends RefCounted\n# --- 私有/辅助方法 ---\n## 只读取输入。\n## [br]\n## @api private\nfunc _read(value: int) -> int:\n\treturn value\n"
	assert_eq(_collect_api_surface_issues(source, path), [])
	_assert_invalid_at_path(source.replace("@api private", "@api unknown"), "invalid @api", path)
	_assert_invalid_at_path(source.replace("## @api private", "## @api private\n## [br]\n## @param absent: 未声明的参数。"), "unknown @param", path)
	_assert_invalid_at_path(source.replace("## @api private", "## @api framework_internal"), "missing @param", path)
	_assert_invalid_at_path(source.replace("## 只读取输入。\n## [br]\n## @api private\n", ""), "missing API doc", path)
	var integration: String = CONTRACT_SOURCES.render_source("var initialized: bool = await Gf.init()\nif not initialized:\n\treturn\n", CONTRACT_SOURCES.INTEGRATION_SNIPPET_PATH)
	var declarations: Array[Dictionary] = _parse_declarations(integration, CONTRACT_SOURCES.INTEGRATION_SNIPPET_PATH)
	assert_eq(declarations.size(), 1, "函数体片段的局部变量不应成为成员；承载函数本身仍接受契约检查。")
	_assert_invalid_at_path("func _hidden() -> void:\n\tpass\n", "function-body template cannot introduce", CONTRACT_SOURCES.INTEGRATION_SNIPPET_PATH)
	_assert_invalid_at_path("static var _cache: int = 0\n", "function-body template cannot introduce", CONTRACT_SOURCES.INTEGRATION_SNIPPET_PATH)
	_assert_invalid_at_path("var _cache: int:\n\tget:\n\t\treturn 0\n", "function-body template cannot introduce", CONTRACT_SOURCES.INTEGRATION_SNIPPET_PATH)


func test_test_runner_names_require_the_actual_gut_base() -> void:
	for method_name: String in ["test_example", "before_each", "after_each"]:
		var source: String = "extends GutTest\nfunc %s() -> void:\n\tpass\n" % method_name
		assert_eq(_collect_api_surface_issues(source, "<gut>"), [])
		_assert_invalid(source.replace("GutTest", "RefCounted"), method_name + " missing API doc")


func test_comments_and_string_literals_cannot_hide_following_declarations() -> void:
	var prefixes: Array[String] = [
		"# 示例分隔符为 \"\"\"\n",
		"# 示例分隔符为 '''\n",
		"const _TEXT: String = '\"\"\"'\n",
		"const _TEXT: String = \"'''\"\n",
		"const _TEXT: String = \"escaped \\\"\\\"\\\"\"\n",
	]
	for path: String in ["<lexical>", "res://contract/lexical.gd.txt"]:
		for prefix: String in prefixes:
			_assert_invalid_at_path("extends RefCounted\n" + prefix + "# --- 私有变量 ---\nvar _hidden: int = 0\n", "_hidden missing API doc", path)
	var source: String = "extends RefCounted\n# --- 私有/辅助方法 ---\n## 返回到调用者。\n## [br]\n## @api private\nfunc _documented() -> void: pass\n\nfunc _hidden() -> void:\n\tpass\n"
	_assert_invalid(source, "_hidden missing API doc")
	var declarations: Array[Dictionary] = _parse_declarations(source, "<one-line-function>")
	assert_eq(declarations.size(), 2, "单行函数体不能吞掉后续函数签名。")
	var decorated_source: String = "extends RefCounted\n# --- 私有变量 ---\n## 保存待处理值。\n## [br]\n## @api private\n@warning_ignore(\"unused_private_class_variable\")\nstatic var _values: Array[String] = [\n\t\"func _fake():\",\n\t\"# literal \\\"\\\"\\\"\",\n]\n\n# --- 私有/辅助方法 ---\n## 读取参数而不保留引用。\n## [br]\n## @api private\nfunc _read(\n\tlabel: String = \"res://sample:),(\", # ) : 不参与签名\n\toptions: Dictionary = {\"colon\": \":\"}\n) -> void: pass\n\nfunc _missing() -> void:\n\tpass\n"
	declarations = _parse_declarations(decorated_source, "<decorated-multiline>")
	assert_eq(declarations.size(), 3, "多行默认值、注释和字符串内伪声明不改变真实成员数量。")
	assert_eq(GF_VARIANT_ACCESS.get_option_string(declarations[0], "name"), "_values")
	assert_true(GF_VARIANT_ACCESS.get_option_bool(declarations[0], "is_static"))
	var parameters: Array = declarations[1]["params"]
	assert_eq(parameters.size(), 2)
	_assert_invalid(decorated_source, "_missing missing API doc")


func test_quoted_script_inner_classes_prove_the_actual_inherited_contract() -> void:
	var base_source: String = "extends RefCounted\n# --- 内部类 ---\n## 协议容器。\n## [br]\n## @api framework_internal\nclass Outer:\n\t# --- 内部类 ---\n\t## 读取协议。\n\t## [br]\n\t## @api framework_internal\n\tclass Nested:\n\t\textends RefCounted\n\t\t# --- 可重写钩子 / 虚方法 ---\n\t\t## 读取当前值。\n\t\t## [br]\n\t\t## @api protected\n\t\t## [br]\n\t\t## @param index: 读取位置。\n\t\t## [br]\n\t\t## @return: 当前位置的值。\n\t\tfunc _read(index: int) -> int:\n\t\t\treturn index\n"
	var child_path: String = "res://contract/child.gd"
	for base_expression: String in ['"res://contract/base.gd".Outer.Nested', '"base.gd".Outer.Nested']:
		var child_source: String = "extends %s\nfunc _read(index: int) -> int:\n\treturn index\n" % base_expression
		var sources: Dictionary = {"res://contract/base.gd": base_source, child_path: child_source}
		var issues: Array[String] = _collect_api_surface_issues_with_type_visibility(child_source, child_path, {}, {}, _collect_contract_owners(sources))
		assert_eq(issues, [], "quoted path 的内部类应由完整 owner 路径解析：%s" % _join_lines(issues))
		var downgrade: String = child_source.replace("func _read", "## 本地读取。\n## [br]\n## @api private\nfunc _read")
		sources[child_path] = downgrade
		issues = _collect_api_surface_issues_with_type_visibility(downgrade, child_path, {}, {}, _collect_contract_owners(sources))
		assert_true(_issues_contain(issues, "inherited protected API cannot be downgraded"))
		var unknown_owner: String = child_source.replace(".Outer.Nested", ".Outer.Missing")
		sources[child_path] = unknown_owner
		issues = _collect_api_surface_issues_with_type_visibility(unknown_owner, child_path, {}, {}, _collect_contract_owners(sources))
		assert_true(_issues_contain(issues, "_read missing API doc"), "未知内部 owner 不能猜测继承契约。")


func test_default_strings_and_annotation_comments_do_not_change_contract_binding() -> void:
	for path: String in ["<signature-lexical>", "res://contract/signature.gd.txt"]:
		var source: String = "extends RefCounted\n# --- 框架内部方法 ---\n## 读取结构。\n## [br]\n## @api framework_internal\n## [br]\n## @param marker: 调用者标记。\n## [br]\n## @return: 当前结构。\nfunc describe(marker: String = \"->\") -> Dictionary:\n\treturn {}\n"
		var declarations: Array[Dictionary] = _parse_declarations(source, path)
		assert_eq(GF_VARIANT_ACCESS.get_option_string(declarations[0], "return_type"), "Dictionary")
		_assert_invalid_at_path(source, "missing @schema for return", path)
		for annotation: String in ["@export # 注解说明", "@export_range(0, 10) # 注解说明"]:
			var field_source: String = "extends RefCounted\n# --- 导出变量 ---\n## 保存配置值。\n## [br]\n## @api private\n%s\nvar _configured: int = 0\n" % annotation
			assert_eq(_collect_api_surface_issues(field_source, path), [], "注解尾注释不得断开已有文档：%s" % path)
			_assert_invalid_at_path(field_source.replace("## 保存配置值。\n## [br]\n## @api private\n", ""), "_configured missing API doc", path)


func test_export_metadata_does_not_consume_following_member_documentation() -> void:
	var metadata_lines: Array[String] = [
		'@export_group("Group")',
		'@export_category("Category") # 编辑器分类',
		'@export_subgroup(\n\t"Subgroup"\n)',
	]
	for path: String in ["<export-metadata>", "res://contract/export_metadata.gd.txt"]:
		for metadata: String in metadata_lines:
			var source: String = "extends Node\n# --- 导出变量 ---\n%s\n\n## 保存配置值。\n## [br]\n## @api private\n@export var _configured: int = 0\n" % metadata
			assert_eq(_collect_api_surface_issues(source, path), [], "分类元注解不能吞掉下一块成员文档：%s" % metadata)
			_assert_invalid_at_path(source.replace("## 保存配置值。\n## [br]\n## @api private\n", ""), "_configured missing API doc", path)
		for file_metadata: String in ["@tool # 文件工具标记", '@icon("res://icon.svg") # 文件图标']:
			var source: String = "%s\nextends RefCounted\n# --- 私有变量 ---\n## 保存值。\n## [br]\n## @api private\nvar _state: int = 0\n" % file_metadata
			assert_eq(_collect_api_surface_issues(source, path), [], "文件元注解不绑定后续成员。")


# --- 私有/辅助方法 ---

func _assert_invalid(source: String, expected_fragment: String) -> void:
	var issues: Array[String] = _collect_api_surface_issues(source, "<inline>")
	assert_true(
		_issues_contain(issues, expected_fragment),
		"应包含违规片段 '%s'，实际问题：\n%s" % [expected_fragment, _join_lines(issues)]
	)


func _assert_invalid_at_path(source: String, expected_fragment: String, path: String) -> void:
	var issues: Array[String] = _collect_api_surface_issues(source, path)
	assert_true(
		_issues_contain(issues, expected_fragment),
		"应包含违规片段 '%s'，实际问题：\n%s" % [expected_fragment, _join_lines(issues)]
	)


func _collect_api_surface_issues(source: String, path: String) -> Array[String]:
	var rendered: String = CONTRACT_SOURCES.render_source(source, path)
	var declarations: Array[Dictionary] = _parse_declarations(rendered, path)
	var type_visibility: Dictionary = _collect_type_visibility(declarations)
	var type_inheritance: Dictionary = _collect_file_type_inheritance(rendered)
	var contract_owners: Dictionary = _collect_contract_owners({path: source})
	return _collect_api_surface_issues_with_type_visibility(source, path, type_visibility, type_inheritance, contract_owners)


func _collect_api_surface_issues_with_type_visibility(
	source: String,
	path: String,
	type_visibility: Dictionary,
	type_inheritance: Dictionary = {},
	contract_owners: Dictionary = {}
) -> Array[String]:
	var strict_issues: Array[String] = _collect_template_fragment_issues(source, path)
	source = CONTRACT_SOURCES.render_source(source, path)
	var declarations: Array[Dictionary] = _parse_declarations(source, path)
	var allows_top_level_public_api: bool = _has_top_level_class_name(declarations)
	if not allows_top_level_public_api:
		allows_top_level_public_api = _has_controlled_gf_autoload_owner(source, path)
	strict_issues.append_array(_collect_file_structure_issues(source, path, type_inheritance))
	strict_issues.append_array(_collect_api_owner_issues(source, path))
	for declaration: Dictionary in declarations:
		var inherited: Dictionary = _inherited_method_info(declaration, contract_owners)
		declaration["inherited_contract"] = inherited.get("documentation", "")
		declaration["inherited_visibility"] = inherited.get("visibility", "")
		declaration["inherited_owner_proven"] = inherited.get("owner_proven", false)
		strict_issues.append_array(_collect_declaration_issues(declaration, type_visibility, allows_top_level_public_api))
	strict_issues.append_array(_collect_public_api_doc_internal_reference_issues(declarations, path))

	if _source_has_migration_marker(source):
		strict_issues.append("%s API surface migration markers are no longer allowed" % path)
	return strict_issues


func _source_has_migration_marker(source: String) -> bool:
	var lines: PackedStringArray = source.split("\n")
	for raw_line: String in lines:
		if _trim_cr(raw_line).strip_edges() == MIGRATION_MARKER:
			return true
	return false


func _collect_placeholder_since_issues(source: String, path: String) -> Array[String]:
	var issues: Array[String] = []
	var controlled_owner: Dictionary = _get_controlled_gf_autoload_owner(source, path)
	var lines: PackedStringArray = source.split("\n")
	for line_index: int in range(lines.size()):
		var line: String = _trim_cr(String(lines[line_index])).strip_edges()
		if not line.begins_with("##"):
			continue
		if _doc_body(line) == "@since %s" % PLACEHOLDER_SINCE_VERSION:
			var source_line: int = line_index + 1
			if (
				not controlled_owner.is_empty()
				and source_line >= GF_VARIANT_ACCESS.get_option_int(controlled_owner, "doc_line", -1)
				and source_line < GF_VARIANT_ACCESS.get_option_int(controlled_owner, "target_line", -1)
			):
				continue
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
	var issues: Array[String] = []
	var paths: Array[String] = CONTRACT_SOURCES.collect_files(root_path, issues)
	assert_eq(issues, [], "完整扫描必须能枚举每个目录：%s" % _join_lines(issues))
	return paths


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
		elif entry.ends_with(".gd") or entry.ends_with(".gd.txt"):
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


func _collect_contract_owners(sources: Dictionary) -> Dictionary:
	var owners: Dictionary = {}
	var names: Dictionary = {}
	for path: String in sources:
		var source: String = CONTRACT_SOURCES.render_source(GF_VARIANT_ACCESS.get_option_string(sources, path), path)
		var root_name: String = _collect_top_level_class_name(source)
		owners[path] = {"path": path, "base": _collect_top_level_extends(source), "methods": {}, "allows_public": not root_name.is_empty() or _has_controlled_gf_autoload_owner(source, path)}
		if not root_name.is_empty():
			names[root_name] = path
		for declaration: Dictionary in _parse_declarations(source, path):
			var kind: String = declaration["kind"]
			if kind == "class":
				var owned_key: String = declaration["owned_key"]
				owners[owned_key] = {"path": path, "base": declaration["base_type"], "methods": {}, "allows_public": true}
				if not root_name.is_empty():
					names[root_name + "." + owned_key.trim_prefix(path + "::").replace("::", ".")] = owned_key
			elif kind == "func":
				var contract_owner: Dictionary = owners[declaration["owner_key"]]
				var methods: Dictionary = contract_owner["methods"]
				methods[declaration["name"]] = declaration
	return {"owners": owners, "names": names}


func _resolve_contract_base(owner_key: String, index: Dictionary) -> String:
	var owners: Dictionary = index.get("owners", {})
	var names: Dictionary = index.get("names", {})
	if not owners.has(owner_key):
		return ""
	var contract_owner: Dictionary = owners[owner_key]
	var base: String = contract_owner["base"]
	var path: String = contract_owner["path"]
	if base.begins_with('"') or base.begins_with("'"):
		var quote: String = base[0]
		var close_index: int = 1
		while close_index < base.length():
			if base[close_index] == "\\":
				close_index += 2
				continue
			if base[close_index] == quote:
				break
			close_index += 1
		if close_index >= base.length():
			return ""
		var script_path: String = base.substr(1, close_index - 1).c_unescape()
		if not script_path.begins_with("res://"):
			script_path = path.get_base_dir().path_join(script_path)
		var resolved: String = script_path.simplify_path()
		var suffix: String = base.substr(close_index + 1).strip_edges()
		if not suffix.is_empty():
			if not suffix.begins_with("."):
				return ""
			for inner_name: String in suffix.substr(1).split("."):
				if inner_name.is_empty() or _read_identifier(inner_name) != inner_name:
					return ""
				resolved += "::" + inner_name
				if not owners.has(resolved):
					return ""
		return resolved
	var scope: String = owner_key
	while not scope.is_empty():
		var local_key: String = scope + "::" + base.replace(".", "::")
		if owners.has(local_key):
			return local_key
		var separator: int = scope.rfind("::")
		if separator == -1:
			break
		scope = scope.substr(0, separator)
	return GF_VARIANT_ACCESS.get_option_string(names, base, base)


func _inherited_method_info(declaration: Dictionary, index: Dictionary) -> Dictionary:
	if declaration.get("kind", "") != "func" or GF_VARIANT_ACCESS.get_option_bool(declaration, "is_static"):
		return {}
	var docs: Array = declaration.get("docs", [])
	var needs_documentation: bool = docs.is_empty()
	if not needs_documentation and declaration.get("api", "") == "public":
		return {}
	var owners: Dictionary = index.get("owners", {})
	var method_name: String = declaration["name"]
	var owner_key: String = declaration.get("owner_key", "")
	var visited: Dictionary = {}
	while owners.has(owner_key) and not visited.has(owner_key):
		visited[owner_key] = true
		var base: String = _resolve_contract_base(owner_key, index)
		if needs_documentation and CONTRACT_SOURCES.is_native_virtual(base, method_name):
			return {"documentation": "native:" + base + "." + method_name}
		if needs_documentation and base in ["GutTest", "res://addons/gut/test.gd"] and _is_gut_runner_entry(declaration):
			return {"documentation": "runner:res://addons/gut/test.gd:" + method_name}
		if not owners.has(base):
			return {}
		var base_owner: Dictionary = owners[base]
		var methods: Dictionary = base_owner["methods"]
		if methods.has(method_name):
			var method: Dictionary = methods[method_name]
			var visibility: String = method.get("api", "")
			if visibility == "protected":
				# 可见性来自真实覆写关系；签名变化只取消复用文档资格，不能降级为 private。
				var owner_proven: bool = _has_protected_owner_origin(base, method_name, index)
				var result: Dictionary = {"visibility": "protected", "documentation": "", "owner_proven": owner_proven}
				if owner_proven and _method_signatures_match(declaration, method) and _collect_declaration_issues(method, {}, true).is_empty():
					result["documentation"] = "protected:" + _format_location(method)
				return result
			if not visibility.is_empty():
				return {}
		owner_key = base
	return {}


func _has_protected_owner_origin(owner_key: String, method_name: String, index: Dictionary) -> bool:
	var owners: Dictionary = index.get("owners", {})
	var visited: Dictionary = {}
	while owners.has(owner_key) and not visited.has(owner_key):
		visited[owner_key] = true
		var contract_owner: Dictionary = owners[owner_key]
		var methods: Dictionary = contract_owner["methods"]
		if methods.has(method_name):
			var method: Dictionary = methods[method_name]
			var visibility: String = method.get("api", "")
			if not visibility.is_empty() and visibility != "protected":
				return false
			if visibility == "protected" and GF_VARIANT_ACCESS.get_option_bool(contract_owner, "allows_public"):
				return _collect_declaration_issues(method, {}, true).is_empty()
		owner_key = _resolve_contract_base(owner_key, index)
	return false


func _method_signatures_match(override_method: Dictionary, base_method: Dictionary) -> bool:
	if override_method.get("return_type", "") != base_method.get("return_type", ""):
		return false
	var override_params: Array = override_method.get("params", [])
	var base_params: Array = base_method.get("params", [])
	if override_params.size() != base_params.size():
		return false
	for parameter_index: int in range(base_params.size()):
		var override_param: Dictionary = override_params[parameter_index]
		var base_param: Dictionary = base_params[parameter_index]
		if override_param.get("type", "") != base_param.get("type", ""):
			return false
		if override_param.get("name", "") != base_param.get("name", ""):
			return false
		if override_param.get("has_default", false) != base_param.get("has_default", false):
			return false
		if override_param.get("default_expression", "") != base_param.get("default_expression", ""):
			return false
	return true


func _is_gut_runner_entry(declaration: Dictionary) -> bool:
	var params: Array = declaration.get("params", [])
	if not params.is_empty() or declaration.get("return_type", "") != "void":
		return false
	var method_name: String = declaration["name"]
	var collector: GUT_COLLECTOR_SCRIPT = GUT_COLLECTOR_SCRIPT.new()
	# 读取真实收集器前缀，且调用者必须已证明此 owner 的继承链到达 GutTest。
	if method_name.begins_with(GF_VARIANT_ACCESS.to_text(collector.get_test_prefix())):
		return true
	if method_name not in ["before_all", "before_each", "after_each", "after_all"]:
		return false
	var gut_script: Script = GUT_TEST_SCRIPT
	for method: Dictionary in gut_script.get_script_method_list():
		if GF_VARIANT_ACCESS.get_option_string(method, "name") == method_name:
			return true
	return false


func _collect_template_fragment_issues(source: String, path: String) -> Array[String]:
	var issues: Array[String] = []
	if path != CONTRACT_SOURCES.INTEGRATION_SNIPPET_PATH:
		return issues
	for declaration: Dictionary in _parse_declarations(source, path):
		if declaration["kind"] not in ["var", "const"] or GF_VARIANT_ACCESS.get_option_bool(declaration, "is_export") or GF_VARIANT_ACCESS.get_option_bool(declaration, "is_onready") or GF_VARIANT_ACCESS.get_option_bool(declaration, "is_static") or GF_VARIANT_ACCESS.get_option_bool(declaration, "has_accessors"):
			issues.append("%s function-body template cannot introduce a member declaration %s" % [_format_location(declaration), declaration["name"]])
	return issues


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
	var doc_has_api_owner_by_indent: Dictionary = {}
	var function_body_indent: int = -1
	var enum_body_indent: int = -1
	var property_body_indent: int = -1
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

		if property_body_indent != -1:
			if trimmed.is_empty():
				continue
			if indent > property_body_indent:
				continue
			property_body_indent = -1

		if trimmed.begins_with("##"):
			if not doc_start_by_indent.has(indent):
				doc_start_by_indent[indent] = line_index + 1
				doc_has_api_by_indent[indent] = false
				doc_has_api_owner_by_indent[indent] = false
			if _doc_body(trimmed).begins_with("@api"):
				doc_has_api_by_indent[indent] = true
			if _doc_body(trimmed).begins_with("@api_owner"):
				doc_has_api_owner_by_indent[indent] = true
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
				var _erase_owner_result_905: Variant = doc_has_api_owner_by_indent.erase(indent)
			continue

		var signature: Dictionary = _collect_declaration_signature(lines, line_index)
		if (
			indent == 0
			and trimmed.begins_with("extends ")
			and GF_VARIANT_ACCESS.get_option_bool(doc_has_api_owner_by_indent, indent, false)
		):
			var _owner_doc_erase_result: Variant = doc_start_by_indent.erase(indent)
			var _owner_api_erase_result: Variant = doc_has_api_by_indent.erase(indent)
			var _owner_tag_erase_result: Variant = doc_has_api_owner_by_indent.erase(indent)
			continue
		var declaration: Dictionary = _parse_declaration(GF_VARIANT_ACCESS.get_option_string(signature, "text", ""))
		if not declaration.is_empty():
			var _erase_result_911: Variant = doc_start_by_indent.erase(indent)
			var _erase_result_912: Variant = doc_has_api_by_indent.erase(indent)
			var _erase_owner_result_912: Variant = doc_has_api_owner_by_indent.erase(indent)
			var declaration_kind: String = GF_VARIANT_ACCESS.get_option_string(declaration, "kind")
			if declaration_kind == "func":
				function_body_indent = indent
			elif declaration_kind == "enum":
				enum_body_indent = indent
			elif (
				declaration_kind == "var"
				and GF_VARIANT_ACCESS.get_option_string(signature, "text").ends_with(":")
			):
				property_body_indent = indent
			skip_until_line = GF_VARIANT_ACCESS.get_option_int(signature, "end_line", line_index)
			multiline_string_delimiter = _update_multiline_string_delimiter(GF_VARIANT_ACCESS.get_option_string(signature, "text"), "")
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
			var _erase_owner_result_928: Variant = doc_has_api_owner_by_indent.erase(indent)

	for indent_variant: Variant in doc_start_by_indent.keys():
		_append_unbound_doc_issue(
			issues,
			path,
			GF_VARIANT_ACCESS.get_option_int(doc_start_by_indent, indent_variant, 0),
			GF_VARIANT_ACCESS.get_option_bool(doc_has_api_by_indent, indent_variant, false)
		)
	return issues


func _collect_api_owner_issues(source: String, path: String) -> Array[String]:
	var issues: Array[String] = []
	var owner_declarations: Array[Dictionary] = _collect_top_level_api_owner_declarations(source)
	if owner_declarations.size() > 1:
		issues.append("%s @api_owner must describe exactly one top-level owner" % path)
	for owner_declaration: Dictionary in owner_declarations:
		issues.append_array(_collect_gf_autoload_owner_declaration_issues(owner_declaration, path, source))
	return issues


func _collect_gf_autoload_owner_declaration_issues(
	owner_declaration: Dictionary,
	path: String,
	source: String
) -> Array[String]:
	var issues: Array[String] = []
	var docs: Array = GF_VARIANT_ACCESS.get_option_array(owner_declaration, "docs", [])
	var owner_values: PackedStringArray = _parse_tag_values(docs, "api_owner")
	var location: String = "%s:%d" % [
		path,
		GF_VARIANT_ACCESS.get_option_int(owner_declaration, "doc_line", 0),
	]
	if owner_values.size() != 1:
		issues.append("%s @api_owner must be declared exactly once" % location)
		return issues

	var owner_value: String = owner_values[0]
	if owner_value != "%s %s" % [GF_AUTOLOAD_OWNER_KIND, GF_AUTOLOAD_OWNER_NAME]:
		issues.append("%s unknown or uncontrolled @api_owner '%s'" % [location, owner_value])
		return issues
	if path != GF_AUTOLOAD_OWNER_PATH:
		issues.append("%s @api_owner autoload Gf is only allowed at %s" % [location, GF_AUTOLOAD_OWNER_PATH])
	if GF_VARIANT_ACCESS.get_option_string(owner_declaration, "target", "") != "extends %s" % GF_AUTOLOAD_OWNER_BASE_TYPE:
		issues.append("%s @api_owner autoload Gf must bind to top-level extends %s" % [
			location,
			GF_AUTOLOAD_OWNER_BASE_TYPE,
		])
	if not _collect_top_level_class_name(source).is_empty():
		issues.append("%s @api_owner autoload Gf must not coexist with class_name" % location)
	var api_values: PackedStringArray = _parse_tag_values(docs, "api")
	if (
		api_values.size() != 1
		or api_values[0] != "public"
		or _parse_tag_value(docs, "api") != "public"
	):
		issues.append("%s @api_owner autoload Gf must declare exactly one @api public" % location)
	if _parse_tag_value(docs, "category") != "runtime_service":
		issues.append("%s @api_owner autoload Gf must declare @category runtime_service" % location)
	if _parse_tag_value(docs, "since") != PLACEHOLDER_SINCE_VERSION:
		issues.append("%s @api_owner autoload Gf must preserve @since %s" % [location, PLACEHOLDER_SINCE_VERSION])
	if _parse_tag_value(docs, "layer") != "kernel/core":
		issues.append("%s @api_owner autoload Gf must declare @layer kernel/core" % location)
	return issues


func _has_controlled_gf_autoload_owner(source: String, path: String) -> bool:
	return not _get_controlled_gf_autoload_owner(source, path).is_empty()


func _get_controlled_gf_autoload_owner(source: String, path: String) -> Dictionary:
	var owner_declarations: Array[Dictionary] = _collect_top_level_api_owner_declarations(source)
	if owner_declarations.size() != 1:
		return {}
	var owner_declaration: Dictionary = owner_declarations[0]
	if not _collect_gf_autoload_owner_declaration_issues(owner_declaration, path, source).is_empty():
		return {}
	return owner_declaration


func _collect_top_level_api_owner_declarations(source: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var lines: PackedStringArray = source.split("\n")
	var pending_docs: Array = []
	var pending_doc_line: int = 0
	var multiline_string_delimiter: String = ""
	for line_index: int in range(lines.size()):
		var raw_line: String = _trim_cr(String(lines[line_index]))
		var trimmed: String = raw_line.strip_edges()
		var was_in_multiline_string: bool = not multiline_string_delimiter.is_empty()
		multiline_string_delimiter = _update_multiline_string_delimiter(raw_line, multiline_string_delimiter)
		if was_in_multiline_string or _get_indent_level(raw_line) != 0:
			continue
		if trimmed.begins_with("##"):
			if pending_docs.is_empty():
				pending_doc_line = line_index + 1
			pending_docs.append(trimmed)
			continue
		if trimmed.is_empty():
			continue
		if not _parse_tag_values(pending_docs, "api_owner").is_empty():
			result.append({
				"docs": pending_docs.duplicate(),
				"doc_line": pending_doc_line,
				"target": trimmed,
				"target_line": line_index + 1,
			})
		pending_docs = []
		pending_doc_line = 0

	if not _parse_tag_values(pending_docs, "api_owner").is_empty():
		result.append({
			"docs": pending_docs.duplicate(),
			"doc_line": pending_doc_line,
			"target": "",
			"target_line": lines.size() + 1,
		})
	return result


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
	var multiline_delimiter: String = ""
	for line: String in source.split("\n"):
		var lexical: Dictionary = CONTRACT_SOURCES.lex_line(line, multiline_delimiter)
		multiline_delimiter = lexical["multiline_delimiter"]
		if GF_VARIANT_ACCESS.get_option_bool(lexical, "starts_in_multiline"):
			continue
		var code: String = lexical["code"]
		if code.begins_with("extends "):
			return _without_source_comments(line.trim_prefix("extends ")).strip_edges()
		if code.begins_with("class_name ") and code.contains(" extends "):
			return _without_source_comments(line.substr(code.find(" extends ") + " extends ".length())).strip_edges()
	return "RefCounted"


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
	var property_body_indent: int = -1
	var multiline_string_delimiter: String = ""
	var skip_until_line: int = -1
	var owner_stack: Array[Dictionary] = [{"key": path, "indent": -1}]

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

		if property_body_indent != -1:
			if trimmed.is_empty():
				continue
			if indent > property_body_indent:
				continue
			property_body_indent = -1

		if not trimmed.is_empty():
			while owner_stack.size() > 1 and indent <= GF_VARIANT_ACCESS.get_option_int(owner_stack[-1], "indent"):
				var _removed_owner: Dictionary = owner_stack.pop_back()
		if trimmed.begins_with("extends ") and owner_stack.size() > 1:
			var owner_declaration: Dictionary = owner_stack[-1]["declaration"]
			owner_declaration["base_type"] = trimmed.trim_prefix("extends ").get_slice("#", 0).strip_edges()
			continue

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
			declaration["owner_key"] = owner_stack[-1]["key"]
			declaration["is_static"] = _strip_leading_annotations(GF_VARIANT_ACCESS.get_option_string(signature, "text")).begins_with("static ")
			declaration["has_accessors"] = false
			if declaration["kind"] == "var" and GF_VARIANT_ACCESS.get_option_string(signature, "text").ends_with(":"):
				for following_line: int in range(GF_VARIANT_ACCESS.get_option_int(signature, "end_line", line_index) + 1, lines.size()):
					var following_text: String = String(lines[following_line]).strip_edges()
					if following_text.is_empty() or following_text.begins_with("#"):
						continue
					declaration["has_accessors"] = following_text == "get:" or following_text.begins_with("set(")
					break
			declaration["line"] = line_index + 1
			declaration["indent"] = indent
			declaration["section"] = _get_section_for_indent(section_by_indent, indent)
			declaration["docs"] = docs.duplicate()
			declaration["is_onready"] = GF_VARIANT_ACCESS.get_option_string(signature, "text").begins_with("@onready ")
			declaration["is_export"] = GF_VARIANT_ACCESS.get_option_string(signature, "text").begins_with("@export")
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
			if declaration_kind == "class":
				var owned_key: String = GF_VARIANT_ACCESS.get_option_string(owner_stack[-1], "key") + "::" + GF_VARIANT_ACCESS.get_option_string(declaration, "name")
				declaration["owned_key"] = owned_key
				owner_stack.append({"key": owned_key, "indent": indent, "declaration": declaration})
			if declaration_kind == "class" or declaration_kind == "class_name":
				for section_indent_variant: Variant in section_by_indent.keys():
					if GF_VARIANT_ACCESS.to_int(section_indent_variant) > indent:
						var _erase_result_1150: Variant = section_by_indent.erase(section_indent_variant)

			if declaration_kind == "func":
				function_body_indent = indent
			elif declaration_kind == "enum":
				enum_body_indent = indent
			elif (
				declaration_kind == "var"
				and GF_VARIANT_ACCESS.get_option_string(signature, "text").ends_with(":")
			):
				property_body_indent = indent
			skip_until_line = GF_VARIANT_ACCESS.get_option_int(signature, "end_line", line_index)
			multiline_string_delimiter = _update_multiline_string_delimiter(GF_VARIANT_ACCESS.get_option_string(signature, "text"), "")
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

	var lexical: Dictionary = CONTRACT_SOURCES.lex_line(text)
	var delimiter: String = lexical["multiline_delimiter"]
	var depth: int = _declaration_bracket_delta(GF_VARIANT_ACCESS.get_option_string(lexical, "code"))
	while end_line + 1 < lines.size():
		if depth <= 0 and delimiter.is_empty():
			var normalized: String = _strip_leading_annotations(_without_source_comments(text))
			var needs_declaration: bool = text.begins_with("@") and normalized.is_empty() and not _annotation_is_file_or_group_metadata(text)
			var needs_colon: bool = (normalized.begins_with("func ") or normalized.begins_with("static func ")) and _find_top_level_character(_without_source_comments(normalized), ":") == -1
			if not needs_declaration and not needs_colon:
				break
		end_line += 1
		var next_text: String = _trim_cr(String(lines[end_line])).strip_edges()
		text += "\n" + next_text
		lexical = CONTRACT_SOURCES.lex_line(next_text, delimiter)
		delimiter = lexical["multiline_delimiter"]
		depth += _declaration_bracket_delta(GF_VARIANT_ACCESS.get_option_string(lexical, "code"))

	return {
		"text": _without_source_comments(text),
		"end_line": end_line,
	}


func _can_have_multiline_signature(text: String) -> bool:
	return (
		text.begins_with("func ")
		or text.begins_with("static func ")
		or text.begins_with("signal ")
		or text.begins_with("var ")
		or text.begins_with("static var ")
		or text.begins_with("const ")
		or text.begins_with("enum ")
		or text.begins_with("@")
	)


func _annotation_is_file_or_group_metadata(text: String) -> bool:
	var annotation_name: String = _read_identifier(text.strip_edges().trim_prefix("@"))
	return annotation_name in ["tool", "icon", "export_group", "export_category", "export_subgroup"]


func _declaration_bracket_delta(code: String) -> int:
	var depth: int = 0
	for index: int in range(code.length()):
		var character: String = code[index]
		if character in ["(", "[", "{"]:
			depth += 1
		elif character in [")", "]", "}"]:
			depth -= 1
	return depth


func _without_source_comments(text: String) -> String:
	var result: String = ""
	var quote: String = ""
	var index: int = 0
	while index < text.length():
		var character: String = text[index]
		if not quote.is_empty():
			if character == "\\" and index + 1 < text.length():
				result += text.substr(index, 2)
				index += 2
				continue
			if text.substr(index, quote.length()) == quote:
				result += quote
				index += quote.length()
				quote = ""
				continue
		elif character == "#":
			var newline: int = text.find("\n", index)
			if newline == -1:
				break
			index = newline
			character = "\n"
		elif character == "\"" or character == "'":
			quote = character.repeat(3) if text.substr(index, 3) == character.repeat(3) else character
			result += quote
			index += quote.length()
			continue
		result += character
		index += 1
	return result


func _signature_balance(text: String) -> int:
	var depth: int = 0
	var quote: String = ""
	var index: int = 0
	while index < text.length():
		var character: String = text[index]
		if not quote.is_empty():
			if character == "\\":
				index += 2
				continue
			if text.substr(index, quote.length()) == quote:
				index += quote.length()
				quote = ""
				continue
		elif character == "#":
			var newline: int = text.find("\n", index)
			if newline == -1:
				break
			index = newline
		elif character == "\"" or character == "'":
			quote = character.repeat(3) if text.substr(index, 3) == character.repeat(3) else character
			index += quote.length()
			continue
		elif character in ["(", "[", "{"]:
			depth += 1
		elif character in [")", "]", "}"]:
			depth -= 1
		index += 1
	return depth + (1 if not quote.is_empty() else 0)


func _strip_leading_annotations(text: String) -> String:
	var remaining: String = text.strip_edges()
	while remaining.begins_with("@"):
		var index: int = 1
		while index < remaining.length() and _is_identifier_character(remaining[index]):
			index += 1
		if index < remaining.length() and remaining[index] == "(":
			var start: int = index
			index += 1
			while index < remaining.length() and _signature_balance(remaining.substr(start, index - start)) > 0:
				index += 1
		remaining = remaining.substr(index).strip_edges()
	return remaining


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
	var lexical: Dictionary = CONTRACT_SOURCES.lex_line(line, current_delimiter)
	return GF_VARIANT_ACCESS.get_option_string(lexical, "multiline_delimiter")


func _parse_declaration(trimmed: String) -> Dictionary:
	trimmed = _strip_leading_annotations(_without_source_comments(trimmed))
	if trimmed.begins_with("class_name "):
		return {
			"kind": "class_name",
			"name": _read_identifier(trimmed.substr("class_name ".length()).strip_edges()),
			"type": "",
			"params": [],
			"return_type": "",
		}

	if trimmed.begins_with("class "):
		var base_type: String = "RefCounted"
		if trimmed.contains(" extends "):
			base_type = trimmed.get_slice(" extends ", 1).trim_suffix(":").strip_edges()
		return {
			"kind": "class",
			"name": _read_identifier(trimmed.substr("class ".length()).strip_edges()),
			"type": "",
			"params": [],
			"return_type": "",
			"base_type": base_type,
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
	if trimmed.begins_with("var ") or trimmed.begins_with("static var "):
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
	var header_end: int = _find_top_level_character(trimmed, ":")
	if header_end != -1:
		trimmed = trimmed.substr(0, header_end + 1)
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
	var arrow_index: int = -1
	for candidate: int in _top_level_character_positions(signature, "-"):
		if signature.substr(candidate, 2) == "->":
			arrow_index = candidate
			break
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
			"has_default": default_index != -1,
			"default_expression": part.substr(default_index + 1).strip_edges() if default_index != -1 else "",
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
	if declaration.get("inherited_visibility", "") == "protected" and api in ["private", "framework_internal", "layer_internal"]:
		issues.append("%s %s inherited protected API cannot be downgraded to @api %s" % [location, declaration_name, api])

	if not api.is_empty() and not API_TAGS.has(api):
		issues.append("%s %s has invalid @api '%s'" % [location, declaration_name, api])

	if not docs.is_empty():
		var api_values: PackedStringArray = _parse_tag_values(docs, "api")
		if api_values.size() != 1 or not API_TAGS.has(api_values[0]):
			issues.append("%s %s doc comment must declare exactly one valid @api" % [location, declaration_name])
	if is_private and not docs.is_empty() and api != "private":
		issues.append("%s %s private members must declare @api private" % [location, declaration_name])

	if not docs.is_empty() and api.is_empty():
		issues.append("%s %s doc comment missing @api" % [location, declaration_name])

	if docs.is_empty() and _declaration_requires_api_doc(declaration):
		issues.append("%s %s missing API doc" % [location, declaration_name])

	if PUBLIC_API_TAGS.has(api) and GF_VARIANT_ACCESS.get_option_int(declaration, "indent", 0) == 0 and kind != "class_name" and not allows_top_level_public_api:
		var inherited_protected: bool = api == "protected" and declaration.get("inherited_visibility", "") == "protected" and GF_VARIANT_ACCESS.get_option_bool(declaration, "inherited_owner_proven")
		if not inherited_protected:
			issues.append("%s %s public top-level API requires class_name or controlled @api_owner autoload Gf" % [location, declaration_name])

	if api == "layer_internal" and GF_VARIANT_ACCESS.get_option_string(declaration, "layer", "").is_empty():
		issues.append("%s %s layer_internal API must declare @layer" % [location, declaration_name])

	var layer: String = GF_VARIANT_ACCESS.get_option_string(declaration, "layer", "")
	if not layer.is_empty() and not _layer_matches_source_path(layer, GF_VARIANT_ACCESS.get_option_string(declaration, "path", "")):
		issues.append("%s %s @layer '%s' does not match source path" % [location, declaration_name, layer])

	if (
		kind == "func"
		and _internal_section_rule_is_enforced(
			GF_VARIANT_ACCESS.get_option_string(declaration, "path", "")
		)
	):
		var declaration_path: String = GF_VARIANT_ACCESS.get_option_string(
			declaration,
			"path",
			""
		)
		var exact_section_is_enforced: bool = _exact_internal_section_rule_is_enforced(
			declaration_path
		)
		var section_name: String = _canonical_section_name(
			GF_VARIANT_ACCESS.get_option_string(declaration, "section", "")
		)
		if (
			api == "framework_internal"
			and (
				(exact_section_is_enforced and section_name != "框架内部方法")
				or (not exact_section_is_enforced and section_name == "公共方法")
			)
		):
			issues.append(
				"%s %s framework_internal API must be placed in a framework internal section"
				% [location, declaration_name]
			)
		if (
			api == "layer_internal"
			and (
				(exact_section_is_enforced and section_name != "层内方法")
				or (not exact_section_is_enforced and section_name == "公共方法")
			)
		):
			issues.append(
				"%s %s layer_internal API must be placed in a layer internal section"
				% [location, declaration_name]
			)

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

	if api == "private":
		issues.append_array(_collect_private_declaration_issues(declaration))
		issues.append_array(_collect_private_optional_tag_issues(declaration))
	elif not api.is_empty() and (kind == "func" or kind == "signal"):
		issues.append_array(_collect_param_doc_issues(declaration))

	if not api.is_empty() and api != "private" and kind == "func":
		issues.append_array(_collect_return_doc_issues(declaration))

	if not api.is_empty() and api != "private":
		issues.append_array(_collect_schema_issues(declaration))

	if PUBLIC_API_TAGS.has(api):
		issues.append_array(_collect_internal_type_exposure_issues(declaration, type_visibility))

	if kind == "enum" and PUBLIC_API_TAGS.has(api):
		issues.append_array(_collect_enum_value_doc_issues(declaration))

	return issues


func _collect_private_declaration_issues(declaration: Dictionary) -> Array[String]:
	var issues: Array[String] = []
	var declaration_name: String = GF_VARIANT_ACCESS.get_option_string(declaration, "name")
	var kind: String = GF_VARIANT_ACCESS.get_option_string(declaration, "kind")
	var location: String = _format_location(declaration)
	if not declaration_name.begins_with("_"):
		issues.append("%s %s private API must use an underscore name" % [location, declaration_name])
	if kind == "class_name":
		issues.append("%s %s class_name cannot declare @api private" % [location, declaration_name])
	var has_prose: bool = false
	for raw_doc: Variant in GF_VARIANT_ACCESS.get_option_array(declaration, "docs"):
		var body: String = _doc_body(GF_VARIANT_ACCESS.to_text(raw_doc)).replace(DOC_RENDER_SEPARATOR, "").strip_edges()
		if not body.is_empty() and not body.begins_with("@"):
			has_prose = true
	if not has_prose:
		issues.append("%s %s private doc must contain explanatory prose" % [location, declaration_name])
	var allowed_sections: Array[String] = []
	match kind:
		"func":
			if declaration_name == "_init":
				allowed_sections = ["Godot 生命周期方法"]
			elif GODOT_CALLBACK_NAMES.has(declaration_name):
				allowed_sections = ["Godot 生命周期方法", "Godot 回调方法"]
			elif declaration_name.begins_with("_on_"):
				allowed_sections = ["信号处理函数"]
			else:
				allowed_sections = ["私有/辅助方法", "Godot 回调方法"]
		"var":
			if GF_VARIANT_ACCESS.get_option_bool(declaration, "is_onready"):
				allowed_sections = ["@onready 变量"]
			elif GF_VARIANT_ACCESS.get_option_bool(declaration, "is_export"):
				allowed_sections = ["导出变量"]
			else:
				allowed_sections = ["私有变量"]
		"const":
			allowed_sections = ["常量"]
		"enum":
			allowed_sections = ["枚举"]
		"signal":
			allowed_sections = ["信号"]
		"class":
			allowed_sections = ["内部类"]
	var section_name: String = _canonical_section_name(GF_VARIANT_ACCESS.get_option_string(declaration, "section"))
	if kind != "class_name" and not allowed_sections.has(section_name):
		issues.append("%s %s private API uses an incompatible section '%s'" % [location, declaration_name, section_name])
	return issues


func _collect_private_optional_tag_issues(declaration: Dictionary) -> Array[String]:
	var issues: Array[String] = []
	var location: String = _format_location(declaration)
	var declaration_name: String = GF_VARIANT_ACCESS.get_option_string(declaration, "name")
	var kind: String = GF_VARIANT_ACCESS.get_option_string(declaration, "kind")
	var return_type: String = GF_VARIANT_ACCESS.get_option_string(declaration, "return_type")
	var has_return: bool = kind == "func" and not return_type.is_empty() and return_type != "void"
	var actual_params: Array[String] = []
	if kind == "func" or kind == "signal":
		for param: Dictionary in GF_VARIANT_ACCESS.get_option_array(declaration, "params"):
			actual_params.append(GF_VARIANT_ACCESS.get_option_string(param, "name"))
	var schema_targets: Array[String] = actual_params.duplicate()
	if has_return:
		schema_targets.append("return")
	if kind == "var" or kind == "const":
		schema_targets.append(declaration_name)
	var seen_params: Dictionary = {}
	var seen_schemas: Dictionary = {}
	var previous_param_index: int = -1
	var return_count: int = 0
	for raw_doc: Variant in GF_VARIANT_ACCESS.get_option_array(declaration, "docs"):
		var body: String = _doc_body(GF_VARIANT_ACCESS.to_text(raw_doc))
		if _is_doc_tag_line(body, "return"):
			return_count += 1
			if not has_return:
				issues.append("%s %s @return requires a non-void function" % [location, declaration_name])
			var return_description: String = body.trim_prefix("@return").strip_edges().trim_prefix(":").strip_edges()
			if return_description.replace(DOC_RENDER_SEPARATOR, "").strip_edges().is_empty():
				issues.append("%s %s @return requires a non-empty description" % [location, declaration_name])
			continue
		for tag_name: String in ["param", "schema"]:
			if not _is_doc_tag_line(body, tag_name):
				continue
			var rest: String = body.trim_prefix("@" + tag_name).strip_edges()
			var colon_index: int = rest.find(":")
			var target_name: String = rest.substr(0, colon_index).strip_edges() if colon_index >= 0 else rest
			var description: String = rest.substr(colon_index + 1).strip_edges() if colon_index >= 0 else ""
			if (
				target_name.is_empty()
				or target_name != _read_identifier(target_name)
				or description.replace(DOC_RENDER_SEPARATOR, "").strip_edges().is_empty()
			):
				issues.append("%s %s @%s requires a target and non-empty description after ':'" % [location, declaration_name, tag_name])
				continue
			if tag_name == "schema":
				if not schema_targets.has(target_name):
					issues.append("%s %s unknown @schema target '%s'" % [location, declaration_name, target_name])
				if seen_schemas.has(target_name):
					issues.append("%s %s duplicate @schema '%s'" % [location, declaration_name, target_name])
				seen_schemas[target_name] = true
				continue
			var param_index: int = actual_params.find(target_name)
			if param_index == -1:
				issues.append("%s %s documents unknown @param '%s'" % [location, declaration_name, target_name])
			if seen_params.has(target_name):
				issues.append("%s %s duplicate @param '%s'" % [location, declaration_name, target_name])
			if param_index >= 0 and param_index < previous_param_index:
				issues.append("%s %s @param order must follow the signature" % [location, declaration_name])
			seen_params[target_name] = true
			previous_param_index = maxi(previous_param_index, param_index)
	if return_count > 1:
		issues.append("%s %s duplicate @return" % [location, declaration_name])
	return issues


func _is_doc_tag_line(body: String, tag_name: String) -> bool:
	var prefix: String = "@" + tag_name
	return body == prefix or body.begins_with(prefix + " ") or body.begins_with(prefix + ":") or body.begins_with(prefix + "\t")


func _internal_section_rule_is_enforced(path: String) -> bool:
	for root: String in INTERNAL_SECTION_ENFORCED_ROOTS:
		if path.begins_with(root):
			return true
	return false


func _exact_internal_section_rule_is_enforced(path: String) -> bool:
	return path.begins_with(PROJECT_LAYOUT_STRICT_ROOT)


func _collect_public_api_doc_internal_reference_issues(
	declarations: Array[Dictionary],
	path: String
) -> Array[String]:
	if not _public_doc_internal_reference_rule_is_enforced(path):
		return []

	var internal_function_names: PackedStringArray = PackedStringArray()
	for declaration: Dictionary in declarations:
		if GF_VARIANT_ACCESS.get_option_string(declaration, "kind", "") != "func":
			continue
		var internal_api: String = GF_VARIANT_ACCESS.get_option_string(declaration, "api", "")
		if internal_api != "framework_internal" and internal_api != "layer_internal":
			continue
		var _append_internal_name_result: Variant = internal_function_names.append(
			GF_VARIANT_ACCESS.get_option_string(declaration, "name", "")
		)

	var issues: Array[String] = []
	for declaration: Dictionary in declarations:
		var public_api: String = GF_VARIANT_ACCESS.get_option_string(declaration, "api", "")
		if not PUBLIC_API_TAGS.has(public_api):
			continue
		var docs: Array = GF_VARIANT_ACCESS.get_option_array(declaration, "docs", [])
		for raw_doc_line: Variant in docs:
			var body: String = _doc_body(GF_VARIANT_ACCESS.to_text(raw_doc_line))
			for internal_function_name: String in internal_function_names:
				if not _text_references_identifier(body, internal_function_name):
					continue
				issues.append(
					"%s %s public API docs reference internal function '%s'" % [
						_format_location(declaration),
						GF_VARIANT_ACCESS.get_option_string(declaration, "name", ""),
						internal_function_name,
					]
				)
	return issues


func _public_doc_internal_reference_rule_is_enforced(path: String) -> bool:
	return path.begins_with(PROJECT_LAYOUT_STRICT_ROOT)


func _text_references_identifier(text: String, identifier: String) -> bool:
	if identifier.is_empty():
		return false
	var search_offset: int = 0
	while search_offset < text.length():
		var match_index: int = text.find(identifier, search_offset)
		if match_index == -1:
			return false
		var before_is_identifier: bool = (
			match_index > 0
			and _is_identifier_character(text[match_index - 1])
		)
		var after_index: int = match_index + identifier.length()
		var after_is_identifier: bool = (
			after_index < text.length()
			and _is_identifier_character(text[after_index])
		)
		if not before_is_identifier and not after_is_identifier:
			return true
		search_offset = after_index
	return false


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
	return GF_VARIANT_ACCESS.get_option_string(declaration, "inherited_contract").is_empty()


func _is_private_declaration(declaration: Dictionary) -> bool:
	var declaration_name: String = GF_VARIANT_ACCESS.get_option_string(declaration, "name", "")
	var api: String = GF_VARIANT_ACCESS.get_option_string(declaration, "api", "")
	if api in ["protected", "framework_internal", "layer_internal"]:
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


func _parse_tag_values(docs: Array, tag_name: String) -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	var prefix: String = "@%s" % tag_name
	for raw_line: Variant in docs:
		var body: String = _doc_body(GF_VARIANT_ACCESS.to_text(raw_line))
		if body == prefix:
			var _append_empty_result: Variant = result.append("")
			continue
		if _is_doc_tag_line(body, tag_name):
			var _append_value_result: Variant = result.append(body.substr(prefix.length()).strip_edges())
	return result


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
	for index: int in _top_level_character_positions(args_text, ","):
		var _append_result_1800: Variant = result.append(args_text.substr(start_index, index - start_index))
		start_index = index + 1
	var _append_result_1802: Variant = result.append(args_text.substr(start_index))
	return result


func _find_top_level_character(text: String, target: String) -> int:
	var positions: Array[int] = _top_level_character_positions(text, target)
	return positions[0] if not positions.is_empty() else -1


func _top_level_character_positions(text: String, target: String) -> Array[int]:
	var positions: Array[int] = []
	var depth: int = 0
	var offset: int = 0
	var delimiter: String = ""
	for line: String in text.split("\n"):
		var lexical: Dictionary = CONTRACT_SOURCES.lex_line(line, delimiter)
		delimiter = lexical["multiline_delimiter"]
		var code: String = lexical["code"]
		for index: int in range(code.length()):
			var character: String = code[index]
			if character == target and depth == 0:
				positions.append(offset + index)
			if character in ["(", "[", "{"]:
				depth += 1
			elif character in [")", "]", "}"]:
				depth -= 1
		offset += line.length() + 1
	return positions


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
