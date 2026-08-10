## 测试 GF 扩展 manifest 与目录发现辅助。
extends GutTest


# --- 常量 ---

const GF_EXTENSION_EXPORT_PLUGIN_BASE = preload("res://addons/gf/kernel/editor/extension/gf_extension_export_plugin.gd")
const GF_EXTENSION_PRESET_BASE = preload("res://addons/gf/kernel/extension/gf_extension_preset.gd")
const GF_EXTENSION_PRESET_DISCOVERY_SCRIPT = preload(
	"res://addons/gf/kernel/extension/gf_extension_preset_discovery.gd"
)
const GF_EXTENSION_MANIFEST_DISCOVERY_SCRIPT = preload(
	"res://addons/gf/kernel/extension/gf_extension_manifest_discovery.gd"
)
const GF_EXTENSION_SELECTION_DISCOVERY_SCRIPT = preload(
	"res://addons/gf/kernel/extension/gf_extension_selection_discovery.gd"
)
const GF_EXTENSION_TOOL_CONTRIBUTION_SCRIPT = preload("res://addons/gf/kernel/extension/gf_extension_tool_contribution.gd")
const GF_EXTENSION_JSON_FILE_READER_SCRIPT = preload(
	"res://addons/gf/kernel/extension/gf_extension_json_file_reader.gd"
)
const GF_VARIANT_ACCESS = preload("res://addons/gf/kernel/core/gf_variant_access.gd")
const EXTENSION_ROOT: String = "res://addons/gf/extensions"
const EXTENSION_ALLOWED_DEPENDENCIES: Array[String] = [
	"gf.kernel",
	"gf.standard",
]
const KERNEL_EXTENSION_REFERENCE_ALLOWED_FILES: Dictionary = {
	"res://addons/gf/kernel/extension/gf_extension_catalog.gd": true,
	"res://addons/gf/kernel/extension/gf_extension_usage_audit.gd": true,
}
const KERNEL_STANDARD_EXTENSION_CLASS_REFERENCE_ALLOWED_FILES: Dictionary = {
	"res://addons/gf/kernel/editor/gf_plugin_actions.gd": true,
}


class BinaryReferenceResource:
	extends Resource

	@export var dependency: Resource


# --- 测试方法 ---

func test_manifest_from_dictionary_normalizes_fields() -> void:
	var fixture_root: String = "res://tests/gf_core/tmp_manifest_normalization/terrain_tools"
	var fixture_editor_root: String = fixture_root.path_join("editor")
	var fixture_paths: Array[String] = [
		fixture_root.path_join("extension.gd"),
		fixture_editor_root.path_join("terrain_actions.gd"),
		fixture_editor_root.path_join("terrain_dock.gd"),
		fixture_editor_root.path_join("terrain_inspector.gd"),
		fixture_editor_root.path_join("terrain_import_plugin.gd"),
		fixture_editor_root.path_join("terrain_export_plugin.gd"),
		fixture_editor_root.path_join("terrain_gltf_extension.gd"),
		fixture_editor_root.path_join("terrain_access_generator.gd"),
	]
	for fixture_path: String in fixture_paths:
		_remove_path_if_exists(fixture_path)
	_remove_path_if_exists(fixture_editor_root)
	_remove_path_if_exists(fixture_root)
	var _make_fixture_dir_result: Variant = DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(fixture_editor_root))
	for fixture_path: String in fixture_paths:
		_write_text_file(fixture_path, "extends RefCounted\n")

	var manifest: GFExtensionManifest = GFExtensionManifest.from_dictionary({
		"id": " author.terrain ",
		"display_name": " Terrain Tools ",
		"version": " 1.0.0 ",
		"extension_version": " 1.2.3 ",
		"kind": " extension ",
		"description": " Example extension. ",
		"dependencies": [" gf.kernel ", &"gf.standard", "gf.standard", ""],
		"installer_paths": PackedStringArray([" %s " % fixture_root.path_join("extension.gd").replace("/", "\\")]),
		"editor_action_paths": [fixture_editor_root.path_join("terrain_actions.gd")],
		"editor_dock_paths": [fixture_editor_root.path_join("terrain_dock.gd")],
		"editor_dock_order": 42,
		"editor_dock_short_label": " Terrain ",
		"editor_inspector_paths": [fixture_editor_root.path_join("terrain_inspector.gd")],
		"import_plugin_paths": [fixture_editor_root.path_join("terrain_import_plugin.gd")],
		"export_plugin_paths": [fixture_editor_root.path_join("terrain_export_plugin.gd")],
		"gltf_document_extension_paths": [fixture_editor_root.path_join("terrain_gltf_extension.gd")],
		"access_generator_extension_paths": [fixture_editor_root.path_join("terrain_access_generator.gd")],
		"tags": [" terrain ", "editor", "terrain", ""],
		"enabled_by_default": false,
	}, " %s " % fixture_root.replace("/", "\\"), " %s " % fixture_root.path_join("gf_extension.json").replace("/", "\\"))

	assert_true(manifest.is_valid(), "完整 manifest 应通过基础校验。")
	assert_eq(manifest.id, "author.terrain", "应读取稳定扩展 ID。")
	assert_eq(manifest.display_name, "Terrain Tools", "显示名应裁剪空白。")
	assert_eq(manifest.version, "1.0.0", "应读取扩展发行版本。")
	assert_eq(manifest.extension_version, "1.2.3", "应读取扩展自身版本。")
	assert_eq(manifest.kind, GFExtensionManifest.KIND_EXTENSION, "扩展类型应读取为统一 extension。")
	assert_eq(manifest.dependencies, ["gf.kernel", "gf.standard"], "依赖列表应归一化为字符串数组。")
	assert_eq(manifest.root_path, fixture_root, "扩展根目录应规范化。")
	assert_eq(manifest.description, "Example extension.", "说明文本应裁剪空白。")
	assert_eq(manifest.installer_paths, [fixture_root.path_join("extension.gd")], "installer_paths 应支持 PackedStringArray 并规范化路径。")
	assert_eq(manifest.editor_action_paths.size(), 1, "editor_action_paths 应读取为字符串数组。")
	assert_eq(manifest.editor_dock_paths.size(), 1, "editor_dock_paths 应读取为字符串数组。")
	assert_eq(manifest.editor_dock_order, 42, "editor_dock_order 应读取为工作区排序值。")
	assert_eq(manifest.editor_dock_short_label, "Terrain", "editor_dock_short_label 应读取为工作区短标签。")
	assert_eq(manifest.editor_inspector_paths.size(), 1, "editor_inspector_paths 应读取为字符串数组。")
	assert_eq(manifest.import_plugin_paths.size(), 1, "import_plugin_paths 应读取为字符串数组。")
	assert_eq(manifest.export_plugin_paths.size(), 1, "export_plugin_paths 应读取为字符串数组。")
	assert_eq(manifest.gltf_document_extension_paths.size(), 1, "gltf_document_extension_paths 应读取为字符串数组。")
	assert_eq(manifest.access_generator_extension_paths.size(), 1, "access_generator_extension_paths 应读取为字符串数组。")
	assert_eq(manifest.tags, ["terrain", "editor"], "标签应裁剪、去空并按首次出现顺序去重。")
	assert_false(manifest.enabled_by_default, "显式关闭默认启用时应保留配置。")
	assert_eq(manifest.source_path, fixture_root.path_join("gf_extension.json"), "manifest 来源路径应规范化。")

	var dictionary: Dictionary = manifest.to_dictionary()
	assert_eq(GF_VARIANT_ACCESS.get_option_int(dictionary, "editor_dock_order"), 42, "manifest 字典应保留工作区排序。")
	assert_eq(GF_VARIANT_ACCESS.get_option_string(dictionary, "editor_dock_short_label"), "Terrain", "manifest 字典应保留工作区短标签。")
	assert_eq(GF_VARIANT_ACCESS.get_option_array(dictionary, "import_plugin_paths").size(), 1, "manifest 字典应保留导入插件路径。")
	assert_eq(GF_VARIANT_ACCESS.get_option_array(dictionary, "gltf_document_extension_paths").size(), 1, "manifest 字典应保留 glTF 文档扩展路径。")
	assert_false(dictionary.has("root_path"), "manifest JSON 字典不应混入运行时 root_path。")
	assert_false(dictionary.has("source_path"), "manifest JSON 字典不应混入运行时 source_path。")
	for index: int in range(fixture_paths.size() - 1, -1, -1):
		_remove_path_if_exists(fixture_paths[index])
	_remove_path_if_exists(fixture_editor_root)
	_remove_path_if_exists(fixture_root)


func test_extension_manifest_defaults_to_disabled_for_optional_extensions() -> void:
	var manifest: GFExtensionManifest = GFExtensionManifest.from_dictionary({
		"id": "gf.example",
		"display_name": "GF Example",
		"version": "3.0.0",
		"extension_version": "1.0.0",
		"kind": "extension",
	}, "res://addons/gf/extensions/example", "res://addons/gf/extensions/example/gf_extension.json")

	assert_false(manifest.enabled_by_default, "可选扩展未显式声明时不应默认启用。")


func test_standard_manifest_defaults_to_enabled() -> void:
	var manifest: GFExtensionManifest = GFExtensionManifest.from_dictionary({
		"id": "gf.standard",
		"display_name": "GF Standard",
		"version": "3.0.0",
		"extension_version": "1.0.0",
		"kind": "standard",
	}, "res://addons/gf/standard", "res://addons/gf/standard/gf_extension.json")

	assert_true(manifest.enabled_by_default, "standard 能力未显式声明时可作为基础能力默认启用。")


func test_manifest_validation_reports_required_fields() -> void:
	var manifest: GFExtensionManifest = GFExtensionManifest.from_dictionary({}, "", "")
	var errors: Array[String] = manifest.get_validation_errors()

	assert_true(errors.has("id is required"), "缺少 id 应报告错误。")
	assert_true(errors.has("display_name is required"), "缺少 display_name 应报告错误。")
	assert_true(errors.has("version is required"), "缺少 version 应报告错误。")
	assert_true(errors.has("root_path is required"), "缺少 root_path 应报告错误。")

	var invalid_kind_manifest: GFExtensionManifest = GFExtensionManifest.from_dictionary({
		"id": "gf.example",
		"display_name": "GF Example",
		"version": "3.1.0",
		"kind": "plugin",
	}, "res://addons/gf/extensions/example", "")
	var invalid_kind_errors: Array[String] = invalid_kind_manifest.get_validation_errors()

	assert_true(
		invalid_kind_errors.has("kind must be standard or extension"),
		"未知 kind 应报告错误。"
	)


func test_manifest_from_json_file_report_includes_parse_and_validation_errors() -> void:
	var root_path: String = "res://tests/gf_core/tmp_manifest_file_report"
	var parse_path: String = root_path.path_join(GFExtensionManifest.FILE_NAME)
	var invalid_path: String = root_path.path_join("invalid_extension.json")
	_remove_path_if_exists(parse_path)
	_remove_path_if_exists(invalid_path)
	_remove_path_if_exists(root_path)
	var _make_dir_result: Variant = DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(root_path))
	_write_text_file(parse_path, "{")
	_write_text_file(invalid_path, JSON.stringify({
		"display_name": "Invalid",
		"version": "1.0.0",
		"kind": "extension",
	}))

	var parse_report: Dictionary = GFExtensionManifest.from_json_file_report(parse_path)
	var invalid_report: Dictionary = GFExtensionManifest.from_json_file_report(invalid_path)
	var missing_report: Dictionary = GFExtensionManifest.from_json_file_report(root_path.path_join("missing.json"))
	var parse_manifest: GFExtensionManifest = GFExtensionManifest.from_json_file(parse_path)
	var invalid_manifest: GFExtensionManifest = GFExtensionManifest.from_json_file(invalid_path)
	var invalid_errors: Array = GF_VARIANT_ACCESS.get_option_array(invalid_report, "errors")
	var invalid_manifest_data: Dictionary = GF_VARIANT_ACCESS.get_option_dictionary(invalid_report, "manifest_data")
	var public_manifest_value: Variant = GF_VARIANT_ACCESS.get_option_value(invalid_report, "manifest")

	_remove_path_if_exists(parse_path)
	_remove_path_if_exists(invalid_path)
	_remove_path_if_exists(root_path)

	assert_false(GF_VARIANT_ACCESS.get_option_bool(parse_report, "ok"), "JSON 解析失败应返回诊断报告。")
	assert_true(GF_VARIANT_ACCESS.get_option_string_array(parse_report, "errors")[0].contains("could not parse JSON"), "解析报告应包含 JSON 错误。")
	assert_null(parse_manifest, "from_json_file 遇到解析失败时应返回 null。")
	assert_null(invalid_manifest, "from_json_file 遇到无效 manifest 时应返回 null。")
	assert_false(GF_VARIANT_ACCESS.get_option_bool(invalid_report, "ok"), "字段校验失败应返回 ok=false。")
	assert_true(invalid_errors.has("id is required"), "校验错误应进入诊断报告。")
	assert_eq(GF_VARIANT_ACCESS.get_option_string(invalid_manifest_data, "display_name"), "Invalid", "公开诊断应保留 JSON-safe manifest_data。")
	assert_true(public_manifest_value == null, "公开诊断不应返回 Godot 对象。")
	assert_false(GF_VARIANT_ACCESS.get_option_bool(missing_report, "ok"), "缺失文件应返回读取失败诊断。")


func test_manifest_schema_distinguishes_malformed_fields_from_defaults() -> void:
	var manifest: GFExtensionManifest = GFExtensionManifest.from_dictionary({
		"id": "author.schema",
		"display_name": "Schema",
		"version": "1.0.0",
		"kind": "extension",
		"dependencies": "gf.kernel",
		"tags": ["valid", 42],
		"editor_dock_order": true,
		"enabled_by_default": "false",
	}, "res://addons/author_schema", "")
	var errors: Array[String] = manifest.get_validation_errors()

	assert_false(manifest.is_valid(), "错误类型不能被静默转换为缺省值或宽松值。")
	assert_true(
		errors.has("manifest dependencies must be an array of strings"),
		"数组字段的标量 shorthand 必须明确失败。"
	)
	assert_true(
		errors.has("manifest tags must contain only strings"),
		"数组中的非字符串元素必须明确失败。"
	)
	assert_true(
		errors.has("manifest editor_dock_order must be an integer"),
		"bool 不能被隐式当作排序整数。"
	)
	assert_true(
		errors.has("manifest enabled_by_default must be a boolean"),
		"字符串不能被隐式当作启用开关。"
	)


func test_manifest_validation_rejects_non_canonical_extension_ids() -> void:
	var manifest: GFExtensionManifest = GFExtensionManifest.from_dictionary({
		"id": "GF.Save",
		"display_name": "GF Save",
		"version": "1.0.0",
		"kind": "extension",
		"dependencies": ["gf.kernel", "gf.Invalid"],
	}, "res://addons/gf/extensions/save", "")
	var errors: Array[String] = manifest.get_validation_errors()

	assert_false(GFExtensionManifest.is_valid_extension_id("GF.Save"), "大写扩展 ID 不应通过共享校验器。")
	assert_true(errors.has("id must use lowercase dotted identifier segments: GF.Save"), "manifest id 应使用严格小写 dotted identifier。")
	assert_true(errors.has("dependencies must use lowercase dotted identifier segments: gf.Invalid"), "manifest dependency ID 应使用同一套严格校验。")


func test_manifest_validation_rejects_unsupported_relation_fields() -> void:
	var manifest: GFExtensionManifest = GFExtensionManifest.from_dictionary({
		"id": "author.feature",
		"display_name": "Feature",
		"version": "1.0.0",
		"kind": "extension",
		"optional_dependencies": ["author.other"],
		"preset": "project.rpg",
		"load_after": ["author.base"],
		"debugger_plugin_paths": ["editor/debugger_plugin.gd"],
		"custom_field": true,
	}, "res://addons/author_feature", "")
	var errors: Array[String] = manifest.get_validation_errors()

	assert_false(manifest.is_valid(), "manifest 不能静默吞掉软依赖、组合或未知字段。")
	assert_true(
		errors.has("unsupported manifest relation field: optional_dependencies"),
		"optional_dependencies 会制造软依赖，应在 runtime 校验中被拒绝。"
	)
	assert_true(
		errors.has("unsupported manifest relation field: preset"),
		"preset 组合属于项目 preset/安装向导，不属于单个 manifest。"
	)
	assert_true(
		errors.has("unsupported manifest relation field: load_after"),
		"load_after 会制造隐式顺序关系，应被拒绝。"
	)
	assert_true(
		errors.has("unsupported manifest field: custom_field"),
		"未知字段不应被基础 manifest 校验静默忽略。"
	)
	assert_true(
		errors.has("unsupported manifest field: debugger_plugin_paths"),
		"Debugger 插件路径只属于 tool contribution，不应泄漏到 runtime manifest。"
	)


func test_manifest_rejects_legacy_name_and_summary_aliases() -> void:
	var manifest: GFExtensionManifest = GFExtensionManifest.from_dictionary({
		"id": "author.legacy",
		"name": "Legacy Name",
		"version": "1.0.0",
		"kind": "extension",
		"summary": "Legacy summary.",
	}, "res://addons/author_legacy", "")
	var errors: Array[String] = manifest.get_validation_errors()

	assert_false(manifest.is_valid(), "manifest 应只接受 display_name / description 规范字段。")
	assert_true(errors.has("unsupported manifest field: name"), "name 旧字段应被拒绝。")
	assert_true(errors.has("unsupported manifest field: summary"), "summary 旧字段应被拒绝。")


func test_manifest_validation_keeps_empty_paths_after_path_normalization() -> void:
	var manifest: GFExtensionManifest = GFExtensionManifest.from_dictionary({
		"id": "author.terrain",
		"display_name": "Terrain Tools",
		"version": "1.0.0",
		"kind": "extension",
		"editor_action_paths": [" ", " res://addons\\terrain_tools/editor/actions.gd "],
	}, "res://addons/terrain_tools", "")
	var errors: Array[String] = manifest.get_validation_errors()

	assert_eq(manifest.editor_action_paths[1], "res://addons/terrain_tools/editor/actions.gd", "路径列表应裁剪空白并统一斜杠。")
	assert_true(errors.has("editor_action_paths contains empty path"), "读取阶段不应吞掉空路径校验错误。")


func test_manifest_validation_keeps_extension_paths_inside_root() -> void:
	var manifest: GFExtensionManifest = GFExtensionManifest.from_dictionary({
		"id": "author.terrain",
		"display_name": "Terrain Tools",
		"version": "1.0.0",
		"kind": "extension",
		"editor_action_paths": ["res://addons/terrain_other/editor/actions.gd"],
		"import_plugin_paths": ["res://addons/terrain_other/editor/terrain_import_plugin.gd"],
		"export_plugin_paths": ["user://terrain_export_plugin.gd"],
		"gltf_document_extension_paths": ["res://addons/terrain_other/editor/gltf_extension.gd"],
	}, "res://addons/terrain_tools", "")
	var errors: Array[String] = manifest.get_validation_errors()

	assert_true(
		errors.has("editor_action_paths path must stay under root_path: res://addons/terrain_other/editor/actions.gd"),
		"扩展编辑器扩展路径不应越过扩展根目录。"
	)
	assert_true(
		errors.has("export_plugin_paths path must be res://: user://terrain_export_plugin.gd"),
		"扩展导出扩展应声明 res:// 脚本路径。"
	)
	assert_true(
		errors.has("import_plugin_paths path must stay under root_path: res://addons/terrain_other/editor/terrain_import_plugin.gd"),
		"扩展导入插件路径不应越过扩展根目录。"
	)
	assert_true(
		errors.has("gltf_document_extension_paths path must stay under root_path: res://addons/terrain_other/editor/gltf_extension.gd"),
		"扩展 glTF 文档扩展路径不应越过扩展根目录。"
	)


func test_manifest_validation_rejects_parent_directory_escape_paths() -> void:
	var manifest: GFExtensionManifest = GFExtensionManifest.from_dictionary({
		"id": "author.terrain",
		"display_name": "Terrain Tools",
		"version": "1.0.0",
		"kind": "extension",
		"editor_action_paths": ["res://addons/terrain_tools/../terrain_other/editor/actions.gd"],
	}, "res://addons/terrain_tools", "")
	var errors: Array[String] = manifest.get_validation_errors()

	assert_true(
		errors.has("editor_action_paths path must stay under root_path: res://addons/terrain_other/editor/actions.gd"),
		"包含 .. 的扩展路径规范化后不应越过扩展根目录。"
	)


func test_extension_preset_from_dictionary_normalizes_fields() -> void:
	var preset: Object = GF_EXTENSION_PRESET_BASE.from_dictionary({
		"id": " project.rpg ",
		"display_name": " RPG Tools ",
		"description": " Save and dialogue setup. ",
		"extension_ids": [" gf.save ", &"gf.dialogue", "gf.save", ""],
		"tags": [" rpg ", "tools", "rpg", ""],
	}, " res://config\\gf_rpg_preset.json ")
	var dictionary: Dictionary = GF_VARIANT_ACCESS.as_dictionary(preset.call("to_dictionary"))

	assert_true(GF_VARIANT_ACCESS.to_bool(preset.call("is_valid")), "完整 preset 应通过基础校验。")
	assert_eq(GF_VARIANT_ACCESS.to_string_name(preset.get("id")), &"project.rpg", "preset ID 应裁剪空白并转换为 StringName。")
	assert_eq(GF_VARIANT_ACCESS.to_text(preset.get("display_name")), "RPG Tools", "preset 显示名应裁剪空白。")
	assert_eq(GF_VARIANT_ACCESS.to_text(preset.get("description")), "Save and dialogue setup.", "preset 说明应裁剪空白。")
	assert_eq(GF_VARIANT_ACCESS.to_string_array(preset.get("extension_ids")), ["gf.save", "gf.dialogue"], "preset 扩展 ID 应去空去重并保持首次出现顺序。")
	assert_eq(GF_VARIANT_ACCESS.to_string_array(preset.get("tags")), ["rpg", "tools"], "preset 标签应去空去重。")
	assert_eq(GF_VARIANT_ACCESS.to_text(preset.get("source_path")), "res://config/gf_rpg_preset.json", "preset 来源路径应规范化。")
	assert_eq(GF_VARIANT_ACCESS.get_option_string(dictionary, "id"), "project.rpg", "preset 字典应保留 ID。")
	assert_eq(GF_VARIANT_ACCESS.get_option_array(dictionary, "extension_ids").size(), 2, "preset 字典应保留扩展 ID。")
	assert_false(dictionary.has("source_path"), "preset 输出字典应保持项目 preset JSON 白名单形状。")


func test_extension_preset_validation_reports_required_fields() -> void:
	var preset: Object = GF_EXTENSION_PRESET_BASE.from_dictionary({})
	var errors: Array[String] = GF_VARIANT_ACCESS.to_string_array(preset.call("get_validation_errors"))

	assert_true(errors.has("id is required"), "缺少 id 应报告错误。")
	assert_true(errors.has("display_name is required"), "缺少 display_name 应报告错误。")


func test_extension_preset_from_json_file_report_includes_parse_and_validation_errors() -> void:
	var root_path: String = "res://tests/gf_core/tmp_preset_file_report"
	var parse_path: String = root_path.path_join("broken.json")
	var invalid_path: String = root_path.path_join("invalid.json")
	_remove_path_if_exists(parse_path)
	_remove_path_if_exists(invalid_path)
	_remove_path_if_exists(root_path)
	var _make_dir_result: Variant = DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(root_path))
	_write_text_file(parse_path, "{")
	_write_text_file(invalid_path, JSON.stringify({
		"display_name": "Invalid",
		"extension_ids": [],
	}))

	var parse_report: Dictionary = GF_EXTENSION_PRESET_BASE.from_json_file_report(parse_path)
	var invalid_report: Dictionary = GF_EXTENSION_PRESET_BASE.from_json_file_report(invalid_path)
	var missing_report: Dictionary = GF_EXTENSION_PRESET_BASE.from_json_file_report(root_path.path_join("missing.json"))
	var parse_preset: Object = GF_EXTENSION_PRESET_BASE.from_json_file(parse_path)
	var invalid_preset: Object = GF_EXTENSION_PRESET_BASE.from_json_file(invalid_path)
	var invalid_errors: Array = GF_VARIANT_ACCESS.get_option_array(invalid_report, "errors")
	var invalid_preset_data: Dictionary = GF_VARIANT_ACCESS.get_option_dictionary(invalid_report, "preset_data")
	var public_preset_value: Variant = GF_VARIANT_ACCESS.get_option_value(invalid_report, "preset")

	_remove_path_if_exists(parse_path)
	_remove_path_if_exists(invalid_path)
	_remove_path_if_exists(root_path)

	assert_false(GF_VARIANT_ACCESS.get_option_bool(parse_report, "ok"), "JSON 解析失败应返回诊断报告。")
	assert_true(GF_VARIANT_ACCESS.get_option_string_array(parse_report, "errors")[0].contains("could not parse preset JSON"), "解析报告应包含 JSON 错误。")
	assert_null(parse_preset, "from_json_file 遇到解析失败时应返回 null。")
	assert_null(invalid_preset, "from_json_file 遇到无效 preset 时应返回 null。")
	assert_false(GF_VARIANT_ACCESS.get_option_bool(invalid_report, "ok"), "字段校验失败应返回 ok=false。")
	assert_true(invalid_errors.has("id is required"), "校验错误应进入诊断报告。")
	assert_eq(GF_VARIANT_ACCESS.get_option_string(invalid_preset_data, "display_name"), "Invalid", "公开诊断应保留 JSON-safe preset_data。")
	assert_true(public_preset_value == null, "公开诊断不应返回 Godot 对象。")
	assert_false(GF_VARIANT_ACCESS.get_option_bool(missing_report, "ok"), "缺失文件应返回读取失败诊断。")


func test_extension_preset_schema_distinguishes_malformed_fields_from_defaults() -> void:
	var preset: Object = GF_EXTENSION_PRESET_BASE.from_dictionary({
		"id": "project.schema",
		"display_name": "Schema",
		"description": 42,
		"extension_ids": "gf.save",
		"tags": ["valid", false],
	})
	var errors: Array[String] = GF_VARIANT_ACCESS.to_string_array(
		preset.call("get_validation_errors")
	)

	assert_false(
		GF_VARIANT_ACCESS.to_bool(preset.call("is_valid")),
		"preset 错误类型不能静默变成缺省值。"
	)
	assert_true(errors.has("preset description must be a string"), "文本字段必须保持字符串类型。")
	assert_true(
		errors.has("preset extension_ids must be an array of strings"),
		"extension_ids 标量 shorthand 必须明确失败。"
	)
	assert_true(
		errors.has("preset tags must contain only strings"),
		"tags 中的非字符串元素必须明确失败。"
	)


func test_extension_preset_validation_rejects_unsupported_boundary_fields() -> void:
	var preset: Object = GF_EXTENSION_PRESET_BASE.from_dictionary({
		"id": "project.rpg",
		"display_name": "RPG Tools",
		"extension_ids": ["gf.save"],
		"optional_dependencies": ["gf.dialogue"],
		"download_url": "https://example.invalid/package.zip",
		"installer_paths": ["res://addons/project_rpg/install.gd"],
		"custom_field": true,
	})
	var errors: Array[String] = GF_VARIANT_ACCESS.to_string_array(preset.call("get_validation_errors"))

	assert_false(
		GF_VARIANT_ACCESS.to_bool(preset.call("is_valid")),
		"preset 不能静默吞掉软依赖、下载包或未知字段。"
	)
	assert_true(
		errors.has("unsupported preset relation field: optional_dependencies"),
		"optional_dependencies 会让 preset 变成软依赖图，应在 runtime 校验中被拒绝。"
	)
	assert_true(
		errors.has("unsupported preset package field: download_url"),
		"download_url 属于外部下载器或包插件，不属于 GFExtensionPreset。"
	)
	assert_true(
		errors.has("unsupported preset package field: installer_paths"),
		"installer_paths 属于 manifest 装配入口，不应由启用组合覆盖。"
	)
	assert_true(
		errors.has("unsupported preset field: custom_field"),
		"未知字段不应被基础 preset 校验静默忽略。"
	)


func test_extension_preset_rejects_legacy_aliases() -> void:
	var preset: Object = GF_EXTENSION_PRESET_BASE.from_dictionary({
		"id": "project.legacy",
		"name": "Legacy Preset",
		"summary": "Legacy summary.",
		"extensions": ["gf.save", "gf.dialogue"],
	})
	var errors: Array[String] = GF_VARIANT_ACCESS.to_string_array(preset.call("get_validation_errors"))

	assert_false(GF_VARIANT_ACCESS.to_bool(preset.call("is_valid")), "preset 应只接受 display_name / description / extension_ids 规范字段。")
	assert_true(errors.has("unsupported preset field: name"), "name 旧字段应被拒绝。")
	assert_true(errors.has("unsupported preset field: summary"), "summary 旧字段应被拒绝。")
	assert_true(errors.has("unsupported preset field: extensions"), "extensions 旧字段应被拒绝。")


func test_catalog_loads_extension_manifests() -> void:
	var manifests: Array[GFExtensionManifest] = GFExtensionCatalog.load_extension_manifests()
	var ids: Array[String] = []
	for manifest: GFExtensionManifest in manifests:
		ids.append(manifest.id)
		assert_true(manifest.is_valid(), "%s manifest 应满足基础规范：%s" % [
			manifest.id,
			", ".join(manifest.get_validation_errors()),
		])

	assert_true(ids.has("gf.combat"), "扩展目录应能发现 combat manifest。")
	assert_true(ids.has("gf.network"), "扩展目录应能发现 network manifest。")
	assert_true(ids.has("gf.save"), "扩展目录应能发现 save manifest。")


func test_catalog_direct_load_clears_previous_manifest_errors() -> void:
	var root_path: String = "res://tests/gf_core/tmp_catalog_error_reset"
	var extension_dir: String = root_path.path_join("broken")
	var manifest_path: String = extension_dir.path_join(GFExtensionManifest.FILE_NAME)
	_cleanup_extension_root_fixture(root_path, extension_dir, manifest_path)
	var _make_dir_result: Variant = DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(extension_dir))
	_write_text_file(manifest_path, "{")

	var broken_manifests: Array[GFExtensionManifest] = GFExtensionCatalog.load_manifests_in(root_path)
	var broken_errors: Array[Dictionary] = GFExtensionCatalog.get_last_manifest_load_errors()
	var clean_manifests: Array[GFExtensionManifest] = GFExtensionCatalog.load_manifests_in(root_path.path_join("missing"))
	var clean_errors: Array[Dictionary] = GFExtensionCatalog.get_last_manifest_load_errors()

	_cleanup_extension_root_fixture(root_path, extension_dir, manifest_path)

	assert_true(broken_manifests.is_empty(), "坏 manifest 不应被加载。")
	assert_eq(broken_errors.size(), 1, "坏 manifest 应记录一次读取错误。")
	assert_true(clean_manifests.is_empty(), "空根目录不应加载 manifest。")
	assert_true(clean_errors.is_empty(), "后续直接扫描应清空上次读取错误。")


func test_catalog_direct_load_normalizes_public_root_path() -> void:
	var root_path: String = "res://tests/gf_core/tmp_catalog_normalized_root"
	var extension_dir: String = root_path.path_join("sample")
	var manifest_path: String = extension_dir.path_join(GFExtensionManifest.FILE_NAME)
	_cleanup_extension_root_fixture(root_path, extension_dir, manifest_path)
	var _make_dir_result: Variant = DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(extension_dir))
	_write_text_file(manifest_path, JSON.stringify({
		"id": "author.normalized",
		"display_name": "Normalized",
		"version": "1.0.0",
		"kind": "extension",
	}))

	var manifests: Array[GFExtensionManifest] = GFExtensionCatalog.load_manifests_in(root_path.replace("/", "\\"))

	_cleanup_extension_root_fixture(root_path, extension_dir, manifest_path)

	assert_eq(manifests.size(), 1, "public 入口应规范化 Windows 分隔符形式的 root。")
	assert_eq(manifests[0].id, "author.normalized", "规范化 root 后应能读取 manifest。")


func test_extension_json_reader_enforces_file_total_and_depth_budgets() -> void:
	var root_path: String = "user://gf_extension_json_budget"
	var first_path: String = root_path.path_join("first.json")
	var second_path: String = root_path.path_join("second.json")
	var deep_path: String = root_path.path_join("deep.json")
	_remove_path_if_exists(first_path)
	_remove_path_if_exists(second_path)
	_remove_path_if_exists(deep_path)
	_remove_path_if_exists(root_path)
	var _make_dir_result: Error = DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path(root_path)
	)
	var first_text: String = JSON.stringify({ "value": "first" })
	var second_text: String = JSON.stringify({ "value": "second" })
	var deep_text: String = '{"a":{"b":{"c":true}}}'
	_write_text_file(first_path, first_text)
	_write_text_file(second_path, second_text)
	_write_text_file(deep_path, deep_text)

	var first_bytes: int = first_text.to_utf8_buffer().size()
	var second_bytes: int = second_text.to_utf8_buffer().size()
	var file_limit_state: Dictionary = GF_EXTENSION_JSON_FILE_READER_SCRIPT.make_budget_state({
		"max_json_file_bytes": first_bytes - 1,
	})
	var oversized_report: Dictionary = GF_EXTENSION_JSON_FILE_READER_SCRIPT.read_object_report(
		first_path,
		{},
		file_limit_state
	)
	var total_state: Dictionary = GF_EXTENSION_JSON_FILE_READER_SCRIPT.make_budget_state({
		"max_json_total_bytes": first_bytes + second_bytes - 1,
	})
	var first_report: Dictionary = GF_EXTENSION_JSON_FILE_READER_SCRIPT.read_object_report(
		first_path,
		{},
		total_state
	)
	var second_report: Dictionary = GF_EXTENSION_JSON_FILE_READER_SCRIPT.read_object_report(
		second_path,
		{},
		total_state
	)
	var deep_report: Dictionary = GF_EXTENSION_JSON_FILE_READER_SCRIPT.read_object_report(
		deep_path,
		{ "max_json_depth": 2 }
	)
	var signature_state: Dictionary = GF_EXTENSION_JSON_FILE_READER_SCRIPT.make_budget_state()
	var signature: Dictionary = GF_EXTENSION_JSON_FILE_READER_SCRIPT.make_file_signature(
		first_path,
		{},
		signature_state
	)
	var forged_state: Dictionary = {
		"max_json_file_bytes": 1 << 40,
		"max_json_total_bytes": 1 << 40,
		"max_json_depth": 1 << 20,
		"consumed_bytes": -1,
		"budget_exceeded": false,
	}
	var forged_state_report: Dictionary = GF_EXTENSION_JSON_FILE_READER_SCRIPT.read_object_report(
		first_path,
		{ "max_json_file_bytes": first_bytes - 1 },
		forged_state
	)

	_remove_path_if_exists(first_path)
	_remove_path_if_exists(second_path)
	_remove_path_if_exists(deep_path)
	_remove_path_if_exists(root_path)

	assert_false(GF_VARIANT_ACCESS.get_option_bool(oversized_report, "ok"), "单文件超限应在 JSON.parse 前失败。")
	assert_true(
		GF_VARIANT_ACCESS.get_option_string_array(oversized_report, "errors").any(
			func(error: String) -> bool: return error.contains("max_json_file_bytes")
		),
		"单文件预算错误应包含稳定 limit key。"
	)
	assert_true(GF_VARIANT_ACCESS.get_option_bool(first_report, "ok"), "累计预算内的第一个文件应成功。")
	assert_false(GF_VARIANT_ACCESS.get_option_bool(second_report, "ok"), "累计预算+1 必须失败关闭。")
	assert_true(
		GF_VARIANT_ACCESS.get_option_string_array(second_report, "errors").any(
			func(error: String) -> bool: return error.contains("max_json_total_bytes")
		),
		"累计预算错误应包含稳定 limit key。"
	)
	assert_false(GF_VARIANT_ACCESS.get_option_bool(deep_report, "ok"), "超过词法嵌套深度应在 parse 前失败。")
	assert_true(
		GF_VARIANT_ACCESS.get_option_string_array(deep_report, "errors").any(
			func(error: String) -> bool: return error.contains("max_json_depth")
		),
		"深度错误应包含稳定 limit key。"
	)
	assert_true(GF_VARIANT_ACCESS.get_option_bool(signature, "ok"), "预算内文件应能生成流式签名。")
	assert_eq(
		GF_VARIANT_ACCESS.get_option_string(signature, "content_sha256"),
		first_text.sha256_text(),
		"流式 SHA-256 必须与内容摘要一致。"
	)
	assert_false(
		GF_VARIANT_ACCESS.get_option_bool(forged_state_report, "ok"),
		"手工构造的共享状态不得绕过调用方更严格的单文件预算。"
	)
	assert_eq(
		GF_VARIANT_ACCESS.get_option_int(forged_state, "max_json_file_bytes"),
		first_bytes - 1,
		"共享状态必须取调用方预算、既有状态与框架硬上限的最小值。"
	)
	assert_eq(
		GF_VARIANT_ACCESS.get_option_int(forged_state, "max_json_total_bytes"),
		64 * 1024 * 1024,
		"手工构造的累计预算不得放宽框架硬上限。"
	)
	assert_eq(
		GF_VARIANT_ACCESS.get_option_int(forged_state, "max_json_depth"),
		64,
		"手工构造的嵌套预算不得放宽框架硬上限。"
	)
	assert_eq(
		GF_VARIANT_ACCESS.get_option_int(forged_state, "consumed_bytes"),
		0,
		"共享预算的负累计值必须规范化为零。"
	)


func test_catalog_rejects_manifest_before_parsing_when_json_budget_is_exceeded() -> void:
	var root_path: String = "res://tests/gf_core/tmp_catalog_json_budget"
	var extension_dir: String = root_path.path_join("oversized")
	var manifest_path: String = extension_dir.path_join(GFExtensionManifest.FILE_NAME)
	_cleanup_extension_root_fixture(root_path, extension_dir, manifest_path)
	var _make_dir_result: Error = DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path(extension_dir)
	)
	_write_text_file(manifest_path, JSON.stringify({
		"id": "author.oversized",
		"display_name": "Oversized",
		"version": "1.0.0",
		"kind": "extension",
	}))

	var manifests: Array[GFExtensionManifest] = GFExtensionCatalog.load_manifests_in(
		root_path,
		{ "max_json_file_bytes": 32 }
	)
	var errors: Array[Dictionary] = GFExtensionCatalog.get_last_manifest_load_errors()
	_cleanup_extension_root_fixture(root_path, extension_dir, manifest_path)

	assert_true(manifests.is_empty(), "超出 JSON 单文件预算的 manifest 不得进入 catalog。")
	assert_eq(errors.size(), 1, "catalog 应保留一条结构化读取错误。")
	assert_true(
		GF_VARIANT_ACCESS.get_option_string_array(errors[0], "errors").any(
			func(error: String) -> bool: return error.contains("max_json_file_bytes")
		),
		"catalog 错误应暴露命中的 JSON limit。"
	)


func test_extension_settings_loads_external_extension_roots_from_project_settings() -> void:
	var root_path: String = "res://tests/gf_core/tmp_external_extensions"
	var extension_dir: String = root_path.path_join("sample")
	var manifest_path: String = extension_dir.path_join(GFExtensionManifest.FILE_NAME)
	_remove_path_if_exists(manifest_path)
	_remove_path_if_exists(extension_dir)
	_remove_path_if_exists(root_path)
	var _make_dir_result: Variant = DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(extension_dir))
	_write_text_file(manifest_path, JSON.stringify({
		"id": "author.external",
		"display_name": "External",
		"version": "1.0.0",
		"kind": "extension",
		"enabled_by_default": false,
	}))
	var restore: Dictionary = _set_project_setting(
		GFExtensionSettings.EXTERNAL_EXTENSION_ROOTS_SETTING,
		[root_path, root_path + "/", root_path.replace("/", "\\"), "user://ignored"]
	)
	GFExtensionSettings.clear_manifest_cache()

	var roots: Array[String] = GFExtensionSettings.get_external_extension_roots()
	var manifest: GFExtensionManifest = GFExtensionSettings.get_manifest_by_id("author.external")
	var report: Dictionary = GFExtensionSettings.get_extension_selection_report()
	var external_roots: Array = GF_VARIANT_ACCESS.get_option_array(report, "external_roots")

	GFExtensionSettings.clear_manifest_cache()
	_restore_project_setting(GFExtensionSettings.EXTERNAL_EXTENSION_ROOTS_SETTING, restore)
	_remove_path_if_exists(manifest_path)
	_remove_path_if_exists(extension_dir)
	_remove_path_if_exists(root_path)

	assert_eq(roots, [root_path], "额外扩展根目录应去重并过滤非 res:// 路径。")
	assert_not_null(manifest, "ProjectSettings 声明的额外扩展根目录应参与 manifest 发现。")
	assert_eq(manifest.root_path, extension_dir, "外部 manifest root_path 应指向扩展自身目录。")
	assert_eq(external_roots, [root_path], "启用状态诊断应暴露当前额外扩展根目录。")


func test_extension_settings_default_selection_mode_uses_manifest_defaults_without_persisted_enabled_ids() -> void:
	var default_manifest: GFExtensionManifest = GFExtensionManifest.from_dictionary({
		"id": "author.default",
		"display_name": "Default",
		"version": "1.0.0",
		"kind": "extension",
		"enabled_by_default": true,
	}, "res://addons/author_default", "")
	var optional_manifest: GFExtensionManifest = GFExtensionManifest.from_dictionary({
		"id": "author.optional",
		"display_name": "Optional",
		"version": "1.0.0",
		"kind": "extension",
		"enabled_by_default": false,
	}, "res://addons/author_optional", "")
	var selection_mode_restore: Dictionary = _set_project_setting(
		GFExtensionSettings.EXTENSION_SELECTION_MODE_SETTING,
		GFExtensionSettings.SELECTION_MODE_DEFAULT
	)
	var enabled_restore: Dictionary = _set_project_setting(
		GFExtensionSettings.ENABLED_EXTENSIONS_SETTING,
		["author.optional"]
	)
	var selection_mode_after_enabled_restore: Dictionary = _set_project_setting(
		GFExtensionSettings.EXTENSION_SELECTION_MODE_SETTING,
		GFExtensionSettings.SELECTION_MODE_DEFAULT
	)
	GFExtensionSettings.set_cached_manifests([default_manifest, optional_manifest])

	var enabled_ids: Array[String] = GFExtensionSettings.get_enabled_extension_ids()
	var report: Dictionary = GFExtensionSettings.get_extension_selection_report()

	GFExtensionSettings.clear_manifest_cache()
	_restore_project_setting(GFExtensionSettings.EXTENSION_SELECTION_MODE_SETTING, selection_mode_after_enabled_restore)
	_restore_project_setting(GFExtensionSettings.ENABLED_EXTENSIONS_SETTING, enabled_restore)
	_restore_project_setting(GFExtensionSettings.EXTENSION_SELECTION_MODE_SETTING, selection_mode_restore)

	assert_eq(enabled_ids, ["author.default"], "默认选择模式应按当前 manifest 默认启用声明派生启用列表。")
	assert_eq(
		GF_VARIANT_ACCESS.get_option_string(report, "selection_mode"),
		GFExtensionSettings.SELECTION_MODE_DEFAULT,
		"启用状态诊断应暴露默认选择模式。"
	)
	assert_eq(
		GF_VARIANT_ACCESS.get_option_array(report, "explicit_ids"),
		["author.optional"],
		"诊断应保留显式列表字段，方便区分存储值和有效默认选择。"
	)


func test_extension_settings_set_enabled_ids_switches_to_explicit_selection_mode() -> void:
	var selection_mode_restore: Dictionary = _set_project_setting(
		GFExtensionSettings.EXTENSION_SELECTION_MODE_SETTING,
		GFExtensionSettings.SELECTION_MODE_DEFAULT
	)
	var enabled_restore: Dictionary = _set_project_setting(
		GFExtensionSettings.ENABLED_EXTENSIONS_SETTING,
		[]
	)

	GFExtensionSettings.set_enabled_extension_ids(["gf.save"], false)
	var selection_mode: String = GFExtensionSettings.get_extension_selection_mode()
	var enabled_ids: Array[String] = GFExtensionSettings.get_enabled_extension_ids()

	_restore_project_setting(GFExtensionSettings.ENABLED_EXTENSIONS_SETTING, enabled_restore)
	_restore_project_setting(GFExtensionSettings.EXTENSION_SELECTION_MODE_SETTING, selection_mode_restore)

	assert_eq(selection_mode, GFExtensionSettings.SELECTION_MODE_EXPLICIT, "显式保存启用列表时应切换到 explicit 模式。")
	assert_eq(enabled_ids, ["gf.save"], "explicit 模式应读取显式保存的启用列表。")


func test_extension_settings_ensure_defaults_infers_legacy_explicit_enabled_list() -> void:
	var selection_mode_restore: Dictionary = _set_project_setting(
		GFExtensionSettings.EXTENSION_SELECTION_MODE_SETTING,
		GFExtensionSettings.SELECTION_MODE_DEFAULT
	)
	var enabled_restore: Dictionary = _set_project_setting(
		GFExtensionSettings.ENABLED_EXTENSIONS_SETTING,
		["gf.save"]
	)
	ProjectSettings.clear(GFExtensionSettings.EXTENSION_SELECTION_MODE_SETTING)

	var changed: bool = GFExtensionSettings.ensure_defaults()
	var selection_mode: String = GFExtensionSettings.get_extension_selection_mode()

	_restore_project_setting(GFExtensionSettings.ENABLED_EXTENSIONS_SETTING, enabled_restore)
	_restore_project_setting(GFExtensionSettings.EXTENSION_SELECTION_MODE_SETTING, selection_mode_restore)

	assert_true(changed, "缺少 selection mode 时 ensure_defaults 应写入迁移后的项目设置。")
	assert_eq(selection_mode, GFExtensionSettings.SELECTION_MODE_EXPLICIT, "旧项目已有非空 enabled 列表时应迁移为 explicit 模式。")


func test_extension_settings_refreshes_manifest_cache_when_external_roots_setting_changes_directly() -> void:
	var first_root_path: String = "res://tests/gf_core/tmp_external_roots_first"
	var second_root_path: String = "res://tests/gf_core/tmp_external_roots_second"
	var first_extension_dir: String = first_root_path.path_join("first")
	var second_extension_dir: String = second_root_path.path_join("second")
	var first_manifest_path: String = first_extension_dir.path_join(GFExtensionManifest.FILE_NAME)
	var second_manifest_path: String = second_extension_dir.path_join(GFExtensionManifest.FILE_NAME)
	_cleanup_extension_root_fixture(first_root_path, first_extension_dir, first_manifest_path)
	_cleanup_extension_root_fixture(second_root_path, second_extension_dir, second_manifest_path)
	var _make_first_dir_result: Variant = DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(first_extension_dir))
	var _make_second_dir_result: Variant = DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(second_extension_dir))
	_write_text_file(first_manifest_path, JSON.stringify({
		"id": "author.first",
		"display_name": "First",
		"version": "1.0.0",
		"kind": "extension",
	}))
	_write_text_file(second_manifest_path, JSON.stringify({
		"id": "author.second",
		"display_name": "Second",
		"version": "1.0.0",
		"kind": "extension",
	}))
	var restore: Dictionary = _set_project_setting(
		GFExtensionSettings.EXTERNAL_EXTENSION_ROOTS_SETTING,
		[first_root_path]
	)
	GFExtensionSettings.clear_manifest_cache()

	var first_manifest: GFExtensionManifest = GFExtensionSettings.get_manifest_by_id("author.first")
	ProjectSettings.set_setting(GFExtensionSettings.EXTERNAL_EXTENSION_ROOTS_SETTING, [second_root_path])
	var second_manifest: GFExtensionManifest = GFExtensionSettings.get_manifest_by_id("author.second")
	var stale_first_manifest: GFExtensionManifest = GFExtensionSettings.get_manifest_by_id("author.first")

	GFExtensionSettings.clear_manifest_cache()
	_restore_project_setting(GFExtensionSettings.EXTERNAL_EXTENSION_ROOTS_SETTING, restore)
	_cleanup_extension_root_fixture(first_root_path, first_extension_dir, first_manifest_path)
	_cleanup_extension_root_fixture(second_root_path, second_extension_dir, second_manifest_path)

	assert_not_null(first_manifest, "初始 external root 应进入 manifest 缓存。")
	assert_not_null(second_manifest, "直接修改 ProjectSettings external roots 后应刷新 manifest 缓存。")
	assert_null(stale_first_manifest, "刷新后旧 external root 的 manifest 不应残留。")


func test_extension_settings_refreshes_manifest_cache_when_manifest_file_changes_in_same_root() -> void:
	var root_path: String = "res://tests/gf_core/tmp_manifest_cache_file_change"
	var extension_dir: String = root_path.path_join("feature")
	var manifest_path: String = extension_dir.path_join(GFExtensionManifest.FILE_NAME)
	_cleanup_extension_root_fixture(root_path, extension_dir, manifest_path)
	var _make_dir_result: Variant = DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(extension_dir))
	_write_text_file(manifest_path, JSON.stringify({
		"id": "author.cached",
		"display_name": "Cached",
		"version": "1.0.0",
		"kind": "extension",
	}))
	var restore: Dictionary = _set_project_setting(
		GFExtensionSettings.EXTERNAL_EXTENSION_ROOTS_SETTING,
		[root_path]
	)
	GFExtensionSettings.clear_manifest_cache()

	var first_manifest: GFExtensionManifest = GFExtensionSettings.get_manifest_by_id("author.cached")
	_write_text_file(manifest_path, JSON.stringify({
		"id": "author.cached",
		"display_name": "Cached Renamed",
		"version": "1.0.1",
		"kind": "extension",
	}))
	var refreshed_manifest: GFExtensionManifest = GFExtensionSettings.get_manifest_by_id("author.cached")

	GFExtensionSettings.clear_manifest_cache()
	_restore_project_setting(GFExtensionSettings.EXTERNAL_EXTENSION_ROOTS_SETTING, restore)
	_cleanup_extension_root_fixture(root_path, extension_dir, manifest_path)

	assert_not_null(first_manifest, "初始 manifest 应进入发现快照。")
	assert_eq(first_manifest.display_name, "Cached", "初始读取应使用第一次写入的 manifest。")
	assert_not_null(refreshed_manifest, "同一 root 内 manifest 文件变化后应自动刷新快照。")
	assert_eq(refreshed_manifest.display_name, "Cached Renamed", "刷新后应读取新的 manifest 内容。")


func test_extension_selection_cache_identity_covers_validation_and_metadata() -> void:
	var manifest: GFExtensionManifest = GFExtensionManifest.from_dictionary({
		"id": "author.semantic_cache",
		"display_name": "Semantic Cache",
		"version": "1.0.0",
		"kind": "extension",
		"description": "first",
		"installer_paths": ["res://addons/author_semantic_cache/install.gd"],
	}, "res://addons/author_semantic_cache", "")
	var manifests: Array[GFExtensionManifest] = [manifest]
	var configured_ids: Array[String] = ["author.semantic_cache"]
	GF_EXTENSION_SELECTION_DISCOVERY_SCRIPT.clear_cache()

	var first_snapshot: Dictionary = GF_EXTENSION_SELECTION_DISCOVERY_SCRIPT.get_snapshot(
		manifests,
		configured_ids,
		{ "force_refresh": true }
	)
	var first_revision: int = GF_VARIANT_ACCESS.get_option_int(first_snapshot, "revision")
	manifest.display_name = ""
	var invalid_snapshot: Dictionary = GF_EXTENSION_SELECTION_DISCOVERY_SCRIPT.get_snapshot(
		manifests,
		configured_ids
	)
	var invalid_paths: Dictionary = GF_VARIANT_ACCESS.get_option_dictionary(
		invalid_snapshot,
		"paths"
	)
	var invalid_graph: Dictionary = GF_VARIANT_ACCESS.get_option_dictionary(
		invalid_snapshot,
		"graph_report"
	)

	manifest.display_name = "Semantic Cache"
	manifest.description = "second"
	var metadata_snapshot: Dictionary = GF_EXTENSION_SELECTION_DISCOVERY_SCRIPT.get_snapshot(
		manifests,
		configured_ids
	)
	var enabled_manifests: Array = GF_VARIANT_ACCESS.get_option_array(
		metadata_snapshot,
		"enabled_manifests"
	)
	GF_EXTENSION_SELECTION_DISCOVERY_SCRIPT.clear_cache()

	assert_true(GF_VARIANT_ACCESS.get_option_bool(first_snapshot, "ok"), "初始合法快照应有效。")
	assert_gt(
		GF_VARIANT_ACCESS.get_option_int(invalid_snapshot, "revision"),
		first_revision,
		"只修改 validation 字段也必须使 selection revision 前进。"
	)
	assert_false(
		GF_VARIANT_ACCESS.get_option_bool(invalid_snapshot, "graph_ok", true),
		"合法到非法的字段变更必须立即重新校验。"
	)
	assert_false(
		GF_VARIANT_ACCESS.get_option_array(invalid_graph, "invalid_manifests").is_empty(),
		"新 validation error 必须进入 graph 诊断。"
	)
	assert_true(
		GF_VARIANT_ACCESS.get_option_string_array(invalid_paths, "installer_paths").is_empty(),
		"非法 manifest 必须撤销旧 installer path 授权。"
	)
	assert_eq(enabled_manifests.size(), 1, "恢复合法字段后应重新生成启用 manifest。")
	if enabled_manifests.size() == 1 and enabled_manifests[0] is GFExtensionManifest:
		var refreshed_manifest: GFExtensionManifest = enabled_manifests[0]
		assert_eq(
			refreshed_manifest.description,
			"second",
			"只修改返回 metadata 也必须刷新缓存值。"
		)


func test_extension_settings_refreshes_manifest_cache_when_manifest_is_added_in_same_root() -> void:
	var root_path: String = "res://tests/gf_core/tmp_manifest_cache_added"
	var first_extension_dir: String = root_path.path_join("first")
	var second_extension_dir: String = root_path.path_join("second")
	var first_manifest_path: String = first_extension_dir.path_join(GFExtensionManifest.FILE_NAME)
	var second_manifest_path: String = second_extension_dir.path_join(GFExtensionManifest.FILE_NAME)
	_remove_path_if_exists(first_manifest_path)
	_remove_path_if_exists(second_manifest_path)
	_remove_path_if_exists(first_extension_dir)
	_remove_path_if_exists(second_extension_dir)
	_remove_path_if_exists(root_path)
	var _make_first_dir_result: Variant = DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(first_extension_dir))
	_write_text_file(first_manifest_path, JSON.stringify({
		"id": "author.first",
		"display_name": "First",
		"version": "1.0.0",
		"kind": "extension",
	}))
	var restore: Dictionary = _set_project_setting(
		GFExtensionSettings.EXTERNAL_EXTENSION_ROOTS_SETTING,
		[root_path]
	)
	GFExtensionSettings.clear_manifest_cache()

	var first_manifest: GFExtensionManifest = GFExtensionSettings.get_manifest_by_id("author.first")
	var _make_second_dir_result: Variant = DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(second_extension_dir))
	_write_text_file(second_manifest_path, JSON.stringify({
		"id": "author.second",
		"display_name": "Second",
		"version": "1.0.0",
		"kind": "extension",
	}))
	var second_manifest: GFExtensionManifest = GFExtensionSettings.get_manifest_by_id("author.second")

	GFExtensionSettings.clear_manifest_cache()
	_restore_project_setting(GFExtensionSettings.EXTERNAL_EXTENSION_ROOTS_SETTING, restore)
	_remove_path_if_exists(second_manifest_path)
	_remove_path_if_exists(first_manifest_path)
	_remove_path_if_exists(second_extension_dir)
	_remove_path_if_exists(first_extension_dir)
	_remove_path_if_exists(root_path)

	assert_not_null(first_manifest, "初始 manifest 应进入发现快照。")
	assert_not_null(second_manifest, "同一 root 内新增 manifest 后应自动刷新快照。")
	assert_eq(second_manifest.display_name, "Second", "刷新后应能读取新增扩展 manifest。")


func test_extension_settings_manual_manifest_cache_invalidates_when_manifest_sources_change() -> void:
	var root_path: String = "res://tests/gf_core/tmp_manual_manifest_cache"
	var extension_dir: String = root_path.path_join("actual")
	var manifest_path: String = extension_dir.path_join(GFExtensionManifest.FILE_NAME)
	_cleanup_extension_root_fixture(root_path, extension_dir, manifest_path)
	var _make_root_result: Variant = DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(root_path))
	var restore: Dictionary = _set_project_setting(
		GFExtensionSettings.EXTERNAL_EXTENSION_ROOTS_SETTING,
		[root_path]
	)
	GFExtensionSettings.clear_manifest_cache()
	var manual_manifest: GFExtensionManifest = GFExtensionManifest.from_dictionary({
		"id": "author.manual",
		"display_name": "Manual",
		"version": "1.0.0",
		"kind": "extension",
	}, "res://addons/author_manual", "")
	GFExtensionSettings.set_cached_manifests([manual_manifest])

	var manual_read: GFExtensionManifest = GFExtensionSettings.get_manifest_by_id("author.manual")
	var _make_extension_dir_result: Variant = DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(extension_dir))
	_write_text_file(manifest_path, JSON.stringify({
		"id": "author.actual",
		"display_name": "Actual",
		"version": "1.0.0",
		"kind": "extension",
	}))
	var actual_read: GFExtensionManifest = GFExtensionSettings.get_manifest_by_id("author.actual")
	var stale_manual_read: GFExtensionManifest = GFExtensionSettings.get_manifest_by_id("author.manual")

	GFExtensionSettings.clear_manifest_cache()
	_restore_project_setting(GFExtensionSettings.EXTERNAL_EXTENSION_ROOTS_SETTING, restore)
	_cleanup_extension_root_fixture(root_path, extension_dir, manifest_path)

	assert_not_null(manual_read, "手动写入的 manifest 应在发现签名未变化时可读。")
	assert_not_null(actual_read, "manifest 来源变化后应丢弃手动快照并读取真实文件。")
	assert_null(stale_manual_read, "自动刷新后旧手动 manifest 不应继续残留。")


func test_extension_manifest_discovery_snapshot_reports_validation_errors() -> void:
	var root_path: String = "res://tests/gf_core/tmp_discovery_invalid_manifest"
	var extension_dir: String = root_path.path_join("invalid")
	var manifest_path: String = extension_dir.path_join(GFExtensionManifest.FILE_NAME)
	_cleanup_extension_root_fixture(root_path, extension_dir, manifest_path)
	var _make_dir_result: Variant = DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(extension_dir))
	_write_text_file(manifest_path, JSON.stringify({
		"id": "author.invalid",
		"version": "1.0.0",
		"kind": "extension",
	}))
	GFExtensionManifestDiscovery.clear_cache()

	var snapshot: Dictionary = GFExtensionManifestDiscovery.get_snapshot([root_path], { "force_refresh": true })
	var manifest_load_errors: Array = GF_VARIANT_ACCESS.get_option_array(snapshot, "manifest_load_errors")
	var manifest_validation_errors: Array = GF_VARIANT_ACCESS.get_option_array(snapshot, "manifest_validation_errors")
	var invalid_manifests: Array = GF_VARIANT_ACCESS.get_option_array(snapshot, "invalid_manifests")
	var snapshot_manifests: Array = GF_VARIANT_ACCESS.get_option_array(snapshot, "manifests")

	GFExtensionManifestDiscovery.clear_cache()
	_cleanup_extension_root_fixture(root_path, extension_dir, manifest_path)

	assert_false(GF_VARIANT_ACCESS.get_option_bool(snapshot, "ok"), "可读取但未通过校验的 manifest 应让 discovery snapshot 失败。")
	assert_eq(manifest_load_errors.size(), 0, "可解析的 manifest 不应进入 load errors。")
	assert_eq(manifest_validation_errors.size(), 1, "可解析但无效的 manifest 应进入 validation errors。")
	assert_eq(invalid_manifests.size(), 1, "validation errors 应折叠进 invalid_manifests。")
	assert_eq(GF_VARIANT_ACCESS.get_option_int(snapshot, "invalid_manifest_count"), 1, "invalid_manifest_count 应统计聚合错误条目。")
	assert_true(_manifest_array_contains_id(snapshot_manifests, "author.invalid"), "snapshot 仍应保留可读取的 invalid manifest，供上层报告和修复工具使用。")
	var issue: Dictionary = GF_VARIANT_ACCESS.as_dictionary(manifest_validation_errors[0])
	assert_eq(GF_VARIANT_ACCESS.get_option_string(issue, "stage"), "validation", "validation 错误应带稳定 stage。")
	assert_eq(GF_VARIANT_ACCESS.get_option_string(issue, "extension_id"), "author.invalid", "validation 错误应带扩展 ID。")
	assert_eq(GF_VARIANT_ACCESS.get_option_string(issue, "source_path"), manifest_path, "validation 错误应带来源路径。")
	assert_true(
		GF_VARIANT_ACCESS.get_option_string_array(issue, "errors").has("display_name is required"),
		"validation 错误应保留 manifest 校验消息。"
	)


func test_manifest_graph_report_marks_readable_manifest_validation_errors() -> void:
	var root_path: String = "res://tests/gf_core/tmp_graph_invalid_manifest"
	var extension_dir: String = root_path.path_join("invalid")
	var manifest_path: String = extension_dir.path_join(GFExtensionManifest.FILE_NAME)
	_cleanup_extension_root_fixture(root_path, extension_dir, manifest_path)
	var _make_dir_result: Variant = DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(extension_dir))
	_write_text_file(manifest_path, JSON.stringify({
		"id": "author.invalid_graph",
		"version": "1.0.0",
		"kind": "extension",
	}))
	var restore: Dictionary = _set_project_setting(
		GFExtensionSettings.EXTERNAL_EXTENSION_ROOTS_SETTING,
		[root_path]
	)
	GFExtensionSettings.clear_manifest_cache()

	var report: Dictionary = GFExtensionSettings.get_manifest_graph_report()
	var manifest_load_errors: Array = GF_VARIANT_ACCESS.get_option_array(report, "manifest_load_errors")
	var invalid_manifests: Array = GF_VARIANT_ACCESS.get_option_array(report, "invalid_manifests")

	GFExtensionSettings.clear_manifest_cache()
	_restore_project_setting(GFExtensionSettings.EXTERNAL_EXTENSION_ROOTS_SETTING, restore)
	_cleanup_extension_root_fixture(root_path, extension_dir, manifest_path)

	assert_false(GF_VARIANT_ACCESS.get_option_bool(report, "ok"), "可读取但无效的 manifest 应让 graph report 失败。")
	assert_eq(manifest_load_errors.size(), 0, "可解析的 manifest 不应进入 graph load errors。")
	assert_eq(invalid_manifests.size(), 1, "可解析但无效的 manifest 应进入 graph invalid_manifests。")
	var issue: Dictionary = GF_VARIANT_ACCESS.as_dictionary(invalid_manifests[0])
	assert_eq(GF_VARIANT_ACCESS.get_option_string(issue, "stage"), "validation", "graph invalid manifest 应标记 validation stage。")
	assert_eq(GF_VARIANT_ACCESS.get_option_string(issue, "extension_id"), "author.invalid_graph", "graph invalid manifest 应带扩展 ID。")
	assert_true(
		GF_VARIANT_ACCESS.get_option_string_array(issue, "errors").has("display_name is required"),
		"graph invalid manifest 应保留 manifest 校验消息。"
	)


func test_manifest_graph_report_includes_manifest_load_errors() -> void:
	var root_path: String = "res://tests/gf_core/tmp_bad_external_extensions"
	var extension_dir: String = root_path.path_join("broken")
	var manifest_path: String = extension_dir.path_join(GFExtensionManifest.FILE_NAME)
	_cleanup_extension_root_fixture(root_path, extension_dir, manifest_path)
	var _make_dir_result: Variant = DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(extension_dir))
	_write_text_file(manifest_path, "{")
	var restore: Dictionary = _set_project_setting(
		GFExtensionSettings.EXTERNAL_EXTENSION_ROOTS_SETTING,
		[root_path]
	)
	GFExtensionSettings.clear_manifest_cache()

	var report: Dictionary = GFExtensionSettings.get_manifest_graph_report()
	var manifest_load_errors: Array = GF_VARIANT_ACCESS.get_option_array(report, "manifest_load_errors")
	var invalid_manifests: Array = GF_VARIANT_ACCESS.get_option_array(report, "invalid_manifests")

	GFExtensionSettings.clear_manifest_cache()
	_restore_project_setting(GFExtensionSettings.EXTERNAL_EXTENSION_ROOTS_SETTING, restore)
	_cleanup_extension_root_fixture(root_path, extension_dir, manifest_path)

	assert_false(GF_VARIANT_ACCESS.get_option_bool(report, "ok"), "无法解析的 manifest 应让图诊断失败。")
	assert_eq(manifest_load_errors.size(), 1, "读取失败的 manifest 应进入 manifest_load_errors。")
	assert_eq(invalid_manifests.size(), 1, "读取失败的 manifest 也应折叠进 invalid_manifests。")
	var issue: Dictionary = GF_VARIANT_ACCESS.as_dictionary(invalid_manifests[0])
	assert_eq(GF_VARIANT_ACCESS.get_option_string(issue, "stage"), "load", "读取失败的 manifest 应标记 load stage。")


func test_enabled_manifest_paths_are_blocked_by_cached_manifest_load_errors() -> void:
	var root_path: String = "res://tests/gf_core/tmp_bad_enabled_external_extensions"
	var broken_extension_dir: String = root_path.path_join("broken")
	var valid_extension_dir: String = root_path.path_join("valid")
	var broken_manifest_path: String = broken_extension_dir.path_join(GFExtensionManifest.FILE_NAME)
	var valid_manifest_path: String = valid_extension_dir.path_join(GFExtensionManifest.FILE_NAME)
	_cleanup_extension_root_fixture(root_path, broken_extension_dir, broken_manifest_path)
	_cleanup_extension_root_fixture(root_path, valid_extension_dir, valid_manifest_path)
	var _make_broken_dir_result: Variant = DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(broken_extension_dir))
	var _make_valid_dir_result: Variant = DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(valid_extension_dir))
	_write_text_file(broken_manifest_path, "{")
	_write_text_file(valid_manifest_path, JSON.stringify({
		"id": "author.valid",
		"display_name": "Valid",
		"version": "1.0.0",
		"kind": "extension",
		"installer_paths": [valid_extension_dir.path_join("valid_installer.gd")],
	}))
	var root_restore: Dictionary = _set_project_setting(
		GFExtensionSettings.EXTERNAL_EXTENSION_ROOTS_SETTING,
		[root_path]
	)
	var enabled_restore: Dictionary = _set_project_setting(
		GFExtensionSettings.ENABLED_EXTENSIONS_SETTING,
		["author.valid"]
	)
	var auto_install_restore: Dictionary = _set_project_setting(
		GFExtensionSettings.AUTO_INSTALL_ENABLED_INSTALLERS_SETTING,
		true
	)
	GFExtensionSettings.clear_manifest_cache()

	var installer_paths: Array[String] = GFExtensionSettings.get_enabled_installer_paths()
	var selection_report: Dictionary = GFExtensionSettings.get_extension_selection_report()

	GFExtensionSettings.clear_manifest_cache()
	_restore_project_setting(GFExtensionSettings.AUTO_INSTALL_ENABLED_INSTALLERS_SETTING, auto_install_restore)
	_restore_project_setting(GFExtensionSettings.ENABLED_EXTENSIONS_SETTING, enabled_restore)
	_restore_project_setting(GFExtensionSettings.EXTERNAL_EXTENSION_ROOTS_SETTING, root_restore)
	_cleanup_extension_root_fixture(root_path, valid_extension_dir, valid_manifest_path)
	_cleanup_extension_root_fixture(root_path, broken_extension_dir, broken_manifest_path)

	assert_eq(installer_paths, [], "manifest 读取失败时不应继续暴露启用扩展 installer 路径。")
	assert_false(GF_VARIANT_ACCESS.get_option_bool(selection_report, "graph_ok", true), "启用状态诊断应反映 manifest 读取失败。")
	assert_push_warning("[GFExtensionSettings] get_enabled_manifests blocked: invalid manifest %s" % broken_manifest_path)


func test_extension_settings_loads_project_extension_presets_from_project_settings() -> void:
	var directory: String = "res://tests/gf_core/tmp_extension_presets"
	var preset_path: String = directory.path_join("rpg.json")
	var invalid_preset_path: String = directory.path_join("download.json")
	_remove_path_if_exists(preset_path)
	_remove_path_if_exists(invalid_preset_path)
	_remove_path_if_exists(directory)
	var _make_dir_result: Variant = DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	_write_text_file(preset_path, JSON.stringify({
		"id": "project.rpg",
		"display_name": "RPG Tools",
		"description": "Project preset.",
		"extension_ids": ["gf.save", "gf.dialogue"],
	}))
	_write_text_file(invalid_preset_path, JSON.stringify({
		"id": "project.download",
		"display_name": "Download Preset",
		"extension_ids": ["gf.save"],
		"download_url": "https://example.invalid/package.zip",
	}))
	var restore: Dictionary = _set_project_setting(
		GFExtensionSettings.EXTENSION_PRESET_PATHS_SETTING,
		[preset_path, invalid_preset_path, preset_path.replace("/", "\\"), "user://ignored.json", "res://ignored.txt"]
	)

	var paths: Array[String] = GFExtensionSettings.get_extension_preset_paths()
	var presets: Array = GFExtensionSettings.get_extension_presets()
	var preset_ids: Array[StringName] = []
	for preset_value: Variant in presets:
		if not (preset_value is Object):
			continue
		var preset: Object = preset_value
		preset_ids.append(GF_VARIANT_ACCESS.to_string_name(preset.get("id")))

	_restore_project_setting(GFExtensionSettings.EXTENSION_PRESET_PATHS_SETTING, restore)
	_remove_path_if_exists(preset_path)
	_remove_path_if_exists(invalid_preset_path)
	_remove_path_if_exists(directory)

	assert_eq(paths, [preset_path, invalid_preset_path], "preset 路径应去重并只保留 res:// JSON 文件。")
	assert_true(preset_ids.has(&"gf.default"), "GF 应提供动态默认选择 preset。")
	assert_true(preset_ids.has(&"gf.none"), "GF 应提供全部关闭 preset。")
	assert_true(preset_ids.has(&"gf.all"), "GF 应提供全部扩展 preset。")
	assert_true(preset_ids.has(&"project.rpg"), "ProjectSettings 声明的 preset JSON 应被加载。")
	assert_false(
		preset_ids.has(&"project.download"),
		"包含下载包字段的 preset JSON 应被视为无效并跳过。"
	)


func test_extension_preset_discovery_refreshes_when_preset_file_changes() -> void:
	var directory: String = "res://tests/gf_core/tmp_extension_preset_cache"
	var preset_path: String = directory.path_join("cache.json")
	_remove_path_if_exists(preset_path)
	_remove_path_if_exists(directory)
	var _make_dir_result: Variant = DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	_write_text_file(preset_path, JSON.stringify({
		"id": "project.cache",
		"display_name": "Cache A",
		"extension_ids": [],
	}))
	var restore: Dictionary = _set_project_setting(
		GFExtensionSettings.EXTENSION_PRESET_PATHS_SETTING,
		[preset_path]
	)
	GFExtensionSettings.clear_manifest_cache()

	var first_preset: GFExtensionPreset = GFExtensionSettings.get_extension_preset_by_id(&"project.cache")
	_write_text_file(preset_path, JSON.stringify({
		"id": "project.cache",
		"display_name": "Cache B",
		"extension_ids": [],
	}))
	var second_preset: GFExtensionPreset = GFExtensionSettings.get_extension_preset_by_id(&"project.cache")

	GFExtensionSettings.clear_manifest_cache()
	_restore_project_setting(GFExtensionSettings.EXTENSION_PRESET_PATHS_SETTING, restore)
	_remove_path_if_exists(preset_path)
	_remove_path_if_exists(directory)

	assert_not_null(first_preset, "第一次读取应能加载项目 preset。")
	assert_not_null(second_preset, "preset 文件变化后仍应能加载项目 preset。")
	assert_eq(first_preset.display_name, "Cache A", "第一次读取应返回旧文件内容。")
	assert_eq(second_preset.display_name, "Cache B", "同一路径 preset 文件变化后应刷新 discovery snapshot。")


func test_extension_preset_discovery_shares_signature_and_parse_byte_budget() -> void:
	var root_path: String = "res://tests/gf_core/tmp_preset_json_budget"
	var preset_path: String = root_path.path_join("oversized.json")
	_remove_path_if_exists(preset_path)
	_remove_path_if_exists(root_path)
	var _make_dir_result: Error = DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path(root_path)
	)
	_write_text_file(preset_path, JSON.stringify({
		"id": "project.oversized",
		"display_name": "Oversized Preset",
		"description": "The signature and parser must share one bounded session.",
		"extension_ids": [],
		"tags": ["test"],
	}))
	GF_EXTENSION_PRESET_DISCOVERY_SCRIPT.clear_cache()

	var snapshot: Dictionary = GF_EXTENSION_PRESET_DISCOVERY_SCRIPT.get_snapshot(
		[],
		[preset_path],
		{
			"force_refresh": true,
			"max_json_file_bytes": 64,
		}
	)
	var report: Dictionary = GF_VARIANT_ACCESS.get_option_dictionary(snapshot, "report")
	var invalid_presets: Array = GF_VARIANT_ACCESS.get_option_array(report, "invalid_presets")
	GF_EXTENSION_PRESET_DISCOVERY_SCRIPT.clear_cache()
	_remove_path_if_exists(preset_path)
	_remove_path_if_exists(root_path)

	assert_false(GF_VARIANT_ACCESS.get_option_bool(snapshot, "ok"), "超限 preset 不得进入有效快照。")
	assert_eq(invalid_presets.size(), 1, "超限 preset 应形成单个 invalid 记录。")
	if invalid_presets.size() == 1:
		var errors: Array[String] = GF_VARIANT_ACCESS.get_option_string_array(
			GF_VARIANT_ACCESS.as_dictionary(invalid_presets[0]),
			"errors"
		)
		assert_true(
			errors.any(func(error: String) -> bool: return error.contains("max_json_file_bytes")),
			"preset invalid 记录应暴露 JSON limit。"
		)


func test_extension_preset_validation_rejects_non_canonical_extension_ids() -> void:
	var preset: GF_EXTENSION_PRESET_BASE = GF_EXTENSION_PRESET_BASE.from_dictionary({
		"id": "project.tools",
		"display_name": "Tools",
		"extension_ids": ["gf.Valid"],
	})
	var errors: Array[String] = preset.get_validation_errors()

	assert_true(errors.has("extension_ids must use lowercase dotted identifier segments: gf.Valid"), "preset extension_ids 应复用 manifest 扩展 ID 校验。")


func test_extension_settings_reports_project_extension_preset_diagnostics() -> void:
	var directory: String = "res://tests/gf_core/tmp_extension_preset_report"
	var valid_path: String = directory.path_join("valid.json")
	var duplicate_path: String = directory.path_join("duplicate.json")
	var invalid_path: String = directory.path_join("invalid.json")
	_remove_path_if_exists(valid_path)
	_remove_path_if_exists(duplicate_path)
	_remove_path_if_exists(invalid_path)
	_remove_path_if_exists(directory)
	var _make_dir_result: Variant = DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	_write_text_file(valid_path, JSON.stringify({
		"id": "project.tools",
		"display_name": "Tools",
		"extension_ids": ["gf.save"],
	}))
	_write_text_file(duplicate_path, JSON.stringify({
		"id": "project.tools",
		"display_name": "Tools Duplicate",
		"extension_ids": ["gf.save"],
	}))
	_write_text_file(invalid_path, JSON.stringify({
		"id": "project.Invalid",
		"display_name": "Invalid",
		"extension_ids": ["gf.save"],
	}))
	var restore: Dictionary = _set_project_setting(
		GFExtensionSettings.EXTENSION_PRESET_PATHS_SETTING,
		[valid_path, duplicate_path, invalid_path, valid_path.replace("/", "\\"), "user://ignored.json"]
	)

	var report: Dictionary = GFExtensionSettings.get_extension_preset_report()
	var invalid_presets: Array = GF_VARIANT_ACCESS.get_option_array(report, "invalid_presets")
	var skipped_presets: Array = GF_VARIANT_ACCESS.get_option_array(report, "skipped_presets")
	var duplicate_ids: PackedStringArray = GF_VARIANT_ACCESS.get_option_packed_string_array(report, "duplicate_ids")

	_restore_project_setting(GFExtensionSettings.EXTENSION_PRESET_PATHS_SETTING, restore)
	_remove_path_if_exists(valid_path)
	_remove_path_if_exists(duplicate_path)
	_remove_path_if_exists(invalid_path)
	_remove_path_if_exists(directory)

	assert_false(GF_VARIANT_ACCESS.get_option_bool(report, "ok"), "存在无效或跳过 preset 时诊断应失败。")
	assert_gt(GF_VARIANT_ACCESS.get_option_int(report, "preset_count"), 0, "报告应包含有效 preset 数量。")
	assert_eq(invalid_presets.size(), 2, "无效 JSON 内容和非法路径都应进入 invalid_presets。")
	assert_eq(skipped_presets.size(), 2, "重复 id 和重复路径都应进入 skipped_presets。")
	assert_true(duplicate_ids.has("project.tools"), "重复 preset id 应进入 duplicate_ids。")


func test_extension_settings_apply_extension_preset_resolves_dependencies() -> void:
	var directory: String = "res://tests/gf_core/tmp_extension_presets"
	var preset_path: String = directory.path_join("feature.json")
	_remove_path_if_exists(preset_path)
	_remove_path_if_exists(directory)
	var _make_dir_result: Variant = DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	_write_text_file(preset_path, JSON.stringify({
		"id": "project.feature",
		"display_name": "Feature",
		"extension_ids": ["author.feature"],
	}))
	var base_manifest: GFExtensionManifest = GFExtensionManifest.from_dictionary({
		"id": "author.base",
		"display_name": "Base",
		"version": "1.0.0",
		"kind": "extension",
	}, "res://addons/author_base", "")
	var feature_manifest: GFExtensionManifest = GFExtensionManifest.from_dictionary({
		"id": "author.feature",
		"display_name": "Feature",
		"version": "1.0.0",
		"kind": "extension",
		"dependencies": ["author.base"],
	}, "res://addons/author_feature", "")
	var enabled_restore: Dictionary = _set_project_setting(
		GFExtensionSettings.ENABLED_EXTENSIONS_SETTING,
		[]
	)
	var preset_restore: Dictionary = _set_project_setting(
		GFExtensionSettings.EXTENSION_PRESET_PATHS_SETTING,
		[preset_path]
	)
	GFExtensionSettings.set_cached_manifests([feature_manifest, base_manifest])

	var applied: bool = GFExtensionSettings.apply_extension_preset(&"project.feature", true)
	var stored_ids: Array[String] = GFExtensionSettings.get_enabled_extension_ids()

	GFExtensionSettings.clear_manifest_cache()
	_restore_project_setting(GFExtensionSettings.EXTENSION_PRESET_PATHS_SETTING, preset_restore)
	_restore_project_setting(GFExtensionSettings.ENABLED_EXTENSIONS_SETTING, enabled_restore)
	_remove_path_if_exists(preset_path)
	_remove_path_if_exists(directory)

	assert_true(applied, "存在的 preset 应能写入启用设置。")
	assert_eq(stored_ids, ["author.base", "author.feature"], "应用 preset 时应按 manifest 硬依赖补齐启用 ID。")


func test_extension_settings_reports_and_rejects_preset_with_unknown_extension_ids() -> void:
	var directory: String = "res://tests/gf_core/tmp_extension_presets_unknown"
	var preset_path: String = directory.path_join("missing.json")
	_remove_path_if_exists(preset_path)
	_remove_path_if_exists(directory)
	var _make_dir_result: Variant = DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	_write_text_file(preset_path, JSON.stringify({
		"id": "project.missing",
		"display_name": "Missing",
		"description": "References an extension that is not installed.",
		"extension_ids": ["author.missing"],
	}))

	var preset_restore: Dictionary = _set_project_setting(
		GFExtensionSettings.EXTENSION_PRESET_PATHS_SETTING,
		[preset_path]
	)
	var enabled_restore: Dictionary = _set_project_setting(
		GFExtensionSettings.ENABLED_EXTENSIONS_SETTING,
		["gf.save"]
	)
	var report: Dictionary = GFExtensionSettings.get_extension_preset_report()
	var invalid_presets: Array = GF_VARIANT_ACCESS.get_option_array(report, "invalid_presets")
	var applied: bool = GFExtensionSettings.apply_extension_preset(&"project.missing", true)
	var stored_ids: Array[String] = GFExtensionSettings.get_enabled_extension_ids()

	_restore_project_setting(GFExtensionSettings.ENABLED_EXTENSIONS_SETTING, enabled_restore)
	_restore_project_setting(GFExtensionSettings.EXTENSION_PRESET_PATHS_SETTING, preset_restore)
	_remove_path_if_exists(preset_path)
	_remove_path_if_exists(directory)

	assert_false(GF_VARIANT_ACCESS.get_option_bool(report, "ok"), "未知扩展 ID 的 preset 应进入诊断失败。")
	assert_true(_preset_issue_contains(invalid_presets, "project.missing", "unknown extension id"), "报告应说明 preset 引用了不可发现扩展。")
	assert_false(applied, "包含未知扩展 ID 的 preset 不应被当作成功应用。")
	assert_eq(stored_ids, ["gf.save"], "失败应用不应改写当前启用扩展设置。")


func test_extension_settings_adds_and_removes_project_preset_paths() -> void:
	var directory: String = "res://tests/gf_core/tmp_extension_presets_path_api"
	var first_path: String = directory.path_join("first.json")
	var second_path: String = directory.path_join("second.json")
	var invalid_preset_path: String = directory.path_join("invalid.json")
	_remove_path_if_exists(first_path)
	_remove_path_if_exists(second_path)
	_remove_path_if_exists(invalid_preset_path)
	_remove_path_if_exists(directory)
	var _make_dir_result: Variant = DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	_write_text_file(first_path, JSON.stringify({
		"id": "project.first",
		"display_name": "First",
		"extension_ids": [],
	}))
	_write_text_file(second_path, JSON.stringify({
		"id": "project.second",
		"display_name": "Second",
		"extension_ids": [],
	}))
	_write_text_file(invalid_preset_path, JSON.stringify({
		"display_name": "Invalid",
		"extension_ids": [],
	}))
	var restore: Dictionary = _set_project_setting(
		GFExtensionSettings.EXTENSION_PRESET_PATHS_SETTING,
		[first_path.replace("/", "\\")]
	)

	var duplicate_added: bool = GFExtensionSettings.add_extension_preset_path(first_path)
	var invalid_added: bool = GFExtensionSettings.add_extension_preset_path("user://ignored.json")
	var invalid_preset_added: bool = GFExtensionSettings.add_extension_preset_path(invalid_preset_path)
	var second_added: bool = GFExtensionSettings.add_extension_preset_path(second_path)
	var paths_after_add: Array[String] = GFExtensionSettings.get_extension_preset_paths()
	var removed: bool = GFExtensionSettings.remove_extension_preset_path(second_path.replace("/", "\\"))
	var missing_removed: bool = GFExtensionSettings.remove_extension_preset_path(directory.path_join("missing.txt"))
	var paths_after_remove: Array[String] = GFExtensionSettings.get_extension_preset_paths()

	_restore_project_setting(GFExtensionSettings.EXTENSION_PRESET_PATHS_SETTING, restore)
	_remove_path_if_exists(first_path)
	_remove_path_if_exists(second_path)
	_remove_path_if_exists(invalid_preset_path)
	_remove_path_if_exists(directory)

	assert_false(duplicate_added, "重复 preset 路径不应再次写入 ProjectSettings。")
	assert_false(invalid_added, "非 res:// JSON 路径不应进入 preset 路径列表。")
	assert_false(invalid_preset_added, "无法解析为有效 GFExtensionPreset 的 JSON 不应通过 add API 写入。")
	assert_true(second_added, "新的 res:// JSON preset 路径应能写入 ProjectSettings。")
	assert_eq(paths_after_add, [first_path, second_path], "新增 preset 路径应保留既有顺序并追加到末尾。")
	assert_true(removed, "存在的 preset 路径应能移除。")
	assert_false(missing_removed, "无效或不存在的 preset 路径移除应返回 false。")
	assert_eq(paths_after_remove, [first_path], "移除后应只保留未移除的 preset 路径。")


func test_extension_manifest_versions_follow_release_policy() -> void:
	var framework_version: String = _read_framework_version()
	var issues: PackedStringArray = PackedStringArray()
	for manifest: GFExtensionManifest in GFExtensionCatalog.load_extension_manifests():
		var manifest_data: Dictionary = _read_json_dictionary(manifest.source_path)
		if manifest.version != framework_version:
			var _append_result_175: Variant = issues.append("%s version %s != framework %s" % [
				manifest.id,
				manifest.version,
				framework_version,
			])
		if not manifest_data.has("extension_version"):
			var _append_result_181: Variant = issues.append("%s does not declare extension_version" % manifest.id)
		if not _is_semver(manifest.extension_version):
			var _append_result_183: Variant = issues.append("%s extension_version is not semver: %s" % [
				manifest.id,
				manifest.extension_version,
			])

	assert_eq(
		Array(issues),
		[],
		"GF 内置扩展 manifest.version 必须跟随 GF 源码版本，extension_version 必须记录扩展自身稳定 SemVer。"
	)


func test_extension_settings_resolves_manifest_dependencies() -> void:
	var base_manifest: GFExtensionManifest = GFExtensionManifest.from_dictionary({
		"id": "author.base",
		"display_name": "Base",
		"version": "1.0.0",
		"kind": "extension",
	}, "res://addons/author_base", "")
	var feature_manifest: GFExtensionManifest = GFExtensionManifest.from_dictionary({
		"id": "author.feature",
		"display_name": "Feature",
		"version": "1.0.0",
		"kind": "extension",
		"dependencies": ["gf.kernel", "author.base"],
	}, "res://addons/author_feature", "")

	var manifests: Array[GFExtensionManifest] = [base_manifest, feature_manifest]
	var resolved: Array[String] = GFExtensionSettings.resolve_extension_dependencies(["author.feature"], manifests)

	assert_eq(resolved, ["author.base", "author.feature"], "启用扩展应按依赖优先顺序自动补齐内部依赖。")


func test_extension_settings_resolves_dependencies_before_dependents_when_manifest_order_is_reversed() -> void:
	var base_manifest: GFExtensionManifest = GFExtensionManifest.from_dictionary({
		"id": "author.base",
		"display_name": "Base",
		"version": "1.0.0",
		"kind": "extension",
	}, "res://addons/author_base", "")
	var feature_manifest: GFExtensionManifest = GFExtensionManifest.from_dictionary({
		"id": "author.feature",
		"display_name": "Feature",
		"version": "1.0.0",
		"kind": "extension",
		"dependencies": ["author.base"],
	}, "res://addons/author_feature", "")

	var manifests: Array[GFExtensionManifest] = [feature_manifest, base_manifest]
	var resolved: Array[String] = GFExtensionSettings.resolve_extension_dependencies(["author.feature"], manifests)

	assert_eq(resolved, ["author.base", "author.feature"], "依赖 manifest 扫描顺序靠后时也应先于依赖方返回。")


func test_enabled_manifest_and_extension_paths_follow_dependency_order() -> void:
	var base_manifest: GFExtensionManifest = GFExtensionManifest.from_dictionary({
		"id": "author.base",
		"display_name": "Base",
		"version": "1.0.0",
		"kind": "extension",
		"installer_paths": ["res://addons/author_base/base_installer.gd"],
		"import_plugin_paths": ["res://addons/author_base/base_import_plugin.gd"],
	}, "res://addons/author_base", "")
	var feature_manifest: GFExtensionManifest = GFExtensionManifest.from_dictionary({
		"id": "author.feature",
		"display_name": "Feature",
		"version": "1.0.0",
		"kind": "extension",
		"dependencies": ["author.base"],
		"installer_paths": ["res://addons/author_feature/feature_installer.gd"],
		"import_plugin_paths": ["res://addons/author_feature/feature_import_plugin.gd"],
	}, "res://addons/author_feature", "")
	var enabled_restore: Dictionary = _set_project_setting(
		GFExtensionSettings.ENABLED_EXTENSIONS_SETTING,
		["author.feature"]
	)
	var auto_install_restore: Dictionary = _set_project_setting(
		GFExtensionSettings.AUTO_INSTALL_ENABLED_INSTALLERS_SETTING,
		true
	)
	var manifests: Array[GFExtensionManifest] = [feature_manifest, base_manifest]
	GFExtensionSettings.set_cached_manifests(manifests)

	var enabled_manifests: Array[GFExtensionManifest] = GFExtensionSettings.get_enabled_manifests()
	var enabled_ids: Array[String] = []
	for manifest: GFExtensionManifest in enabled_manifests:
		enabled_ids.append(manifest.id)
	var installer_paths: Array[String] = GFExtensionSettings.get_enabled_installer_paths()
	var import_paths: Array[String] = GFExtensionSettings.get_enabled_import_plugin_paths()

	GFExtensionSettings.clear_manifest_cache()
	_restore_project_setting(GFExtensionSettings.AUTO_INSTALL_ENABLED_INSTALLERS_SETTING, auto_install_restore)
	_restore_project_setting(GFExtensionSettings.ENABLED_EXTENSIONS_SETTING, enabled_restore)

	assert_eq(enabled_ids, ["author.base", "author.feature"], "启用 manifest 列表应保持依赖优先顺序。")
	assert_eq(
		installer_paths,
		[
			"res://addons/author_base/base_installer.gd",
			"res://addons/author_feature/feature_installer.gd",
		],
		"启用扩展 installer 应先执行依赖扩展，再执行依赖方。"
	)
	assert_eq(
		import_paths,
		[
			"res://addons/author_base/base_import_plugin.gd",
			"res://addons/author_feature/feature_import_plugin.gd",
		],
		"启用扩展导入插件应保持依赖优先顺序。"
	)


func test_extension_settings_manifest_cache_returns_copies() -> void:
	var feature_manifest: GFExtensionManifest = GFExtensionManifest.from_dictionary({
		"id": "author.feature",
		"display_name": "Feature",
		"version": "1.0.0",
		"kind": "extension",
		"installer_paths": ["res://addons/author_feature/feature_installer.gd"],
	}, "res://addons/author_feature", "")
	GFExtensionSettings.set_cached_manifests([feature_manifest])
	feature_manifest.id = "author.changed"

	var first_read: Array[GFExtensionManifest] = GFExtensionSettings.get_all_manifests()
	first_read[0].id = "author.mutated"
	first_read[0].installer_paths.append("res://addons/author_feature/mutated_installer.gd")
	var second_read: Array[GFExtensionManifest] = GFExtensionSettings.get_all_manifests()

	GFExtensionSettings.clear_manifest_cache()

	assert_eq(second_read[0].id, "author.feature", "写入缓存后的原始 manifest 改动不应污染缓存。")
	assert_false(second_read[0].installer_paths.has("res://addons/author_feature/mutated_installer.gd"), "读取到的 manifest 副本改动不应污染缓存。")


func test_enabled_manifest_paths_are_blocked_when_manifest_graph_is_invalid() -> void:
	var feature_manifest: GFExtensionManifest = GFExtensionManifest.from_dictionary({
		"id": "author.feature",
		"display_name": "Feature",
		"version": "1.0.0",
		"kind": "extension",
		"dependencies": ["author.missing"],
		"installer_paths": ["res://addons/author_feature/feature_installer.gd"],
	}, "res://addons/author_feature", "")
	var enabled_restore: Dictionary = _set_project_setting(
		GFExtensionSettings.ENABLED_EXTENSIONS_SETTING,
		["author.feature"]
	)
	var auto_install_restore: Dictionary = _set_project_setting(
		GFExtensionSettings.AUTO_INSTALL_ENABLED_INSTALLERS_SETTING,
		true
	)
	GFExtensionSettings.set_cached_manifests([feature_manifest])

	var installer_paths: Array[String] = GFExtensionSettings.get_enabled_installer_paths()

	GFExtensionSettings.clear_manifest_cache()
	_restore_project_setting(GFExtensionSettings.AUTO_INSTALL_ENABLED_INSTALLERS_SETTING, auto_install_restore)
	_restore_project_setting(GFExtensionSettings.ENABLED_EXTENSIONS_SETTING, enabled_restore)

	assert_eq(installer_paths, [], "扩展依赖图无效时不应继续收集 installer 路径。")
	assert_push_warning("[GFExtensionSettings] get_enabled_manifests blocked: missing dependency author.feature -> author.missing")


func test_disabled_manifests_are_blocked_when_manifest_graph_is_invalid() -> void:
	var feature_manifest: GFExtensionManifest = GFExtensionManifest.from_dictionary({
		"id": "author.feature",
		"display_name": "Feature",
		"version": "1.0.0",
		"kind": "extension",
		"dependencies": ["author.missing"],
	}, "res://addons/author_feature", "")
	GFExtensionSettings.set_cached_manifests([feature_manifest])

	var disabled_manifests: Array[GFExtensionManifest] = GFExtensionSettings.get_disabled_manifests()

	GFExtensionSettings.clear_manifest_cache()

	assert_true(disabled_manifests.is_empty(), "扩展依赖图无效时不应继续收集禁用 manifest。")
	assert_push_warning("[GFExtensionSettings] get_disabled_manifests blocked: missing dependency author.feature -> author.missing")


func test_extension_settings_resolves_only_known_manifest_ids() -> void:
	var feature_manifest: GFExtensionManifest = GFExtensionManifest.from_dictionary({
		"id": "author.feature",
		"display_name": "Feature",
		"version": "1.0.0",
		"kind": "extension",
	}, "res://addons/author_feature", "")

	var manifests: Array[GFExtensionManifest] = [feature_manifest]
	var resolved: Array[String] = GFExtensionSettings.resolve_extension_dependencies(
		["author.feature", "author.missing", "gf.kernel"],
		manifests
	)

	assert_eq(resolved, ["author.feature"], "启用结果只能包含当前发现到的 manifest ID。")


func test_extension_settings_resolves_dependency_cycles_without_recursing_forever() -> void:
	var first_manifest: GFExtensionManifest = GFExtensionManifest.from_dictionary({
		"id": "author.first",
		"display_name": "First",
		"version": "1.0.0",
		"kind": "extension",
		"dependencies": ["author.second"],
	}, "res://addons/author_first", "")
	var second_manifest: GFExtensionManifest = GFExtensionManifest.from_dictionary({
		"id": "author.second",
		"display_name": "Second",
		"version": "1.0.0",
		"kind": "extension",
		"dependencies": ["author.first"],
	}, "res://addons/author_second", "")

	var manifests: Array[GFExtensionManifest] = [first_manifest, second_manifest]
	var resolved: Array[String] = GFExtensionSettings.resolve_extension_dependencies(["author.first"], manifests)
	var report: Dictionary = GFExtensionSettings.get_manifest_graph_report(manifests)
	var cycles: Array = GF_VARIANT_ACCESS.get_option_array(report, "dependency_cycles")

	assert_eq(resolved, ["author.first", "author.second"], "循环依赖不应导致递归卡死，仍应返回已解析扩展。")
	assert_false(GF_VARIANT_ACCESS.get_option_bool(report, "ok"), "循环依赖应让图诊断失败。")
	assert_eq(cycles.size(), 1, "应报告一条依赖循环。")
	assert_eq(GF_VARIANT_ACCESS.to_string_array(cycles[0]), ["author.first", "author.second", "author.first"], "循环路径应保留闭环顺序。")
	assert_push_warning("[GFExtensionSelectionDiscovery] 检测到扩展依赖循环：author.first -> author.second -> author.first")


func test_manifest_graph_report_includes_missing_dependencies_and_duplicates() -> void:
	var first_manifest: GFExtensionManifest = GFExtensionManifest.from_dictionary({
		"id": "author.feature",
		"display_name": "Feature",
		"version": "1.0.0",
		"kind": "extension",
		"dependencies": ["gf.kernel", "author.missing"],
	}, "res://addons/author_feature", "")
	var duplicate_manifest: GFExtensionManifest = GFExtensionManifest.from_dictionary({
		"id": "author.feature",
		"display_name": "Feature Duplicate",
		"version": "1.0.0",
		"kind": "extension",
	}, "res://addons/author_feature_duplicate", "")

	var report: Dictionary = GFExtensionSettings.get_manifest_graph_report([first_manifest, duplicate_manifest])
	var missing_dependencies: Array = GF_VARIANT_ACCESS.get_option_array(report, "missing_dependencies")
	var duplicate_ids: PackedStringArray = GF_VARIANT_ACCESS.get_option_packed_string_array(report, "duplicate_ids")
	var missing_dependency: Dictionary = GF_VARIANT_ACCESS.as_dictionary(missing_dependencies[0])

	assert_false(GF_VARIANT_ACCESS.get_option_bool(report, "ok"), "缺失依赖或重复 ID 应让图诊断失败。")
	assert_true(duplicate_ids.has("author.feature"), "重复扩展 ID 应写入 duplicate_ids。")
	assert_eq(missing_dependencies.size(), 1, "内置依赖不应被当作缺失扩展，真实缺失依赖应被报告。")
	assert_eq(GF_VARIANT_ACCESS.get_option_string(missing_dependency, "dependency_id"), "author.missing", "缺失依赖 ID 应可用于编辑器提示。")


func test_default_enabled_extension_ids_match_manifest_defaults() -> void:
	var ids: Array[String] = GFExtensionSettings.get_default_enabled_extension_ids()
	var expected_ids: Array[String] = []
	for manifest: GFExtensionManifest in GFExtensionCatalog.load_extension_manifests():
		if manifest.enabled_by_default:
			expected_ids.append(manifest.id)
	expected_ids.sort()

	assert_eq(ids, expected_ids, "默认启用扩展应与 GF manifest 的 enabled_by_default 保持一致。")
	assert_true(ids.is_empty(), "GF 内置可选扩展默认应保持关闭，由项目显式选择。")


func test_extension_installer_paths_exist_when_declared() -> void:
	for manifest: GFExtensionManifest in GFExtensionCatalog.load_extension_manifests():
		for installer_path: String in manifest.installer_paths:
			assert_true(
				ResourceLoader.exists(installer_path),
				"%s installer 应指向存在的脚本：%s" % [manifest.id, installer_path]
			)


func test_manifest_json_report_rejects_missing_declared_resource_paths() -> void:
	var root_path: String = "res://tests/gf_core/tmp_missing_declared_resource"
	var manifest_path: String = root_path.path_join(GFExtensionManifest.FILE_NAME)
	_remove_path_if_exists(manifest_path)
	_remove_path_if_exists(root_path)
	var _make_dir_result: Variant = DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(root_path))
	_write_text_file(manifest_path, JSON.stringify({
		"id": "author.missing_resource",
		"display_name": "Missing Resource",
		"version": "1.0.0",
		"kind": "extension",
		"installer_paths": [root_path.path_join("missing_installer.gd")],
	}))

	var report: Dictionary = GFExtensionManifest.from_json_file_report(manifest_path)
	var manifest: GFExtensionManifest = GFExtensionManifest.from_json_file(manifest_path)
	var errors: Array[String] = GF_VARIANT_ACCESS.get_option_string_array(report, "errors")

	_remove_path_if_exists(manifest_path)
	_remove_path_if_exists(root_path)

	assert_false(GF_VARIANT_ACCESS.get_option_bool(report, "ok"), "外部 manifest 声明不存在脚本时应失败。")
	assert_true(_string_array_contains(errors, "must point to an existing script resource"), "错误应说明声明脚本路径不存在。")
	assert_null(manifest, "from_json_file 不应返回包含缺失脚本路径的 manifest。")


func test_manifest_json_report_rejects_non_script_declared_resources() -> void:
	var root_path: String = "res://tests/gf_core/tmp_non_script_declared_resource"
	var manifest_path: String = root_path.path_join(GFExtensionManifest.FILE_NAME)
	var resource_path: String = root_path.path_join("metadata.tres")
	_remove_path_if_exists(manifest_path)
	_remove_path_if_exists(resource_path)
	_remove_path_if_exists(root_path)
	var _make_dir_result: Variant = DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(root_path))
	_write_text_file(resource_path, "[gd_resource type=\"Resource\" format=3]\n")
	_write_text_file(manifest_path, JSON.stringify({
		"id": "author.non_script_resource",
		"display_name": "Non Script Resource",
		"version": "1.0.0",
		"kind": "extension",
		"editor_action_paths": [resource_path],
	}))

	var report: Dictionary = GFExtensionManifest.from_json_file_report(manifest_path)
	var manifest: GFExtensionManifest = GFExtensionManifest.from_json_file(manifest_path)
	var errors: Array[String] = GF_VARIANT_ACCESS.get_option_string_array(report, "errors")

	_remove_path_if_exists(manifest_path)
	_remove_path_if_exists(resource_path)
	_remove_path_if_exists(root_path)

	assert_false(GF_VARIANT_ACCESS.get_option_bool(report, "ok"), "manifest 声明非脚本资源作为贡献入口时应失败。")
	assert_true(_string_array_contains(errors, "must point to a GDScript resource"), "错误应说明贡献入口必须是 GDScript。")
	assert_null(manifest, "from_json_file 不应返回包含非脚本贡献入口的 manifest。")


func test_enabled_installer_paths_follow_extension_selection() -> void:
	var setting_restore: Dictionary = _set_project_setting(
		GFExtensionSettings.ENABLED_EXTENSIONS_SETTING,
		["gf.save"]
	)
	var auto_install_restore: Dictionary = _set_project_setting(
		GFExtensionSettings.AUTO_INSTALL_ENABLED_INSTALLERS_SETTING,
		true
	)

	var installer_paths: Array[String] = GFExtensionSettings.get_enabled_installer_paths()

	_restore_project_setting(GFExtensionSettings.AUTO_INSTALL_ENABLED_INSTALLERS_SETTING, auto_install_restore)
	_restore_project_setting(GFExtensionSettings.ENABLED_EXTENSIONS_SETTING, setting_restore)

	assert_eq(
		installer_paths,
		["res://addons/gf/extensions/save/extension.gd"],
		"启用扩展 installer 应只来自当前启用扩展 manifest。"
	)


func test_extension_resource_paths_must_stay_inside_extension_root() -> void:
	var feature_manifest: GFExtensionManifest = GFExtensionManifest.from_dictionary({
		"id": "author.feature",
		"display_name": "Feature",
		"version": "1.0.0",
		"kind": "extension",
	}, "res://addons/author_feature", "")
	GFExtensionSettings.set_cached_manifests([feature_manifest])

	var relative_path: String = GFExtensionSettings.get_extension_resource_path("author.feature", "scripts/tool.gd")
	var absolute_under_root: String = GFExtensionSettings.get_extension_resource_path("author.feature", "res://addons/author_feature/scripts/tool.gd")
	var user_path: String = GFExtensionSettings.get_extension_resource_path("author.feature", "user://tool.gd")
	var escaped_path: String = GFExtensionSettings.get_extension_resource_path("author.feature", "../author_other/tool.gd")
	var foreign_path: String = GFExtensionSettings.get_extension_resource_path("author.feature", "res://addons/gf/extensions/save/core/gf_save_scope.gd")

	GFExtensionSettings.clear_manifest_cache()

	assert_eq(relative_path, "res://addons/author_feature/scripts/tool.gd", "相对路径应解析到扩展 root 下。")
	assert_eq(absolute_under_root, "res://addons/author_feature/scripts/tool.gd", "root 内绝对 res:// 路径应允许。")
	assert_eq(user_path, "", "扩展资源路径不应接受 user://。")
	assert_eq(escaped_path, "", "相对路径不应能通过 .. 越过扩展 root。")
	assert_eq(foreign_path, "", "扩展资源路径不应指向其他扩展或项目目录。")


func test_extension_settings_can_query_manifest_and_enabled_state() -> void:
	var setting_restore: Dictionary = _set_project_setting(
		GFExtensionSettings.ENABLED_EXTENSIONS_SETTING,
		["gf.save"]
	)
	var save_manifest: GFExtensionManifest = GFExtensionSettings.get_manifest_by_id("gf.save")
	var has_save_extension: bool = GFExtensionSettings.has_extension("gf.save")
	var has_missing_extension: bool = GFExtensionSettings.has_extension("gf.missing")
	var save_enabled: bool = GFExtensionSettings.is_extension_enabled("gf.save")
	var combat_enabled: bool = GFExtensionSettings.is_extension_enabled("gf.combat")
	var missing_enabled: bool = GFExtensionSettings.is_extension_enabled("gf.missing")
	var save_scope_path: String = GFExtensionSettings.get_extension_resource_path(
		"gf.save",
		"core/gf_save_scope.gd"
	)
	var save_scope_script: Script = GFExtensionSettings.load_enabled_extension_script(
		"gf.save",
		"core/gf_save_scope.gd"
	)
	var save_action_paths: Array[String] = GFExtensionSettings.get_enabled_editor_action_paths()
	var save_dock_paths: Array[String] = GFExtensionSettings.get_enabled_editor_dock_paths()
	var save_inspector_paths: Array[String] = GFExtensionSettings.get_enabled_editor_inspector_paths()
	var save_import_paths: Array[String] = GFExtensionSettings.get_enabled_import_plugin_paths()
	var save_export_paths: Array[String] = GFExtensionSettings.get_enabled_export_plugin_paths()
	var save_gltf_document_paths: Array[String] = GFExtensionSettings.get_enabled_gltf_document_extension_paths()
	var save_access_extension_paths: Array[String] = GFExtensionSettings.get_enabled_access_generator_extension_paths()
	var save_debugger_paths: Array[String] = GFExtensionSettings.get_enabled_debugger_plugin_paths()
	var combat_script: Script = GFExtensionSettings.load_enabled_extension_script(
		"gf.combat",
		"actions/gf_combat_action.gd"
	)

	_restore_project_setting(GFExtensionSettings.ENABLED_EXTENSIONS_SETTING, setting_restore)

	assert_not_null(save_manifest, "应能按 ID 查询扩展 manifest。")
	assert_eq(save_manifest.id, "gf.save", "manifest 查询结果应匹配请求 ID。")
	assert_true(has_save_extension, "存在 manifest 的扩展应报告存在。")
	assert_false(has_missing_extension, "不存在 manifest 的扩展不应报告存在。")
	assert_true(save_enabled, "显式启用的扩展应报告为启用。")
	assert_false(combat_enabled, "未被当前设置启用的扩展应报告为禁用。")
	assert_false(missing_enabled, "不存在 manifest 的扩展不应报告为启用。")
	assert_eq(save_scope_path, "res://addons/gf/extensions/save/core/gf_save_scope.gd", "扩展内资源路径应由 manifest 根目录拼接。")
	assert_not_null(save_scope_script, "启用扩展内脚本应能通过扩展设置统一加载。")
	assert_true(
		save_action_paths.has("res://addons/gf/extensions/save/editor/gf_save_editor_actions.gd"),
		"启用扩展的菜单动作路径应由统一查询入口返回。"
	)
	assert_true(
		save_dock_paths.has("res://addons/gf/extensions/save/editor/gf_save_graph_dock.gd"),
		"Save 扩展的工作区页面路径应由统一查询入口返回。"
	)
	assert_true(
		save_inspector_paths.has("res://addons/gf/extensions/save/editor/gf_persist_properties_inspector_plugin.gd"),
		"Save 扩展的属性白名单 Inspector 路径应由统一查询入口返回。"
	)
	assert_true(save_import_paths.is_empty(), "Save 扩展未声明导入插件时应返回空导入插件路径。")
	assert_true(save_export_paths.is_empty(), "Save 扩展未声明导出插件时应返回空导出插件路径。")
	assert_true(save_gltf_document_paths.is_empty(), "Save 扩展未声明 glTF 文档扩展时应返回空 glTF 文档扩展路径。")
	assert_true(save_access_extension_paths.is_empty(), "Save 扩展未声明访问器扩展时应返回空访问器扩展路径。")
	assert_true(save_debugger_paths.is_empty(), "Save 扩展未声明 Debugger 插件时应返回空 Debugger 插件路径。")
	assert_null(combat_script, "未启用扩展内脚本不应被统一加载入口加载。")


func test_asset_metadata_contributes_exactly_one_gltf_document_extension() -> void:
	var setting_restore: Dictionary = _set_project_setting(
		GFExtensionSettings.ENABLED_EXTENSIONS_SETTING,
		["gf.asset_metadata"]
	)
	var selection_mode_restore: Dictionary = _set_project_setting(
		GFExtensionSettings.EXTENSION_SELECTION_MODE_SETTING,
		GFExtensionSettings.SELECTION_MODE_EXPLICIT
	)
	GFExtensionSettings.clear_manifest_cache()

	var gltf_document_paths: Array[String] = (
		GFExtensionSettings.get_enabled_gltf_document_extension_paths()
	)

	_restore_project_setting(
		GFExtensionSettings.EXTENSION_SELECTION_MODE_SETTING,
		selection_mode_restore
	)
	_restore_project_setting(GFExtensionSettings.ENABLED_EXTENSIONS_SETTING, setting_restore)
	GFExtensionSettings.clear_manifest_cache()

	assert_eq(
		gltf_document_paths,
		[
			"res://addons/gf/extensions/asset_metadata/editor/"
			+ "gf_asset_metadata_gltf_document_extension.gd",
		],
		"只启用 Asset Metadata 时应贡献恰好一个规范 glTF 文档扩展路径。"
	)


func test_extension_settings_collects_editor_tool_contribution_paths() -> void:
	var setting_restore: Dictionary = _set_project_setting(
		GFExtensionSettings.ENABLED_EXTENSIONS_SETTING,
		["gf.network"]
	)
	GFExtensionSettings.clear_manifest_cache()

	var network_manifest: GFExtensionManifest = GFExtensionSettings.get_manifest_by_id("gf.network")
	var action_paths: Array[String] = GFExtensionSettings.get_enabled_editor_action_paths()

	_restore_project_setting(GFExtensionSettings.ENABLED_EXTENSIONS_SETTING, setting_restore)
	GFExtensionSettings.clear_manifest_cache()

	assert_not_null(network_manifest, "Network 扩展 manifest 应可发现。")
	assert_true(network_manifest.editor_action_paths.is_empty(), "Network runtime manifest 不应携带可选 editor tool 路径。")
	assert_true(
		action_paths.has("res://addons/gf/extensions/network/editor/gf_network_editor_actions.gd"),
		"启用扩展对应的 tool contribution 应贡献编辑器动作路径。"
	)


func test_extension_tool_contribution_schema_normalizes_valid_paths() -> void:
	var report: Dictionary = GF_EXTENSION_TOOL_CONTRIBUTION_SCRIPT.parse_dictionary({
		"schema_version": float(GF_EXTENSION_TOOL_CONTRIBUTION_SCRIPT.SCHEMA_VERSION),
		"extension_id": "author.feature",
		"debugger_plugin_paths": [" editor/debugger_plugin.gd ", "editor/debugger_plugin.gd"],
		"editor_action_paths": [" editor/action.gd ", "editor/action.gd"],
	}, "author.feature")
	var data: Dictionary = GF_VARIANT_ACCESS.get_option_dictionary(report, "data")

	assert_true(GF_VARIANT_ACCESS.get_option_bool(report, "ok", false), "合法 tool contribution 应通过 schema 校验。")
	assert_eq(
		GF_VARIANT_ACCESS.get_option_int(data, "schema_version"),
		GF_EXTENSION_TOOL_CONTRIBUTION_SCRIPT.SCHEMA_VERSION,
		"规范化结果应保留明确 schema 版本。"
	)
	assert_eq(GF_VARIANT_ACCESS.get_option_string(data, "extension_id"), "author.feature", "规范化结果应保留扩展 ID。")
	assert_eq(
		GF_VARIANT_ACCESS.get_option_array(data, "debugger_plugin_paths"),
		["editor/debugger_plugin.gd"],
		"Debugger 插件路径应去空白并去重。"
	)
	assert_eq(
		GF_VARIANT_ACCESS.get_option_array(data, "editor_action_paths"),
		["editor/action.gd"],
		"路径应去空白并去重。"
	)


func test_extension_tool_contribution_schema_rejects_legacy_version() -> void:
	var legacy_schema_version: int = GF_EXTENSION_TOOL_CONTRIBUTION_SCRIPT.SCHEMA_VERSION - 1
	var report: Dictionary = GF_EXTENSION_TOOL_CONTRIBUTION_SCRIPT.parse_dictionary({
		"schema_version": legacy_schema_version,
		"extension_id": "author.feature",
	}, "author.feature")
	var errors: Array = GF_VARIANT_ACCESS.get_option_array(report, "errors")

	assert_false(GF_VARIANT_ACCESS.get_option_bool(report, "ok", true), "旧 tool contribution schema 不应隐式兼容。")
	assert_true(
		errors.has("unsupported tool contribution schema_version: %d" % legacy_schema_version),
		"schema v1 应给出明确迁移错误。"
	)


func test_extension_tool_contribution_schema_rejects_future_and_unknown_fields() -> void:
	var future_schema_version: int = GF_EXTENSION_TOOL_CONTRIBUTION_SCRIPT.SCHEMA_VERSION + 1
	var report: Dictionary = GF_EXTENSION_TOOL_CONTRIBUTION_SCRIPT.parse_dictionary({
		"schema_version": future_schema_version,
		"extension_id": "author.feature",
		"future_loader": "res://future.gd",
	}, "author.feature")
	var errors: Array = GF_VARIANT_ACCESS.get_option_array(report, "errors")

	assert_false(GF_VARIANT_ACCESS.get_option_bool(report, "ok", true), "未来 schema 和未知字段必须 fail-closed。")
	assert_true(
		errors.has("unsupported tool contribution schema_version: %d" % future_schema_version),
		"应报告未来 schema。"
	)
	assert_true(errors.has("unsupported tool contribution field: future_loader"), "应报告未知字段。")


func test_extension_tool_contribution_schema_rejects_mismatched_id_and_invalid_paths() -> void:
	var report: Dictionary = GF_EXTENSION_TOOL_CONTRIBUTION_SCRIPT.parse_dictionary({
		"schema_version": GF_EXTENSION_TOOL_CONTRIBUTION_SCRIPT.SCHEMA_VERSION,
		"extension_id": "author.other",
		"editor_action_paths": ["", 42],
	}, "author.feature")
	var errors: Array = GF_VARIANT_ACCESS.get_option_array(report, "errors")

	assert_false(GF_VARIANT_ACCESS.get_option_bool(report, "ok", true), "错误 ID 和非法路径不得被 discovery 消费。")
	assert_true(errors.has("tool contribution extension_id mismatch"), "应报告扩展 ID 不匹配。")
	assert_true(
		errors.has("tool contribution editor_action_paths must not contain empty paths"),
		"应拒绝空路径。"
	)
	assert_true(
		errors.has("tool contribution editor_action_paths must contain only strings"),
		"应拒绝非字符串路径。"
	)


func test_extension_tool_contribution_schema_rejects_invalid_id_without_expected_id() -> void:
	var report: Dictionary = GF_EXTENSION_TOOL_CONTRIBUTION_SCRIPT.parse_dictionary({
		"schema_version": GF_EXTENSION_TOOL_CONTRIBUTION_SCRIPT.SCHEMA_VERSION,
		"extension_id": "Invalid Extension",
	})
	var errors: Array = GF_VARIANT_ACCESS.get_option_array(report, "errors")

	assert_false(GF_VARIANT_ACCESS.get_option_bool(report, "ok", true), "贡献协议自身必须校验扩展 ID 语法。")
	assert_true(
		errors.any(func(error: Variant) -> bool: return "lowercase dotted identifier" in str(error)),
		"未提供 expected_extension_id 时也应拒绝无效扩展 ID。"
	)


func test_extension_selection_discovery_refreshes_when_tool_contribution_file_changes() -> void:
	var root_path: String = "res://tests/gf_core/tmp_extension_selection_cache"
	var extension_dir: String = root_path.path_join("feature")
	var editor_dir: String = extension_dir.path_join("editor")
	var contribution_path: String = editor_dir.path_join("gf_tool_contribution.json")
	var first_action_path: String = editor_dir.path_join("first_action.gd")
	var second_action_path: String = editor_dir.path_join("second_action.gd")
	var first_debugger_path: String = editor_dir.path_join("first_debugger_plugin.gd")
	var second_debugger_path: String = editor_dir.path_join("second_debugger_plugin.gd")
	_remove_path_if_exists(contribution_path)
	_remove_path_if_exists(first_action_path)
	_remove_path_if_exists(first_action_path + ".uid")
	_remove_path_if_exists(second_action_path)
	_remove_path_if_exists(second_action_path + ".uid")
	_remove_path_if_exists(first_debugger_path)
	_remove_path_if_exists(first_debugger_path + ".uid")
	_remove_path_if_exists(second_debugger_path)
	_remove_path_if_exists(second_debugger_path + ".uid")
	_remove_path_if_exists(editor_dir)
	_remove_path_if_exists(extension_dir)
	_remove_path_if_exists(root_path)
	var _make_dir_result: Variant = DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(editor_dir))
	_write_text_file(first_action_path, "extends RefCounted\n")
	_write_text_file(second_action_path, "extends RefCounted\n")
	_write_text_file(first_debugger_path, "@tool\nextends EditorDebuggerPlugin\n")
	_write_text_file(second_debugger_path, "@tool\nextends EditorDebuggerPlugin\n")
	_write_text_file(contribution_path, JSON.stringify({
		"schema_version": GF_EXTENSION_TOOL_CONTRIBUTION_SCRIPT.SCHEMA_VERSION,
		"extension_id": "author.selection",
		"debugger_plugin_paths": [first_debugger_path],
		"editor_action_paths": [first_action_path],
	}))
	var manifest: GFExtensionManifest = GFExtensionManifest.from_dictionary({
		"id": "author.selection",
		"display_name": "Selection",
		"version": "1.0.0",
		"kind": "extension",
	}, extension_dir, extension_dir.path_join("gf_extension.json"))
	var restore: Dictionary = _set_project_setting(
		GFExtensionSettings.ENABLED_EXTENSIONS_SETTING,
		["author.selection"]
	)
	GFExtensionSettings.set_cached_manifests([manifest])

	var first_action_paths: Array[String] = GFExtensionSettings.get_enabled_editor_action_paths()
	var first_debugger_paths: Array[String] = GFExtensionSettings.get_enabled_debugger_plugin_paths()
	var selection_manifests: Array[GFExtensionManifest] = [manifest]
	var selection_ids: Array[String] = ["author.selection"]
	var first_snapshot: Dictionary = GF_EXTENSION_SELECTION_DISCOVERY_SCRIPT.get_snapshot(
		selection_manifests,
		selection_ids,
		{
			"builtin_extension_ids": GFExtensionSettings.BUILT_IN_EXTENSION_IDS,
			"force_refresh": true,
		}
	)
	var manifest_paths: Dictionary = GF_VARIANT_ACCESS.get_option_dictionary(
		first_snapshot,
		"manifest_paths"
	)
	var contribution_paths: Dictionary = GF_VARIANT_ACCESS.get_option_dictionary(
		first_snapshot,
		"contribution_paths"
	)
	var merged_paths: Dictionary = GF_VARIANT_ACCESS.get_option_dictionary(first_snapshot, "paths")
	_write_text_file(contribution_path, JSON.stringify({
		"schema_version": GF_EXTENSION_TOOL_CONTRIBUTION_SCRIPT.SCHEMA_VERSION,
		"extension_id": "author.selection",
		"debugger_plugin_paths": [second_debugger_path],
		"editor_action_paths": [second_action_path],
	}))
	var second_action_paths: Array[String] = GFExtensionSettings.get_enabled_editor_action_paths()
	var second_debugger_paths: Array[String] = GFExtensionSettings.get_enabled_debugger_plugin_paths()

	GFExtensionSettings.clear_manifest_cache()
	_restore_project_setting(GFExtensionSettings.ENABLED_EXTENSIONS_SETTING, restore)
	_remove_path_if_exists(contribution_path)
	_remove_path_if_exists(first_action_path)
	_remove_path_if_exists(first_action_path + ".uid")
	_remove_path_if_exists(second_action_path)
	_remove_path_if_exists(second_action_path + ".uid")
	_remove_path_if_exists(first_debugger_path)
	_remove_path_if_exists(first_debugger_path + ".uid")
	_remove_path_if_exists(second_debugger_path)
	_remove_path_if_exists(second_debugger_path + ".uid")
	_remove_path_if_exists(editor_dir)
	_remove_path_if_exists(extension_dir)
	_remove_path_if_exists(root_path)

	assert_eq(first_action_paths, [first_action_path], "第一次读取应返回 tool contribution 的初始路径。")
	assert_eq(second_action_paths, [second_action_path], "同一路径 tool contribution 文件变化后应刷新 selection snapshot。")
	assert_eq(first_debugger_paths, [first_debugger_path], "第一次读取应返回扩展贡献的 Debugger 插件路径。")
	assert_eq(second_debugger_paths, [second_debugger_path], "Debugger 插件贡献文件变化后应刷新 selection snapshot。")
	assert_false(
		manifest_paths.has("debugger_plugin_paths"),
		"Debugger 插件路径不应进入 runtime manifest 路径集合。"
	)
	assert_eq(
		GF_VARIANT_ACCESS.get_option_string_array(contribution_paths, "debugger_plugin_paths"),
		[first_debugger_path],
		"Debugger 插件路径应保留在 tool contribution 路径集合。"
	)
	assert_eq(
		GF_VARIANT_ACCESS.get_option_string_array(merged_paths, "debugger_plugin_paths"),
		[first_debugger_path],
		"启用选择的合并路径应暴露扩展贡献的 Debugger 插件路径。"
	)


func test_invalid_tool_contribution_is_public_partial_status() -> void:
	var root_path: String = "res://tests/gf_core/tmp_invalid_tool_contribution_status"
	var extension_dir: String = root_path.path_join("feature")
	var editor_dir: String = extension_dir.path_join("editor")
	var contribution_path: String = editor_dir.path_join("gf_tool_contribution.json")
	_remove_path_if_exists(contribution_path)
	_remove_path_if_exists(editor_dir)
	_remove_path_if_exists(extension_dir)
	_remove_path_if_exists(root_path)
	var _make_dir_result: Error = DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path(editor_dir)
	)
	_write_text_file(contribution_path, JSON.stringify({
		"schema_version": GF_EXTENSION_TOOL_CONTRIBUTION_SCRIPT.SCHEMA_VERSION + 1,
		"extension_id": "author.partial",
	}))
	var manifest: GFExtensionManifest = GFExtensionManifest.from_dictionary({
		"id": "author.partial",
		"display_name": "Partial",
		"version": "1.0.0",
		"kind": "extension",
	}, extension_dir, extension_dir.path_join(GFExtensionManifest.FILE_NAME))
	var manifests: Array[GFExtensionManifest] = [manifest]
	var enabled_ids: Array[String] = ["author.partial"]
	GF_EXTENSION_SELECTION_DISCOVERY_SCRIPT.clear_cache()

	var snapshot: Dictionary = GF_EXTENSION_SELECTION_DISCOVERY_SCRIPT.get_snapshot(
		manifests,
		enabled_ids,
		{ "force_refresh": true }
	)
	var setting_restore: Dictionary = _set_project_setting(
		GFExtensionSettings.ENABLED_EXTENSIONS_SETTING,
		enabled_ids
	)
	GFExtensionSettings.set_cached_manifests(manifests)
	var public_report: Dictionary = GFExtensionSettings.get_extension_selection_report()

	GFExtensionSettings.clear_manifest_cache()
	_restore_project_setting(GFExtensionSettings.ENABLED_EXTENSIONS_SETTING, setting_restore)
	_remove_path_if_exists(contribution_path)
	_remove_path_if_exists(editor_dir)
	_remove_path_if_exists(extension_dir)
	_remove_path_if_exists(root_path)

	assert_false(GF_VARIANT_ACCESS.get_option_bool(snapshot, "ok", true), "已存在但无效的贡献不能报告完整成功。")
	assert_eq(
		GF_VARIANT_ACCESS.get_option_string_name(snapshot, "status"),
		GF_EXTENSION_SELECTION_DISCOVERY_SCRIPT.STATUS_PARTIAL,
		"逐扩展隔离的贡献错误应形成 partial 状态。"
	)
	assert_true(GF_VARIANT_ACCESS.get_option_bool(snapshot, "partial"), "partial 布尔投影应与状态一致。")
	assert_true(
		GF_VARIANT_ACCESS.get_option_bool(snapshot, "paths_allowed"),
		"manifest 图有效时，其他已验证扩展路径仍可使用。"
	)
	assert_eq(
		GF_VARIANT_ACCESS.get_option_array(snapshot, "tool_contribution_errors").size(),
		1,
		"raw snapshot 应保留 contribution 错误。"
	)
	assert_false(GF_VARIANT_ACCESS.get_option_bool(public_report, "ok", true), "公共诊断不得隐藏 contribution 错误。")
	assert_eq(
		GF_VARIANT_ACCESS.get_option_string_name(public_report, "status"),
		GF_EXTENSION_SELECTION_DISCOVERY_SCRIPT.STATUS_PARTIAL,
		"公共诊断应投影同一 partial 状态。"
	)
	assert_eq(
		GF_VARIANT_ACCESS.get_option_array(public_report, "tool_contribution_errors").size(),
		1,
		"公共诊断应暴露可定位的 contribution 错误。"
	)


func test_tool_contribution_discovery_rejects_oversized_json() -> void:
	var root_path: String = "res://tests/gf_core/tmp_tool_contribution_json_budget"
	var editor_dir: String = root_path.path_join("editor")
	var contribution_path: String = editor_dir.path_join("gf_tool_contribution.json")
	_remove_path_if_exists(contribution_path)
	_remove_path_if_exists(editor_dir)
	_remove_path_if_exists(root_path)
	var _make_dir_result: Error = DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path(editor_dir)
	)
	_write_text_file(contribution_path, JSON.stringify({
		"schema_version": GF_EXTENSION_TOOL_CONTRIBUTION_SCRIPT.SCHEMA_VERSION,
		"extension_id": "author.oversized_tool",
		"editor_action_paths": [],
		"debugger_plugin_paths": [],
	}))
	var manifest: GFExtensionManifest = GFExtensionManifest.from_dictionary({
		"id": "author.oversized_tool",
		"display_name": "Oversized Tool",
		"version": "1.0.0",
		"kind": "extension",
	}, root_path, root_path.path_join(GFExtensionManifest.FILE_NAME))
	GF_EXTENSION_SELECTION_DISCOVERY_SCRIPT.clear_cache()

	var snapshot: Dictionary = GF_EXTENSION_SELECTION_DISCOVERY_SCRIPT.get_snapshot(
		[manifest],
		["author.oversized_tool"],
		{
			"force_refresh": true,
			"max_json_file_bytes": 48,
		}
	)
	var errors: Array = GF_VARIANT_ACCESS.get_option_array(snapshot, "tool_contribution_errors")
	GF_EXTENSION_SELECTION_DISCOVERY_SCRIPT.clear_cache()
	_remove_path_if_exists(contribution_path)
	_remove_path_if_exists(editor_dir)
	_remove_path_if_exists(root_path)

	assert_eq(
		GF_VARIANT_ACCESS.get_option_string_name(snapshot, "status"),
		GF_EXTENSION_SELECTION_DISCOVERY_SCRIPT.STATUS_PARTIAL,
		"超限 contribution 应作为隔离后的 partial failure。"
	)
	assert_eq(errors.size(), 1, "超限 contribution 应形成可定位错误。")
	if errors.size() == 1:
		assert_true(
			GF_VARIANT_ACCESS.get_option_string_array(
				GF_VARIANT_ACCESS.as_dictionary(errors[0]),
				"errors"
			).any(func(error: String) -> bool: return error.contains("max_json_file_bytes")),
			"contribution 错误应暴露 JSON limit。"
		)


func test_load_enabled_extension_script_rejects_absolute_paths_outside_extension_root() -> void:
	var restore: Dictionary = _set_project_setting(
		GFExtensionSettings.ENABLED_EXTENSIONS_SETTING,
		["gf.save"]
	)

	var script: Script = GFExtensionSettings.load_enabled_extension_script(
		"gf.save",
		"res://addons/gf/extensions/combat/actions/gf_combat_action.gd"
	)

	_restore_project_setting(GFExtensionSettings.ENABLED_EXTENSIONS_SETTING, restore)

	assert_null(script, "启用扩展脚本加载入口不应加载扩展 root 外脚本。")


func test_load_enabled_extension_script_rejects_non_script_resource_inside_extension_root() -> void:
	var restore: Dictionary = _set_project_setting(
		GFExtensionSettings.ENABLED_EXTENSIONS_SETTING,
		["gf.save"]
	)

	var script: Script = GFExtensionSettings.load_enabled_extension_script(
		"gf.save",
		"gf_extension.json"
	)

	_restore_project_setting(GFExtensionSettings.ENABLED_EXTENSIONS_SETTING, restore)

	assert_null(script, "启用扩展脚本加载入口不应加载扩展 root 内的非脚本资源。")


func test_extension_selection_report_includes_unknown_enabled_ids() -> void:
	var restore: Dictionary = _set_project_setting(
		GFExtensionSettings.ENABLED_EXTENSIONS_SETTING,
		["gf.save", "author.missing"]
	)

	var report: Dictionary = GFExtensionSettings.get_extension_selection_report()
	var unknown_enabled_ids: Array = GF_VARIANT_ACCESS.get_option_array(report, "unknown_enabled_ids")
	var resolved_ids: Array = GF_VARIANT_ACCESS.get_option_array(report, "resolved_ids")
	var known_action_paths: Array[String] = GFExtensionSettings.get_enabled_editor_action_paths()

	_restore_project_setting(GFExtensionSettings.ENABLED_EXTENSIONS_SETTING, restore)

	assert_true(unknown_enabled_ids.has("author.missing"), "启用列表中不存在 manifest 的扩展 ID 应被报告。")
	assert_false(resolved_ids.has("author.missing"), "未知扩展 ID 不应进入最终启用结果。")
	assert_eq(GF_VARIANT_ACCESS.get_option_int(report, "enabled_count", -1), resolved_ids.size(), "启用数量应基于最终有效启用结果。")
	assert_false(GF_VARIANT_ACCESS.get_option_bool(report, "ok", true), "存在未知启用扩展时选择诊断不应通过。")
	assert_eq(
		GF_VARIANT_ACCESS.get_option_string_name(report, "status"),
		GF_EXTENSION_SELECTION_DISCOVERY_SCRIPT.STATUS_PARTIAL,
		"未知 ID 应成为显式 partial，而不是含义不明的 ok=false。"
	)
	assert_true(
		GF_VARIANT_ACCESS.get_option_bool(report, "paths_allowed"),
		"未知 ID 无法授权路径，但不应撤销独立验证通过的已知扩展路径。"
	)
	assert_true(
		known_action_paths.has("res://addons/gf/extensions/save/editor/gf_save_editor_actions.gd"),
		"partial 状态下已知扩展的合法路径应继续可用。"
	)


func test_set_enabled_extension_ids_drops_unknown_ids() -> void:
	var restore: Dictionary = _set_project_setting(
		GFExtensionSettings.ENABLED_EXTENSIONS_SETTING,
		["gf.save", "author.missing"]
	)

	GFExtensionSettings.set_enabled_extension_ids(["gf.save", "author.missing"], true)
	var stored_ids: Array[String] = GFExtensionSettings.get_enabled_extension_ids()

	_restore_project_setting(GFExtensionSettings.ENABLED_EXTENSIONS_SETTING, restore)

	assert_eq(stored_ids, ["gf.save"], "保存启用扩展时应只保留可发现的 manifest ID。")


func test_set_enabled_extension_ids_drops_unknown_ids_without_dependency_expansion() -> void:
	var restore: Dictionary = _set_project_setting(
		GFExtensionSettings.ENABLED_EXTENSIONS_SETTING,
		["author.missing"]
	)

	GFExtensionSettings.set_enabled_extension_ids(["gf.save", "author.missing"], false)
	var stored_ids: Array[String] = GFExtensionSettings.get_enabled_extension_ids()

	_restore_project_setting(GFExtensionSettings.ENABLED_EXTENSIONS_SETTING, restore)

	assert_eq(stored_ids, ["gf.save"], "即使不补齐依赖，保存启用扩展时也不应保留未知 ID。")


func test_extension_settings_defaults_to_strict_disabled_reference_policy() -> void:
	var setting_name: String = GFExtensionSettings.EXPORT_FAIL_ON_DISABLED_REFERENCES_SETTING
	var restore: Dictionary = {
		"had_setting": ProjectSettings.has_setting(setting_name),
		"value": ProjectSettings.get_setting(setting_name, null),
	}
	ProjectSettings.clear(setting_name)

	assert_true(
		GFExtensionSettings.should_fail_export_on_disabled_extension_references(),
		"默认应把禁用扩展引用审计报告为错误。"
	)

	_restore_project_setting(setting_name, restore)


func test_extension_settings_allows_explicit_warning_only_disabled_reference_policy() -> void:
	var restore: Dictionary = _set_project_setting(
		GFExtensionSettings.EXPORT_FAIL_ON_DISABLED_REFERENCES_SETTING,
		false
	)

	assert_false(
		GFExtensionSettings.should_fail_export_on_disabled_extension_references(),
		"显式 false 时禁用扩展引用审计应仅告警。"
	)

	GFExtensionSettings.set_fail_export_on_disabled_extension_references(true)

	assert_true(
		GFExtensionSettings.should_fail_export_on_disabled_extension_references(),
		"启用策略后禁用扩展引用审计应报告为错误。"
	)

	_restore_project_setting(GFExtensionSettings.EXPORT_FAIL_ON_DISABLED_REFERENCES_SETTING, restore)


func test_extension_manifest_dependency_graph_is_valid() -> void:
	var report: Dictionary = GFExtensionSettings.get_manifest_graph_report(
		GFExtensionCatalog.load_extension_manifests()
	)

	assert_true(
		GF_VARIANT_ACCESS.get_option_bool(report, "ok"),
		"GF 内置扩展依赖图必须无缺失、无重复、无环：%s" % report
	)


func test_extension_manifests_are_atomic_capability_bundles() -> void:
	var issues: PackedStringArray = PackedStringArray()
	for manifest: GFExtensionManifest in GFExtensionCatalog.load_extension_manifests():
		var manifest_data: Dictionary = _read_json_dictionary(manifest.source_path)
		if not manifest_data.has("extension_version"):
			var _append_result_558: Variant = issues.append("%s missing extension_version" % manifest.id)

		for dependency_id: String in manifest.dependencies:
			if not EXTENSION_ALLOWED_DEPENDENCIES.has(dependency_id):
				var _append_result_562: Variant = issues.append("%s declares dependency %s" % [manifest.id, dependency_id])

	assert_eq(
		Array(issues),
		[],
		"GF 内置扩展必须保持原子化：只允许依赖 gf.kernel 与 gf.standard，不能声明内置扩展硬依赖。"
	)


func test_kernel_and_standard_do_not_hard_preload_extensions() -> void:
	var files: Array[String] = []
	_collect_gd_files("res://addons/gf/kernel", files)
	_collect_gd_files("res://addons/gf/standard", files)

	var issues: PackedStringArray = PackedStringArray()
	for path: String in files:
		var source: String = _read_text(path)
		if source.contains("preload(\"res://addons/gf/extensions/"):
			var _append_result_580: Variant = issues.append(path)

	assert_eq(Array(issues), [], "kernel 与 standard 不能硬 preload 可选扩展脚本。")


func test_kernel_extension_path_references_stay_in_extension_infrastructure() -> void:
	var files: Array[String] = []
	_collect_gd_files("res://addons/gf/kernel", files)
	_collect_gd_files("res://addons/gf/standard", files)

	var issues: PackedStringArray = PackedStringArray()
	for path: String in files:
		if KERNEL_EXTENSION_REFERENCE_ALLOWED_FILES.has(path):
			continue
		var source: String = _read_text(path)
		if source.contains(EXTENSION_ROOT + "/"):
			var _append_result_596: Variant = issues.append(path)

	assert_eq(
		Array(issues),
		[],
		"kernel/standard 只有 extension 基础设施可以知道 GF 扩展根目录。"
	)


func test_kernel_and_standard_do_not_hard_reference_extension_class_names() -> void:
	var extension_class_roots: Dictionary = _collect_extension_class_roots()
	var files: Array[String] = []
	_collect_gd_files("res://addons/gf/kernel", files)
	_collect_gd_files("res://addons/gf/standard", files)

	var issues: PackedStringArray = PackedStringArray()
	for path: String in files:
		if KERNEL_STANDARD_EXTENSION_CLASS_REFERENCE_ALLOWED_FILES.has(path):
			continue

		var source: String = _read_text(path)
		for class_name_variant: Variant in extension_class_roots.keys():
			var class_name_text: String = GF_VARIANT_ACCESS.to_text(class_name_variant)
			if _source_contains_identifier(source, class_name_text):
				var _append_result_620: Variant = issues.append("%s references %s" % [path, class_name_text])

	assert_eq(
		Array(issues),
		[],
		"kernel/standard 不应直接引用可选扩展 class_name；可选联动应通过扩展设置和动态脚本加载完成。"
	)


func test_extensions_do_not_hard_reference_other_extensions() -> void:
	var files: Array[String] = []
	_collect_gd_files(EXTENSION_ROOT, files)
	var extension_class_roots: Dictionary = _collect_extension_class_roots()

	var issues: PackedStringArray = PackedStringArray()
	for path: String in files:
		var extension_root: String = _get_extension_root(path)
		var source: String = _read_text(path)
		var referenced_roots: Array[String] = _extract_extension_roots(source)
		for referenced_root: String in referenced_roots:
			if not _extension_root_can_reference(extension_root, referenced_root):
				var _append_result_641: Variant = issues.append("%s references %s" % [path, referenced_root])

		for class_name_variant: Variant in extension_class_roots.keys():
			var class_name_text: String = GF_VARIANT_ACCESS.to_text(class_name_variant)
			var class_root: String = GF_VARIANT_ACCESS.to_text(extension_class_roots[class_name_text])
			if (
				not _extension_root_can_reference(extension_root, class_root)
				and _source_contains_identifier(source, class_name_text)
			):
				var _append_result_650: Variant = issues.append("%s references class %s" % [path, class_name_text])

	assert_eq(Array(issues), [], "GF 内置扩展只能硬引用自身；跨扩展组合属于项目或外部插件。")


func test_extension_export_plugin_reports_stable_name() -> void:
	var export_plugin_script: Script = GF_EXTENSION_EXPORT_PLUGIN_BASE
	var method_names: Array[StringName] = []
	for method_info: Dictionary in export_plugin_script.get_script_method_list():
		method_names.append(GF_VARIANT_ACCESS.get_option_string_name(method_info, "name"))

	assert_true(
		method_names.has(&"_get_name"),
		"EditorExportPlugin 必须覆盖 _get_name()，避免导出流程报错。"
	)


func test_extension_export_plugin_matches_disabled_roots() -> void:
	assert_true(
		GF_EXTENSION_EXPORT_PLUGIN_BASE._should_skip_export_path(
			"res://addons/gf/extensions/save/graph/gf_save_graph_utility.gd",
			["res://addons/gf/extensions/save"]
		),
		"禁用扩展根目录下的文件应被导出过滤命中。"
	)
	assert_true(
		GF_EXTENSION_EXPORT_PLUGIN_BASE._should_skip_export_path(
			"res://addons/gf/extensions/save",
			["res://addons/gf/extensions/save"]
		),
		"禁用扩展根目录本身也应被导出过滤命中。"
	)
	assert_false(
		GF_EXTENSION_EXPORT_PLUGIN_BASE._should_skip_export_path(
			"res://addons/gf/extensions/save_extra/gf_extension.json",
			["res://addons/gf/extensions/save"]
		),
		"前缀相似但不在根目录内的路径不应被误过滤。"
	)


func test_extension_export_plugin_collects_disabled_roots_without_editor_instance() -> void:
	var enabled_manifest: GFExtensionManifest = GFExtensionManifest.from_dictionary({
		"id": "author.enabled",
		"display_name": "Enabled",
		"version": "1.0.0",
		"kind": "extension",
	}, "res://addons/author_enabled", "")
	var disabled_manifest: GFExtensionManifest = GFExtensionManifest.from_dictionary({
		"id": "author.disabled",
		"display_name": "Disabled",
		"version": "1.0.0",
		"kind": "extension",
	}, "res://addons/author_disabled", "")
	var enabled_restore: Dictionary = _set_project_setting(
		GFExtensionSettings.ENABLED_EXTENSIONS_SETTING,
		["author.enabled"]
	)
	var export_restore: Dictionary = _set_project_setting(
		GFExtensionSettings.EXPORT_EXCLUDE_DISABLED_SETTING,
		true
	)
	GFExtensionSettings.set_cached_manifests([enabled_manifest, disabled_manifest])

	var disabled_roots: Array[String] = []
	var disabled_manifests: Array[GFExtensionManifest] = []
	var graph_report: Dictionary = GF_EXTENSION_EXPORT_PLUGIN_BASE._collect_disabled_export_state(
		disabled_roots,
		disabled_manifests
	)
	var skips_disabled_path: bool = GF_EXTENSION_EXPORT_PLUGIN_BASE._should_skip_export_path(
		"res://addons/author_disabled/runtime/tool.gd",
		disabled_roots
	)
	var skips_similar_prefix: bool = GF_EXTENSION_EXPORT_PLUGIN_BASE._should_skip_export_path(
		"res://addons/author_disabled_extra/runtime/tool.gd",
		disabled_roots
	)

	GFExtensionSettings.clear_manifest_cache()
	_restore_project_setting(GFExtensionSettings.EXPORT_EXCLUDE_DISABLED_SETTING, export_restore)
	_restore_project_setting(GFExtensionSettings.ENABLED_EXTENSIONS_SETTING, enabled_restore)

	assert_true(
		GF_VARIANT_ACCESS.get_option_bool(graph_report, "ok", false),
		"禁用根目录收集前应确认 manifest 图有效。"
	)
	assert_eq(disabled_roots, ["res://addons/author_disabled"], "导出插件应只收集当前禁用扩展根目录。")
	assert_eq(disabled_manifests.size(), 1, "导出插件应保留禁用 manifest 供引用审计使用。")
	assert_true(skips_disabled_path, "导出插件应跳过禁用扩展根目录下的文件。")
	assert_false(skips_similar_prefix, "导出插件不应跳过前缀相似的其他目录。")


func test_extension_export_plugin_blocks_invalid_manifest_graph() -> void:
	var feature_manifest: GFExtensionManifest = GFExtensionManifest.from_dictionary({
		"id": "author.feature",
		"display_name": "Feature",
		"version": "1.0.0",
		"kind": "extension",
		"dependencies": ["author.missing"],
	}, "res://addons/author_feature", "")
	var report: Dictionary = GFExtensionSettings.get_manifest_graph_report([feature_manifest])
	var formatted_report: String = GF_EXTENSION_EXPORT_PLUGIN_BASE._format_manifest_graph_report(report)

	assert_false(
		GF_EXTENSION_EXPORT_PLUGIN_BASE._manifest_graph_allows_export(report),
		"导出插件不应在 manifest 图无效时继续导出过滤。"
	)
	assert_true(formatted_report.contains("author.feature"), "导出错误信息应包含出问题的扩展 ID。")
	assert_true(formatted_report.contains("author.missing"), "导出错误信息应包含缺失依赖 ID。")


func test_extension_usage_audit_finds_project_reference() -> void:
	var directory: String = "user://gf_extension_usage_audit"
	var path: String = directory.path_join("uses_save.gd")
	var _make_dir_recursive_absolute_result_682: Variant = DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	var _store_string_result_684: Variant = file.store_string('const SaveGraph = preload("res://addons/gf/extensions/save/graph/gf_save_graph_utility.gd")')
	file.close()

	var report: Dictionary = GFExtensionUsageAudit.find_references_to_root_report(
		"res://addons/gf/extensions/save",
		{
			"scan_roots": [directory],
			"ignored_roots": [],
		}
	)
	var references: Array = GF_VARIANT_ACCESS.get_option_array(report, "references")

	var _remove_absolute_result_695: Variant = DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	var _remove_absolute_result_696: Variant = DirAccess.remove_absolute(ProjectSettings.globalize_path(directory))

	assert_eq(references.size(), 1, "直接 preload 禁用扩展目录下的脚本应被审计发现。")
	var reference: Dictionary = GF_VARIANT_ACCESS.as_dictionary(references[0])
	assert_eq(GF_VARIANT_ACCESS.get_option_string(reference, "path"), path, "审计结果应包含引用文件路径。")
	assert_eq(GF_VARIANT_ACCESS.get_option_string(reference, "match"), "res://addons/gf/extensions/save", "审计结果应暴露命中的稳定 token。")
	assert_false(GF_VARIANT_ACCESS.get_option_string(reference, "preview").contains("preload"), "审计 preview 不应包含源码行原文。")


func test_extension_usage_audit_finds_windows_style_project_reference() -> void:
	var directory: String = "user://gf_extension_usage_audit_windows"
	var path: String = directory.path_join("uses_save_windows.gd")
	var _make_dir_recursive_absolute_result: Variant = DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	_write_text_file(
		path,
		"const SaveWin = preload(\"res:\\\\addons\\\\gf\\\\extensions\\\\save\\\\graph\\\\gf_save_graph_utility.gd\")"
	)

	var report: Dictionary = GFExtensionUsageAudit.find_references_to_root_report(
		"res://addons/gf/extensions/save",
		{
			"scan_roots": [directory],
			"ignored_roots": [],
		}
	)
	var references: Array = GF_VARIANT_ACCESS.get_option_array(report, "references")

	_remove_path_if_exists(path)
	_remove_path_if_exists(directory)

	assert_eq(references.size(), 1, "反斜杠形式的禁用扩展资源路径也应被审计发现。")
	assert_eq(GF_VARIANT_ACCESS.get_option_string(GF_VARIANT_ACCESS.as_dictionary(references[0]), "path"), path, "审计结果应包含引用文件路径。")


func test_extension_usage_audit_normalizes_scan_and_ignored_roots() -> void:
	var directory: String = "user://gf_extension_usage_audit_ignored"
	var keep_dir: String = directory.path_join("keep")
	var skip_dir: String = directory.path_join("skip")
	var keep_path: String = keep_dir.path_join("uses_save_keep.gd")
	var skip_path: String = skip_dir.path_join("uses_save_skip.gd")
	var _make_keep_dir_result: Variant = DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(keep_dir))
	var _make_skip_dir_result: Variant = DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(skip_dir))
	_write_text_file(keep_path, 'const SaveKeep = preload("res://addons/gf/extensions/save/graph/gf_save_graph_utility.gd")')
	_write_text_file(skip_path, 'const SaveSkip = preload("res://addons/gf/extensions/save/graph/gf_save_graph_utility.gd")')

	var references: Array = GFExtensionUsageAudit.find_references_to_root(
		"res://addons/gf/extensions/save/",
		{
			"scan_roots": [directory + "\\"],
			"ignored_roots": [skip_dir + "\\", skip_dir, ""],
			"max_references_per_extension": 10,
		}
	)

	var _remove_keep_file_result: Variant = DirAccess.remove_absolute(ProjectSettings.globalize_path(keep_path))
	var _remove_skip_file_result: Variant = DirAccess.remove_absolute(ProjectSettings.globalize_path(skip_path))
	var _remove_keep_dir_result: Variant = DirAccess.remove_absolute(ProjectSettings.globalize_path(keep_dir))
	var _remove_skip_dir_result: Variant = DirAccess.remove_absolute(ProjectSettings.globalize_path(skip_dir))
	var _remove_directory_result: Variant = DirAccess.remove_absolute(ProjectSettings.globalize_path(directory))

	assert_eq(references.size(), 1, "审计扫描根和忽略根应统一斜杠、去重并跳过忽略目录。")
	assert_eq(
		GF_VARIANT_ACCESS.get_option_string(GF_VARIANT_ACCESS.as_dictionary(references[0]), "path"),
		keep_path,
		"未忽略目录中的引用应保留。"
	)


func test_extension_usage_audit_does_not_ignore_project_test_roots_by_default() -> void:
	var references: Array = GFExtensionUsageAudit.find_references_to_root(
		"res://addons/gf/extensions/save",
		{
			"scan_roots": ["res://tests/gf_core/fixtures/extension_usage_audit"],
			"max_references_per_extension": 10,
		}
	)

	assert_eq(references.size(), 1, "默认忽略列表不应把项目 tests/docs/tools 等目录当成框架内置细节。")
	assert_eq(
		GF_VARIANT_ACCESS.get_option_string(GF_VARIANT_ACCESS.as_dictionary(references[0]), "path"),
		"res://tests/gf_core/fixtures/extension_usage_audit/uses_save_in_project_tests.gd",
		"审计应能报告项目测试目录里的禁用扩展引用。"
	)


func test_extension_usage_audit_scans_project_specific_roots_by_default() -> void:
	var directory: String = "res://ai_analysis/tmp_extension_usage_audit"
	var path: String = directory.path_join("uses_save_in_ai_analysis.gd")
	var _make_dir_recursive_absolute_result: Variant = DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	_write_text_file(path, 'const SaveAI = preload("res://addons/gf/extensions/save/graph/gf_save_graph_utility.gd")')

	var references: Array = GFExtensionUsageAudit.find_references_to_root(
		"res://addons/gf/extensions/save",
		{
			"scan_roots": [directory],
			"max_references_per_extension": 10,
		}
	)

	_remove_path_if_exists(path)
	_remove_path_if_exists(directory)

	assert_eq(references.size(), 1, "通用审计不应隐式忽略项目自定义目录。")


func test_extension_usage_audit_respects_scanned_file_limit() -> void:
	var directory: String = "user://gf_extension_usage_audit_limit"
	var first_path: String = directory.path_join("uses_save_a.gd")
	var second_path: String = directory.path_join("uses_save_b.gd")
	var _make_dir_recursive_absolute_result_723: Variant = DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	_write_text_file(first_path, 'const SaveA = preload("res://addons/gf/extensions/save/graph/gf_save_graph_utility.gd")')
	_write_text_file(second_path, 'const SaveB = preload("res://addons/gf/extensions/save/slots/gf_save_slot_metadata.gd")')

	var report: Dictionary = GFExtensionUsageAudit.find_references_to_root_report(
		"res://addons/gf/extensions/save",
		{
			"scan_roots": [directory],
			"ignored_roots": [],
			"max_scanned_files": 1,
			"max_references_per_extension": 10,
		}
	)
	var references: Array = GF_VARIANT_ACCESS.get_option_array(report, "references")

	var _remove_absolute_result_737: Variant = DirAccess.remove_absolute(ProjectSettings.globalize_path(first_path))
	var _remove_absolute_result_738: Variant = DirAccess.remove_absolute(ProjectSettings.globalize_path(second_path))
	var _remove_absolute_result_739: Variant = DirAccess.remove_absolute(ProjectSettings.globalize_path(directory))

	assert_true(references.is_empty(), "共享文件预算被 class_name 预扫描耗尽后不得继续项目扫描。")
	assert_true(GF_VARIANT_ACCESS.get_option_bool(report, "partial_scan"), "共享文件预算耗尽必须标记 partial。")
	assert_true(GF_VARIANT_ACCESS.get_option_bool(report, "truncated"), "共享文件数量配额耗尽必须标记 truncated。")
	assert_push_warning(
		"[GFExtensionUsageAudit] 扩展 class_name 预扫描达到 max_scanned_files=1，后续扫描按 partial_scan 处理。"
	)


func test_extension_usage_audit_warns_when_scan_depth_limit_skips_directory() -> void:
	var directory: String = "user://gf_extension_usage_audit_depth"
	var shallow_directory: String = directory.path_join("a")
	var deep_directory: String = shallow_directory.path_join("b")
	var shallow_path: String = shallow_directory.path_join("shallow.gd")
	var deep_path: String = deep_directory.path_join("deep.gd")
	var _make_dir_recursive_absolute_result_746: Variant = DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(deep_directory))
	_write_text_file(shallow_path, "# shallow")
	_write_text_file(deep_path, 'const SaveB = preload("res://addons/gf/extensions/save/slots/gf_save_slot_metadata.gd")')

	var references: Array = GFExtensionUsageAudit.find_references_to_root(
		"res://addons/author_empty",
		{
			"scan_roots": [directory],
			"ignored_roots": [],
			"max_scan_depth": 1,
			"max_references_per_extension": 10,
		}
	)

	_remove_path_if_exists(deep_path)
	_remove_path_if_exists(shallow_path)
	_remove_path_if_exists(deep_directory)
	_remove_path_if_exists(shallow_directory)
	_remove_path_if_exists(directory)

	assert_true(references.is_empty(), "超过 max_scan_depth 的深层引用不应被扫描。")
	assert_push_warning("[GFExtensionUsageAudit] 已达到 max_scan_depth=1，已跳过更深目录：%s。" % deep_directory)


func test_extension_usage_audit_does_not_match_similar_prefix() -> void:
	var directory: String = "user://gf_extension_usage_audit"
	var path: String = directory.path_join("uses_save_extra.gd")
	var _make_dir_recursive_absolute_result_748: Variant = DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	var _store_string_result_750: Variant = file.store_string('const Other = preload("res://addons/gf/extensions/save_extra/example.gd")')
	file.close()

	var references: Array = GFExtensionUsageAudit.find_references_to_root(
		"res://addons/gf/extensions/save",
		{
			"scan_roots": [directory],
			"ignored_roots": [],
		}
	)

	var _remove_absolute_result_761: Variant = DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	var _remove_absolute_result_762: Variant = DirAccess.remove_absolute(ProjectSettings.globalize_path(directory))

	assert_true(references.is_empty(), "扩展根目录前缀相似但不在目录内时不应误报。")


func test_extension_usage_audit_finds_class_name_reference() -> void:
	var directory: String = "user://gf_extension_usage_audit"
	var path: String = directory.path_join("uses_save_class.gd")
	var _make_dir_recursive_absolute_result_770: Variant = DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	var _store_string_result_772: Variant = file.store_string("var save_graph: GFSaveGraphUtility = null")
	file.close()

	var references: Array = GFExtensionUsageAudit.find_references_to_root(
		"res://addons/gf/extensions/save",
		{
			"scan_roots": [directory],
			"ignored_roots": [],
		}
	)

	var _remove_absolute_result_783: Variant = DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	var _remove_absolute_result_784: Variant = DirAccess.remove_absolute(ProjectSettings.globalize_path(directory))

	assert_eq(references.size(), 1, "直接使用禁用扩展 class_name 时应被审计发现。")
	var reference: Dictionary = GF_VARIANT_ACCESS.as_dictionary(references[0])
	assert_eq(GF_VARIANT_ACCESS.get_option_string(reference, "kind"), "class_name", "审计结果应标记 class_name 引用。")
	assert_eq(GF_VARIANT_ACCESS.get_option_string(reference, "symbol"), "GFSaveGraphUtility", "审计结果应包含命中的类名。")
	assert_eq(GF_VARIANT_ACCESS.get_option_string(reference, "match"), "GFSaveGraphUtility", "审计 match 应包含命中的类名。")
	assert_false(GF_VARIANT_ACCESS.get_option_string(reference, "preview").contains("var save_graph"), "审计 preview 不应泄露源码片段。")


func test_extension_usage_audit_does_not_block_comments_or_plain_strings() -> void:
	var directory: String = "user://gf_extension_usage_audit_weak"
	var path: String = directory.path_join("weak_text.gd")
	var _make_dir_recursive_absolute_result: Variant = DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	_write_text_file(path, "\n".join([
		'# preload("res://addons/gf/extensions/save/graph/gf_save_graph_utility.gd")',
		'var path_text: String = "res://addons/gf/extensions/save/graph/gf_save_graph_utility.gd"',
		'var class_text: String = "GFSaveGraphUtility"',
	]))
	var manifest: GFExtensionManifest = GFExtensionManifest.from_dictionary({
		"id": "gf.extension.save",
		"display_name": "Save",
		"version": "1.0.0",
		"kind": "extension",
	}, "res://addons/gf/extensions/save", "")

	var blocking_references: Array = GFExtensionUsageAudit.find_references_to_root(
		"res://addons/gf/extensions/save",
		{
			"scan_roots": [directory],
			"ignored_roots": [],
			"max_references_per_extension": 10,
		}
	)
	var weak_references: Array = GFExtensionUsageAudit.find_references_to_root(
		"res://addons/gf/extensions/save",
		{
			"scan_roots": [directory],
			"ignored_roots": [],
			"include_weak_references": true,
			"max_references_per_extension": 10,
			"max_weak_references_per_extension": 10,
		}
	)
	var report: Dictionary = GFExtensionUsageAudit.audit_disabled_extensions([manifest], {
		"scan_roots": [directory],
		"ignored_roots": [],
		"max_references_per_extension": 10,
		"max_weak_references_per_extension": 10,
	})

	_remove_path_if_exists(path)
	_remove_path_if_exists(directory)

	assert_true(blocking_references.is_empty(), "注释和普通字符串不应作为禁用扩展阻断引用。")
	assert_eq(weak_references.size(), 2, "普通字符串路径和 class_name 只应作为弱引用提示。")
	assert_true(GF_VARIANT_ACCESS.get_option_bool(report, "ok"), "只有弱引用时审计不应失败。")
	assert_eq(GF_VARIANT_ACCESS.get_option_int(report, "reference_count"), 0, "阻断引用数量应排除弱文本命中。")
	assert_eq(GF_VARIANT_ACCESS.get_option_int(report, "weak_reference_count"), 2, "弱引用应单独计数。")


func test_extension_usage_audit_exposes_partial_budget_report() -> void:
	var directory: String = "user://gf_extension_usage_audit_budget"
	var path: String = directory.path_join("large_reference.gd")
	var _make_dir_recursive_absolute_result: Variant = DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	_write_text_file(path, 'const First = preload("res://addons/author/first/runtime/tool.gd")')
	var manifest: GFExtensionManifest = GFExtensionManifest.from_dictionary({
		"id": "author.first",
		"display_name": "First",
		"version": "1.0.0",
		"kind": "extension",
	}, "res://addons/author/first", "")

	var report: Dictionary = GFExtensionUsageAudit.audit_disabled_extensions([manifest], {
		"scan_roots": [directory],
		"ignored_roots": [],
		"max_file_bytes": 16,
	})

	_remove_path_if_exists(path)
	_remove_path_if_exists(directory)

	assert_false(GF_VARIANT_ACCESS.get_option_bool(report, "ok"), "不完整扫描不能报告为 ok。")
	assert_true(GF_VARIANT_ACCESS.get_option_bool(report, "partial_scan"), "预算耗尽应透出 partial_scan。")
	assert_true(GF_VARIANT_ACCESS.get_option_bool(report, "budget_exceeded"), "预算耗尽应透出 budget_exceeded。")
	assert_eq(GF_VARIANT_ACCESS.get_option_int(report, "reference_count"), 0, "未读取文件不应产生阻断引用。")
	assert_eq(GF_VARIANT_ACCESS.get_option_array(report, "skipped_files").size(), 1, "预算跳过文件应进入审计报告。")
	assert_push_warning("[GFExtensionUsageAudit] 引用扫描达到 max_file_bytes=16 字节预算，后续结果按 partial_scan 处理：%s。" % path)


func test_extension_usage_audit_bounds_class_name_pre_scan_file_bytes() -> void:
	var extension_root: String = "res://tests/gf_core/tmp_extension_class_file_budget"
	var extension_path: String = extension_root.path_join("type.gd")
	var project_root: String = "user://gf_extension_class_file_budget"
	var project_path: String = project_root.path_join("uses_type.gd")
	_remove_path_if_exists(extension_path)
	_remove_path_if_exists(extension_root)
	_remove_path_if_exists(project_path)
	_remove_path_if_exists(project_root)
	var _make_extension_dir: Error = DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path(extension_root)
	)
	var _make_project_dir: Error = DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path(project_root)
	)
	var extension_source: String = "class_name AuditBudgetType\nextends RefCounted\n"
	_write_text_file(extension_path, extension_source)
	_write_text_file(project_path, "var value: AuditBudgetType")
	var max_file_bytes: int = extension_source.to_utf8_buffer().size() - 1

	var report: Dictionary = GFExtensionUsageAudit.find_references_to_root_report(
		extension_root,
		{
			"scan_roots": [project_root],
			"ignored_roots": [],
			"max_file_bytes": max_file_bytes,
		}
	)
	var class_name_scan: Dictionary = GF_VARIANT_ACCESS.get_option_dictionary(
		report,
		"class_name_scan"
	)
	var skipped_files: Array = GF_VARIANT_ACCESS.get_option_array(report, "skipped_files")
	var has_class_name_skip: bool = false
	for skipped_value: Variant in skipped_files:
		if not skipped_value is Dictionary:
			continue
		var skipped_file: Dictionary = skipped_value
		if (
			GF_VARIANT_ACCESS.get_option_string(skipped_file, "path") == extension_path
			and GF_VARIANT_ACCESS.get_option_string(skipped_file, "phase") == "class_name_pre_scan"
		):
			has_class_name_skip = true
			break

	_remove_path_if_exists(extension_path)
	_remove_path_if_exists(extension_root)
	_remove_path_if_exists(project_path)
	_remove_path_if_exists(project_root)

	assert_false(GF_VARIANT_ACCESS.get_option_bool(report, "ok"), "class_name 预扫描不完整时不能报告安全。")
	assert_true(GF_VARIANT_ACCESS.get_option_bool(report, "partial_scan"), "预扫描超限必须传播 partial。")
	assert_true(GF_VARIANT_ACCESS.get_option_bool(report, "budget_exceeded"), "预扫描超限必须传播 budget。")
	assert_true(
		GF_VARIANT_ACCESS.get_option_bool(class_name_scan, "partial_scan"),
		"class_name_scan 子报告必须独立可观察。"
	)
	assert_true(has_class_name_skip, "被预算拒绝的扩展脚本必须带 phase 进入 skipped_files。")
	assert_push_warning(
		"[GFExtensionUsageAudit] 扩展 class_name 预扫描达到 max_file_bytes=%d 字节预算，结果按 partial_scan 处理：%s。"
		% [max_file_bytes, extension_path]
	)


func test_extension_usage_audit_propagates_class_name_depth_truncation() -> void:
	var extension_root: String = "res://tests/gf_core/tmp_extension_class_depth"
	var shallow_root: String = extension_root.path_join("a")
	var deep_root: String = shallow_root.path_join("b")
	var extension_path: String = deep_root.path_join("type.gd")
	var project_root: String = "user://gf_extension_class_depth"
	var project_path: String = project_root.path_join("uses_type.gd")
	_remove_path_if_exists(extension_path)
	_remove_path_if_exists(deep_root)
	_remove_path_if_exists(shallow_root)
	_remove_path_if_exists(extension_root)
	_remove_path_if_exists(project_path)
	_remove_path_if_exists(project_root)
	var _make_extension_dir: Error = DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path(deep_root)
	)
	var _make_project_dir: Error = DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path(project_root)
	)
	_write_text_file(extension_path, "class_name AuditDeepType\nextends RefCounted\n")
	_write_text_file(project_path, "var value: AuditDeepType")

	var report: Dictionary = GFExtensionUsageAudit.find_references_to_root_report(
		extension_root,
		{
			"scan_roots": [project_root],
			"ignored_roots": [],
			"max_scan_depth": 1,
		}
	)
	var has_class_name_depth_issue: bool = false
	for issue_value: Variant in GF_VARIANT_ACCESS.get_option_array(report, "issues"):
		if not issue_value is Dictionary:
			continue
		var issue: Dictionary = issue_value
		if (
			GF_VARIANT_ACCESS.get_option_string(issue, "code") == "max_scan_depth"
			and GF_VARIANT_ACCESS.get_option_string(issue, "phase") == "class_name_pre_scan"
		):
			has_class_name_depth_issue = true
			break

	_remove_path_if_exists(extension_path)
	_remove_path_if_exists(deep_root)
	_remove_path_if_exists(shallow_root)
	_remove_path_if_exists(extension_root)
	_remove_path_if_exists(project_path)
	_remove_path_if_exists(project_root)

	assert_false(GF_VARIANT_ACCESS.get_option_bool(report, "ok"), "深度截断时不能报告安全。")
	assert_true(GF_VARIANT_ACCESS.get_option_bool(report, "partial_scan"), "class-name 深度截断必须传播。")
	assert_true(has_class_name_depth_issue, "深度截断必须形成结构化 phase issue。")
	assert_push_warning(
		"[GFExtensionUsageAudit] 扩展 class_name 预扫描达到 max_scan_depth=1，已跳过更深目录：%s。"
		% deep_root
	)


func test_extension_usage_audit_shares_total_bytes_across_both_phases() -> void:
	var extension_root: String = "res://tests/gf_core/tmp_extension_class_total"
	var extension_path: String = extension_root.path_join("type.gd")
	var project_root: String = "user://gf_extension_class_total"
	var project_path: String = project_root.path_join("uses_type.gd")
	_remove_path_if_exists(extension_path)
	_remove_path_if_exists(extension_root)
	_remove_path_if_exists(project_path)
	_remove_path_if_exists(project_root)
	var _make_extension_dir: Error = DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path(extension_root)
	)
	var _make_project_dir: Error = DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path(project_root)
	)
	var extension_source: String = "class_name AuditTotalType\nextends RefCounted\n"
	var project_source: String = "var value: AuditTotalType"
	_write_text_file(extension_path, extension_source)
	_write_text_file(project_path, project_source)
	var extension_bytes: int = extension_source.to_utf8_buffer().size()
	var project_bytes: int = project_source.to_utf8_buffer().size()
	var max_total_bytes: int = extension_bytes + project_bytes - 1
	var project_remaining_bytes: int = max_total_bytes - extension_bytes

	var report: Dictionary = GFExtensionUsageAudit.find_references_to_root_report(
		extension_root,
		{
			"scan_roots": [project_root],
			"ignored_roots": [],
			"max_total_bytes": max_total_bytes,
		}
	)

	_remove_path_if_exists(extension_path)
	_remove_path_if_exists(extension_root)
	_remove_path_if_exists(project_path)
	_remove_path_if_exists(project_root)

	assert_false(GF_VARIANT_ACCESS.get_option_bool(report, "ok"), "组合读取超出总预算时不能报告安全。")
	assert_true(GF_VARIANT_ACCESS.get_option_bool(report, "partial_scan"), "组合总预算耗尽必须传播 partial。")
	assert_true(GF_VARIANT_ACCESS.get_option_bool(report, "budget_exceeded"), "组合总预算耗尽必须传播 budget。")
	assert_lte(
		GF_VARIANT_ACCESS.get_option_int(report, "scanned_bytes"),
		max_total_bytes,
		"两个阶段的实际读取总量不得突破公开总预算。"
	)
	assert_push_warning(
		"[GFExtensionUsageAudit] 引用扫描达到 max_total_bytes=%d 字节预算，后续结果按 partial_scan 处理：%s。"
		% [project_remaining_bytes, project_path]
	)


func test_extension_usage_audit_finds_resource_text_dependency_reference() -> void:
	var directory: String = "user://gf_extension_usage_audit_resource_text"
	var path: String = directory.path_join("uses_save_scene.tscn")
	var _make_dir_recursive_absolute_result: Variant = DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	_write_text_file(path, "\n".join([
		"[gd_scene load_steps=2 format=3]",
		'[ext_resource type="Script" path="res://addons/gf/extensions/save/graph/gf_save_graph_utility.gd" id="1"]',
		'[node name="Root" type="Node"]',
		'script = ExtResource("1")',
	]))

	var references: Array = GFExtensionUsageAudit.find_references_to_root(
		"res://addons/gf/extensions/save",
		{
			"scan_roots": [directory],
			"ignored_roots": [],
			"max_references_per_extension": 10,
			"use_resource_dependencies": false,
		}
	)

	_remove_path_if_exists(path)
	_remove_path_if_exists(directory)

	assert_eq(references.size(), 1, "文本资源中的 ExtResource path 应作为强引用。")
	var reference: Dictionary = GF_VARIANT_ACCESS.as_dictionary(references[0])
	assert_eq(GF_VARIANT_ACCESS.get_option_string_name(reference, "strength"), GFExtensionUsageAudit.REFERENCE_STRENGTH_STRONG, "资源文本依赖应是 strong。")
	assert_eq(GF_VARIANT_ACCESS.get_option_string_name(reference, "source"), GFExtensionUsageAudit.REFERENCE_SOURCE_RESOURCE_TEXT, "资源文本依赖应记录来源。")


func test_extension_usage_audit_promotes_godot_dependency_graph_reference_when_available() -> void:
	var directory: String = "res://tests/gf_core/tmp_extension_usage_audit_dependencies"
	var path: String = directory.path_join("uses_save_scene.tscn")
	_remove_path_if_exists(path)
	_remove_path_if_exists(path + ".uid")
	_remove_path_if_exists(directory)
	var _make_dir_recursive_absolute_result: Variant = DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	_write_text_file(path, "\n".join([
		"[gd_scene load_steps=2 format=3]",
		'[ext_resource type="Script" path="res://addons/gf/extensions/save/graph/gf_save_graph_utility.gd" id="1"]',
		'[node name="Root" type="Node"]',
		'script = ExtResource("1")',
	]))
	var dependency_available: bool = false
	for dependency_entry: String in ResourceLoader.get_dependencies(path):
		if dependency_entry.contains("res://addons/gf/extensions/save"):
			dependency_available = true
			break

	var references: Array = GFExtensionUsageAudit.find_references_to_root(
		"res://addons/gf/extensions/save",
		{
			"scan_roots": [directory],
			"ignored_roots": [],
			"max_references_per_extension": 10,
		}
	)

	_remove_path_if_exists(path)
	_remove_path_if_exists(path + ".uid")
	_remove_path_if_exists(directory)

	assert_eq(references.size(), 1, "资源依赖应被审计发现。")
	var reference: Dictionary = GF_VARIANT_ACCESS.as_dictionary(references[0])
	if dependency_available:
		assert_eq(GF_VARIANT_ACCESS.get_option_string_name(reference, "strength"), GFExtensionUsageAudit.REFERENCE_STRENGTH_VERIFIED, "Godot 依赖图可用时应提升为 verified。")
		assert_eq(GF_VARIANT_ACCESS.get_option_string_name(reference, "source"), GFExtensionUsageAudit.REFERENCE_SOURCE_GODOT_DEPENDENCY, "verified 引用应记录 Godot 依赖图来源。")
	else:
		assert_eq(GF_VARIANT_ACCESS.get_option_string_name(reference, "strength"), GFExtensionUsageAudit.REFERENCE_STRENGTH_STRONG, "依赖图不可用时应保留静态 strong 引用。")


func test_extension_usage_audit_finds_binary_resource_dependency_reference() -> void:
	var directory: String = "res://tests/gf_core/tmp_extension_usage_audit_binary_dependency"
	var path: String = directory.path_join("uses_save.res")
	_remove_path_if_exists(path)
	_remove_path_if_exists(directory)
	var _make_dir_recursive_absolute_result: Variant = DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path(directory)
	)
	var consumer: BinaryReferenceResource = BinaryReferenceResource.new()
	consumer.dependency = ResourceLoader.load(
		"res://addons/gf/extensions/save/graph/gf_save_graph_utility.gd"
	)
	assert_not_null(consumer.dependency, "测试应能加载扩展脚本资源。")
	assert_eq(ResourceSaver.save(consumer, path), OK, "测试应能保存二进制扩展引用资源。")

	var references: Array = GFExtensionUsageAudit.find_references_to_root(
		"res://addons/gf/extensions/save",
		{
			"scan_roots": [directory],
			"ignored_roots": [],
			"max_references_per_extension": 10,
		}
	)
	consumer.dependency = null
	_remove_path_if_exists(path)
	_remove_path_if_exists(directory)

	assert_eq(references.size(), 1, "二进制资源依赖应被扩展审计发现。")
	if references.size() == 1:
		var reference: Dictionary = GF_VARIANT_ACCESS.as_dictionary(references[0])
		assert_eq(GF_VARIANT_ACCESS.get_option_string_name(reference, "strength"), GFExtensionUsageAudit.REFERENCE_STRENGTH_VERIFIED, "二进制扩展引用应由 Godot 依赖图验证。")
		assert_eq(GF_VARIANT_ACCESS.get_option_string_name(reference, "source"), GFExtensionUsageAudit.REFERENCE_SOURCE_GODOT_DEPENDENCY, "二进制扩展引用应记录依赖图来源。")


func test_extension_usage_audit_reports_multiple_disabled_roots_from_one_scan() -> void:
	var directory: String = "user://gf_extension_usage_audit_multi"
	var first_path: String = directory.path_join("uses_first.gd")
	var second_path: String = directory.path_join("uses_second.gd")
	var _make_directory_result: Error = DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	_write_text_file(first_path, 'const First = preload("res://addons/author/first/runtime/tool.gd")')
	_write_text_file(second_path, 'const Second = preload("res://addons/author/second/runtime/tool.gd")')
	var first_manifest: GFExtensionManifest = GFExtensionManifest.from_dictionary({
		"id": "author.first",
		"display_name": "First",
		"version": "1.0.0",
		"kind": "extension",
		"dependencies": [],
	}, "res://addons/author/first", "")
	var second_manifest: GFExtensionManifest = GFExtensionManifest.from_dictionary({
		"id": "author.second",
		"display_name": "Second",
		"version": "1.0.0",
		"kind": "extension",
		"dependencies": [],
	}, "res://addons/author/second", "")
	var disabled_manifests: Array[GFExtensionManifest] = [first_manifest, second_manifest]

	var report: Dictionary = GFExtensionUsageAudit.audit_disabled_extensions(
		disabled_manifests,
		{
			"scan_roots": [directory],
			"ignored_roots": [],
			"max_references_per_extension": 10,
		}
	)

	_remove_path_if_exists(first_path)
	_remove_path_if_exists(second_path)
	_remove_path_if_exists(directory)

	var extensions: Dictionary = GF_VARIANT_ACCESS.get_option_dictionary(report, "extensions")
	assert_false(GF_VARIANT_ACCESS.get_option_bool(report, "ok"), "多个禁用扩展被引用时审计应失败。")
	assert_eq(GF_VARIANT_ACCESS.get_option_int(report, "extension_count"), 2, "审计应同时报告两个被引用扩展。")
	assert_eq(GF_VARIANT_ACCESS.get_option_int(report, "reference_count"), 2, "审计应保留两个扩展各自的引用。")
	assert_true(extensions.has(&"author.first"), "报告应包含第一个禁用扩展。")
	assert_true(extensions.has(&"author.second"), "报告应包含第二个禁用扩展。")


func test_extension_usage_audit_ignores_all_disabled_roots_during_project_scan() -> void:
	var root_path: String = "res://tests/gf_core/tmp_disabled_extension_usage_scan"
	var first_root: String = root_path.path_join("first")
	var second_root: String = root_path.path_join("second")
	var first_reference_path: String = first_root.path_join("uses_second.gd")
	_remove_path_if_exists(first_reference_path)
	_remove_path_if_exists(first_root)
	_remove_path_if_exists(second_root)
	_remove_path_if_exists(root_path)
	var _make_first_root_result: Variant = DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(first_root))
	var _make_second_root_result: Variant = DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(second_root))
	_write_text_file(first_reference_path, 'const Second = preload("%s")' % second_root.path_join("runtime/tool.gd"))
	var first_manifest: GFExtensionManifest = GFExtensionManifest.from_dictionary({
		"id": "author.first",
		"display_name": "First",
		"version": "1.0.0",
		"kind": "extension",
	}, first_root, "")
	var second_manifest: GFExtensionManifest = GFExtensionManifest.from_dictionary({
		"id": "author.second",
		"display_name": "Second",
		"version": "1.0.0",
		"kind": "extension",
	}, second_root, "")

	var report: Dictionary = GFExtensionUsageAudit.audit_disabled_extensions(
		[first_manifest, second_manifest],
		{
			"scan_roots": [root_path],
			"ignored_roots": [],
			"max_references_per_extension": 10,
		}
	)

	_remove_path_if_exists(first_reference_path)
	_remove_path_if_exists(first_root)
	_remove_path_if_exists(second_root)
	_remove_path_if_exists(root_path)

	assert_true(GF_VARIANT_ACCESS.get_option_bool(report, "ok"), "禁用扩展根目录内部的互相引用不应被项目扫描报告。")
	assert_eq(GF_VARIANT_ACCESS.get_option_int(report, "reference_count"), 0, "禁用根目录内部文件应整体跳过。")


# --- 私有/辅助方法 ---

func _collect_gd_files(root_path: String, result: Array[String]) -> void:
	var dir: DirAccess = DirAccess.open(root_path)
	if dir == null:
		return

	var _list_dir_begin_result_799: Variant = dir.list_dir_begin()
	var entry: String = dir.get_next()
	while not entry.is_empty():
		var path: String = root_path.path_join(entry)
		if dir.current_is_dir():
			if not entry.begins_with("."):
				_collect_gd_files(path, result)
		elif entry.ends_with(".gd"):
			result.append(path)
		entry = dir.get_next()
	dir.list_dir_end()


func _read_text(path: String) -> String:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	var text: String = file.get_as_text()
	file.close()
	return text


func _manifest_array_contains_id(manifests: Array, extension_id: String) -> bool:
	for manifest_value: Variant in manifests:
		if not (manifest_value is GFExtensionManifest):
			continue
		var manifest: GFExtensionManifest = manifest_value
		if manifest.id == extension_id:
			return true
	return false


func _string_array_contains(values: Array[String], needle: String) -> bool:
	for value: String in values:
		if value.contains(needle):
			return true
	return false


func _preset_issue_contains(issues: Array, preset_id: String, needle: String) -> bool:
	for issue_value: Variant in issues:
		if not (issue_value is Dictionary):
			continue
		var issue: Dictionary = issue_value
		if GF_VARIANT_ACCESS.get_option_string(issue, "id") != preset_id:
			continue
		for error: String in GF_VARIANT_ACCESS.get_option_string_array(issue, "errors"):
			if error.contains(needle):
				return true
	return false


func _write_text_file(path: String, text: String) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	assert_not_null(file, "测试应能创建临时文本文件。")
	if file == null:
		return
	var _store_string_result_826: Variant = file.store_string(text)
	file.close()


func _remove_path_if_exists(path: String) -> void:
	var absolute_path: String = ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(absolute_path) or DirAccess.dir_exists_absolute(absolute_path):
		var _remove_absolute_result: Variant = DirAccess.remove_absolute(absolute_path)


func _cleanup_extension_root_fixture(root_path: String, extension_dir: String, manifest_path: String) -> void:
	_remove_path_if_exists(manifest_path)
	_remove_path_if_exists(extension_dir)
	_remove_path_if_exists(root_path)


func _get_extension_root(path: String) -> String:
	var marker: String = EXTENSION_ROOT + "/"
	if not path.begins_with(marker):
		return ""

	var slash_index: int = path.find("/", marker.length())
	if slash_index == -1:
		return ""
	return path.substr(0, slash_index)


func _extract_extension_roots(source: String) -> Array[String]:
	var roots: Array[String] = []
	var marker: String = EXTENSION_ROOT + "/"
	var search_from: int = 0
	while search_from < source.length():
		var start_index: int = source.find(marker, search_from)
		if start_index == -1:
			break

		var slash_index: int = source.find("/", start_index + marker.length())
		if slash_index == -1:
			break

		var root: String = source.substr(start_index, slash_index - start_index)
		if not roots.has(root):
			roots.append(root)
		search_from = slash_index + 1
	return roots


func _collect_extension_class_roots() -> Dictionary:
	var files: Array[String] = []
	_collect_gd_files(EXTENSION_ROOT, files)

	var result: Dictionary = {}
	var regex: RegEx = RegEx.new()
	var _compile_result_867: Variant = regex.compile("^\\s*class_name\\s+([A-Za-z_]\\w*)")
	for path: String in files:
		var extension_root: String = _get_extension_root(path)
		for line: String in _read_text(path).split("\n"):
			var match_result: RegExMatch = regex.search(line)
			if match_result == null:
				continue

			result[match_result.get_string(1)] = extension_root
	return result


func _extension_root_can_reference(extension_root: String, referenced_root: String) -> bool:
	return referenced_root.is_empty() or referenced_root == extension_root


func _source_contains_identifier(source: String, identifier: String) -> bool:
	var regex: RegEx = RegEx.new()
	var error: Error = regex.compile("(^|[^A-Za-z0-9_])%s([^A-Za-z0-9_]|$)" % identifier)
	if error != OK:
		return source.contains(identifier)
	return regex.search(source) != null


func _set_project_setting(setting_name: String, value: Variant) -> Dictionary:
	var restore: Dictionary = {
		"had_setting": ProjectSettings.has_setting(setting_name),
		"value": ProjectSettings.get_setting(setting_name, null),
	}
	if setting_name == GFExtensionSettings.ENABLED_EXTENSIONS_SETTING:
		restore["selection_mode_had_setting"] = ProjectSettings.has_setting(
			GFExtensionSettings.EXTENSION_SELECTION_MODE_SETTING
		)
		restore["selection_mode_value"] = ProjectSettings.get_setting(
			GFExtensionSettings.EXTENSION_SELECTION_MODE_SETTING,
			null
		)
	ProjectSettings.set_setting(setting_name, value)
	if setting_name == GFExtensionSettings.ENABLED_EXTENSIONS_SETTING:
		ProjectSettings.set_setting(
			GFExtensionSettings.EXTENSION_SELECTION_MODE_SETTING,
			GFExtensionSettings.SELECTION_MODE_EXPLICIT
		)
	return restore


func _restore_project_setting(setting_name: String, restore: Dictionary) -> void:
	if GF_VARIANT_ACCESS.get_option_bool(restore, "had_setting"):
		ProjectSettings.set_setting(setting_name, GF_VARIANT_ACCESS.get_option_value(restore, "value"))
	else:
		ProjectSettings.clear(setting_name)
	if setting_name != GFExtensionSettings.ENABLED_EXTENSIONS_SETTING:
		return

	if GF_VARIANT_ACCESS.get_option_bool(restore, "selection_mode_had_setting"):
		ProjectSettings.set_setting(
			GFExtensionSettings.EXTENSION_SELECTION_MODE_SETTING,
			GF_VARIANT_ACCESS.get_option_value(restore, "selection_mode_value")
		)
	else:
		ProjectSettings.clear(GFExtensionSettings.EXTENSION_SELECTION_MODE_SETTING)


func _read_framework_version() -> String:
	var config: ConfigFile = ConfigFile.new()
	var error: Error = config.load("res://addons/gf/plugin.cfg")
	if error != OK:
		return ""
	return GF_VARIANT_ACCESS.to_text(config.get_value("plugin", "version", ""))


func _read_json_dictionary(path: String) -> Dictionary:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
		return parsed
	return {}


func _is_semver(version: String) -> bool:
	var regex: RegEx = RegEx.new()
	var _compile_result_927: Variant = regex.compile("^\\d+\\.\\d+\\.\\d+$")
	return regex.search(version) != null
