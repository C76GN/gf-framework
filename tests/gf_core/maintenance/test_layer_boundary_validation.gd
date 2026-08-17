## 验证 GF 核心层级依赖边界。
extends GutTest


# --- 常量 ---

const KERNEL_ROOT: String = "res://addons/gf/kernel"
const KERNEL_EDITOR_ROOT: String = "res://addons/gf/kernel/editor"
const STANDARD_ROOT: String = "res://addons/gf/standard"
const EXTENSIONS_ROOT: String = "res://addons/gf/extensions"
const PACKAGE_ROOT: String = "res://packages"
const KERNEL_FORBIDDEN_TEXTS: Array[String] = [
	"res://addons/gf/standard",
	"addons/gf/standard",
	"GFTimeUtility",
	"GFCommandHistoryUtility",
	"GFStandardEditorExtensionsBase",
	"GFValidationIssue",
	"GFValidationReport",
	"GFValidationReportDictionary",
	"GFResultDictionary",
	"GFCapability",
	"GFNodeCapability",
	"GFNode2DCapability",
	"GFNode3DCapability",
	"GFControlCapability",
	"GFNodeState",
	"GFNodeStateMachine",
]
const STANDARD_FORBIDDEN_EXTENSION_PATHS: Array[String] = [
	"res://addons/gf/extensions/",
	"addons/gf/extensions/",
]
const KERNEL_EXTENSION_INFRASTRUCTURE_PATHS: Array[String] = [
	"res://addons/gf/kernel/extension/gf_extension_catalog.gd",
	"res://addons/gf/kernel/extension/gf_extension_usage_audit.gd",
]
const EXTENSION_ALLOWED_DEPENDENCIES: Array[String] = [
	"gf.kernel",
	"gf.standard",
]
const EXTENSION_ALLOWED_MANIFEST_FIELDS: Array[String] = [
	"dependencies",
	"description",
	"display_name",
	"editor_dock_order",
	"editor_dock_short_label",
	"enabled_by_default",
	"extension_version",
	"id",
	"installer_paths",
	"kind",
	"tags",
	"version",
]
const EXTENSION_FORBIDDEN_MANIFEST_FIELDS: Array[String] = [
	"after",
	"before",
	"bundle",
	"bundles",
	"conflicts",
	"extension_dependencies",
	"extension_pack",
	"extension_preset",
	"integrates_with",
	"load_after",
	"load_before",
	"optional_dependencies",
	"peer_dependencies",
	"preset",
	"presets",
	"recommends",
	"soft_dependencies",
	"suggests",
]
const EXTENSION_FORBIDDEN_SOFT_REFERENCES: Dictionary = {
	"interaction": [
		"capability_provider",
		"with_capability_provider",
		"get_capability(",
		"get_receivers_in_group",
		"sender_as",
		"target_as",
		"GFCapability",
	],
	"feedback": [
		"GFShakeAction",
		"GFActionQueueSystem",
		"GFVisualAction",
		"ActionQueue",
		"action_queue",
		"should_wait_for_result",
	],
}
const BUSINESS_EXTENSION_CANDIDATES: Array[String] = [
	"combat",
	"domain",
]
const EXTENSION_FORBIDDEN_INTERNAL_TAGS: Array[String] = [
	"externalization-candidate",
]
const GF_VARIANT_ACCESS = preload("res://addons/gf/kernel/core/gf_variant_access.gd")


# --- 测试用例 ---

func test_kernel_does_not_depend_on_standard_layer() -> void:
	var files: Array[String] = []
	_collect_gd_files(KERNEL_ROOT, files)

	var issues: Array[String] = []
	for path: String in files:
		var source: String = _read_text(path)
		for forbidden_text: String in KERNEL_FORBIDDEN_TEXTS:
			if source.contains(forbidden_text):
				issues.append("%s contains %s" % [path, forbidden_text])

	assert_eq(
		issues,
		[],
		"`addons/gf/kernel` 不能直接依赖 `addons/gf/standard`；需要内核识别的契约必须放在 kernel。"
	)


func test_only_kernel_extension_infrastructure_knows_extension_root_path() -> void:
	var files: Array[String] = []
	_collect_gd_files(KERNEL_ROOT, files)

	var issues: Array[String] = []
	for path: String in files:
		if KERNEL_EXTENSION_INFRASTRUCTURE_PATHS.has(path):
			continue
		var source: String = _read_text(path)
		for forbidden_path: String in STANDARD_FORBIDDEN_EXTENSION_PATHS:
			if source.contains(forbidden_path):
				issues.append("%s contains %s" % [path, forbidden_path])

	assert_eq(
		issues,
		[],
		"只有 kernel extension infrastructure 可以识别 `addons/gf/extensions` 根路径；其他 kernel 代码不能硬编码可选扩展路径。"
	)


func test_kernel_does_not_reference_standard_or_extension_classes() -> void:
	var files: Array[String] = []
	_collect_gd_files(KERNEL_ROOT, files)
	var forbidden_class_names: Array[String] = _collect_class_names(STANDARD_ROOT)
	forbidden_class_names.append_array(_collect_class_names(EXTENSIONS_ROOT))

	var issues: Array[String] = _collect_forbidden_class_reference_issues(files, forbidden_class_names)

	assert_eq(
		issues,
		[],
		"`addons/gf/kernel` 不能直接引用 standard 或可选扩展的具体 class_name；需要共享的最小契约必须上移到 kernel。"
	)


func test_kernel_editor_does_not_hardcode_extension_ids() -> void:
	var files: Array[String] = []
	_collect_gd_files(KERNEL_EDITOR_ROOT, files)
	var extension_ids: Array[String] = _collect_extension_ids()

	var issues: Array[String] = []
	for path: String in files:
		var source: String = _read_text(path)
		for extension_id: String in extension_ids:
			if source.contains(extension_id):
				issues.append("%s contains %s" % [path, extension_id])

	assert_eq(
		issues,
		[],
		"`addons/gf/kernel/editor` 不能硬编码可选扩展 ID；扩展级编辑器能力应由 manifest 注入。"
	)


func test_kernel_does_not_hardcode_extension_ids() -> void:
	var files: Array[String] = []
	_collect_gd_files(KERNEL_ROOT, files)
	var extension_ids: Array[String] = _collect_extension_ids()

	var issues: Array[String] = []
	for path: String in files:
		var source: String = _read_text(path)
		for extension_id: String in extension_ids:
			if source.contains(extension_id):
				issues.append("%s contains %s" % [path, extension_id])

	assert_eq(
		issues,
		[],
		"`addons/gf/kernel` 不能硬编码可选扩展 ID；扩展能力必须由扩展侧通过 manifest 或通用扩展点贡献。"
	)


func test_standard_does_not_hard_depend_on_extension_paths_or_classes() -> void:
	var files: Array[String] = []
	_collect_gd_files(STANDARD_ROOT, files)
	var extension_class_names: Array[String] = _collect_class_names(EXTENSIONS_ROOT)

	var issues: Array[String] = []
	for path: String in files:
		var source: String = _read_text(path)
		for forbidden_path: String in STANDARD_FORBIDDEN_EXTENSION_PATHS:
			if source.contains(forbidden_path):
				issues.append("%s contains %s" % [path, forbidden_path])
		for extension_class_name: String in extension_class_names:
			if _contains_identifier(source, extension_class_name):
				issues.append("%s references extension class %s" % [path, extension_class_name])

	assert_eq(
		issues,
		[],
		"`addons/gf/standard` 不能硬 preload、硬路径引用或直接类型引用可选扩展；需要联动时由扩展侧向 standard 的通用注册入口贡献能力。"
	)


func test_standard_does_not_reference_extension_ids() -> void:
	var files: Array[String] = []
	_collect_gd_files(STANDARD_ROOT, files)
	var extension_ids: Array[String] = _collect_extension_ids()

	var issues: Array[String] = []
	for path: String in files:
		var source: String = _read_text(path)
		for extension_id: String in extension_ids:
			if source.contains(extension_id):
				issues.append("%s contains %s" % [path, extension_id])

	assert_eq(
		issues,
		[],
		"`standard` 不能按扩展 ID 主动探测可选扩展；可选扩展联动必须由扩展侧注册贡献。"
	)


func test_bundled_extension_manifests_are_atomic() -> void:
	var extension_names: Array[String] = _collect_immediate_directory_names(EXTENSIONS_ROOT)
	var manifest_by_extension_name: Dictionary = _collect_manifest_by_extension_name(extension_names)
	var issues: Array[String] = []
	for extension_name: String in extension_names:
		var manifest_data: Dictionary = GF_VARIANT_ACCESS.get_option_dictionary(
			manifest_by_extension_name,
			extension_name,
			{}
		)
		if manifest_data.is_empty():
			issues.append("%s missing manifest" % extension_name)
			continue

		if not manifest_data.has("extension_version"):
			issues.append("%s missing extension_version" % extension_name)
		if GF_VARIANT_ACCESS.get_option_string(manifest_data, "kind") != "extension":
			issues.append("%s must declare kind=extension" % extension_name)
		if not manifest_data.has("enabled_by_default"):
			issues.append("%s missing enabled_by_default" % extension_name)
		elif GF_VARIANT_ACCESS.get_option_bool(manifest_data, "enabled_by_default", true):
			issues.append("%s must declare enabled_by_default=false" % extension_name)
		for field_name_variant: Variant in manifest_data.keys():
			var field_name: String = GF_VARIANT_ACCESS.to_text(field_name_variant)
			if not EXTENSION_ALLOWED_MANIFEST_FIELDS.has(field_name):
				issues.append("%s declares unsupported manifest field %s" % [extension_name, field_name])

		var dependencies: Array = GF_VARIANT_ACCESS.get_option_array(manifest_data, "dependencies", [])
		for dependency_variant: Variant in dependencies:
			var dependency_id: String = GF_VARIANT_ACCESS.to_text(dependency_variant)
			if not EXTENSION_ALLOWED_DEPENDENCIES.has(dependency_id):
				issues.append("%s declares dependency %s" % [extension_name, dependency_id])

		for field_name: String in EXTENSION_FORBIDDEN_MANIFEST_FIELDS:
			if manifest_data.has(field_name):
				issues.append("%s declares unsupported manifest field %s" % [extension_name, field_name])

	assert_eq(
		issues,
		[],
		"GF 内置扩展必须保持原子化：只能依赖 gf.kernel 与 gf.standard，不能声明其他内置扩展硬依赖或软协作字段；组合属于项目或外部插件。"
	)


func test_bundled_extensions_do_not_reference_other_bundled_extensions() -> void:
	var extension_names: Array[String] = _collect_immediate_directory_names(EXTENSIONS_ROOT)
	var class_root_by_name: Dictionary = _collect_extension_class_root_by_name()
	var issues: Array[String] = []
	for extension_name: String in extension_names:
		var extension_root: String = EXTENSIONS_ROOT.path_join(extension_name)
		var files: Array[String] = []
		_collect_gd_files(extension_root, files)
		for path: String in files:
			var source: String = _read_text(path)
			for other_extension_name: String in extension_names:
				if other_extension_name == extension_name:
					continue
				var other_extension_path: String = "addons/gf/extensions/%s" % other_extension_name
				var other_extension_id: String = "gf.%s" % other_extension_name
				if source.contains(other_extension_path):
					issues.append("%s references %s" % [path, other_extension_path])
				if source.contains(other_extension_id):
					issues.append("%s references %s" % [path, other_extension_id])
			for class_name_variant: Variant in class_root_by_name.keys():
				var class_name_text: String = GF_VARIANT_ACCESS.to_text(class_name_variant)
				var class_root: String = GF_VARIANT_ACCESS.to_text(class_root_by_name[class_name_text])
				if class_root != extension_root and _contains_identifier(source, class_name_text):
					issues.append("%s references extension class %s" % [path, class_name_text])

	assert_eq(
		issues,
		[],
		"GF 内置扩展之间不能通过路径或扩展 ID 互相引用；跨扩展组合应留给项目或外部插件。"
	)


func test_business_extensions_remain_optional_atomic_extensions_without_internal_tags() -> void:
	var manifest_by_extension_name: Dictionary = _collect_manifest_by_extension_name(BUSINESS_EXTENSION_CANDIDATES)
	var issues: Array[String] = []
	for extension_name: String in BUSINESS_EXTENSION_CANDIDATES:
		var manifest_data: Dictionary = GF_VARIANT_ACCESS.get_option_dictionary(
			manifest_by_extension_name,
			extension_name,
			{}
		)
		if manifest_data.is_empty():
			issues.append("%s missing manifest" % extension_name)
			continue
		if GF_VARIANT_ACCESS.get_option_bool(manifest_data, "enabled_by_default", true):
			issues.append("%s must stay disabled by default" % extension_name)
		var dependencies: Array = GF_VARIANT_ACCESS.get_option_array(manifest_data, "dependencies", [])
		for dependency_variant: Variant in dependencies:
			var dependency_id: String = GF_VARIANT_ACCESS.to_text(dependency_variant)
			if not EXTENSION_ALLOWED_DEPENDENCIES.has(dependency_id):
				issues.append("%s declares non-foundation dependency %s" % [extension_name, dependency_id])
		var tags: Array = GF_VARIANT_ACCESS.get_option_array(manifest_data, "tags", [])
		for tag_variant: Variant in tags:
			var tag: String = GF_VARIANT_ACCESS.to_text(tag_variant)
			if EXTENSION_FORBIDDEN_INTERNAL_TAGS.has(tag):
				issues.append("%s leaks internal tag %s" % [extension_name, tag])

	assert_eq(
		issues,
		[],
		"Domain/Combat 属于业务型扩展：发布包内只能作为默认关闭的原子扩展存在，内部路线标签不得写入公开 manifest。"
	)


func test_2d_toolkit_preset_closure_stays_runtime_only_and_expected_size() -> void:
	var manifests_by_id: Dictionary = _collect_package_manifests(PACKAGE_ROOT)
	var closure: Dictionary = _resolve_package_closure("gf.preset.2d_toolkit", manifests_by_id)
	var expected_ids: Array[String] = [
		"gf.extension.camera",
		"gf.extension.flow",
		"gf.extension.interaction",
		"gf.extension.physics",
		"gf.kernel",
		"gf.preset.2d_toolkit",
		"gf.standard.base",
		"gf.standard.deterministic",
		"gf.standard.input",
		"gf.standard.spatial",
		"gf.standard.spatial.canvas",
		"gf.standard.ui",
	]
	var actual_ids: Array[String] = _sorted_dictionary_string_keys(closure)
	var editor_packages: Array[String] = []
	for package_id: String in actual_ids:
		if package_id.contains(".editor"):
			editor_packages.append(package_id)

	assert_eq(actual_ids, expected_ids, "2D toolkit preset 闭包应稳定包含 2D 运行时常用能力和必要依赖。")
	assert_eq(editor_packages, [], "2D toolkit runtime preset 不能拉入 editor-only package。")


func test_standard_input_package_closure_stays_runtime_only() -> void:
	var manifests_by_id: Dictionary = _collect_package_manifests(PACKAGE_ROOT)
	var closure: Dictionary = _resolve_package_closure("gf.standard.input", manifests_by_id)
	var actual_ids: Array[String] = _sorted_dictionary_string_keys(closure)

	assert_eq(
		actual_ids,
		["gf.kernel", "gf.standard.base", "gf.standard.input"],
		"Input runtime package 只能安装自身和基础运行时依赖。"
	)
	assert_false(
		actual_ids.has("gf.standard.input.editor"),
		"Input runtime package 不能反向安装 editor Dock。"
	)


func test_save_preset_closure_stays_minimal_runtime_only() -> void:
	var manifests_by_id: Dictionary = _collect_package_manifests(PACKAGE_ROOT)
	var closure: Dictionary = _resolve_package_closure("gf.preset.save", manifests_by_id)
	var expected_ids: Array[String] = [
		"gf.extension.save",
		"gf.kernel",
		"gf.preset.save",
		"gf.standard.base",
		"gf.standard.deterministic",
		"gf.standard.storage",
	]
	var actual_ids: Array[String] = _sorted_dictionary_string_keys(closure)

	assert_eq(actual_ids, expected_ids, "Save preset 只应安装保存扩展和必需标准依赖。")
	assert_false(_contains_editor_package(actual_ids), "Save runtime preset 不能拉入 editor-only package。")


func test_rpg_save_dialogue_preset_closure_stays_runtime_only_without_ui_fan_in() -> void:
	var manifests_by_id: Dictionary = _collect_package_manifests(PACKAGE_ROOT)
	var closure: Dictionary = _resolve_package_closure("gf.preset.rpg_save_dialogue", manifests_by_id)
	var expected_ids: Array[String] = [
		"gf.extension.dialogue",
		"gf.extension.domain",
		"gf.extension.save",
		"gf.kernel",
		"gf.preset.rpg_save_dialogue",
		"gf.standard.base",
		"gf.standard.config",
		"gf.standard.deterministic",
		"gf.standard.storage",
	]
	var actual_ids: Array[String] = _sorted_dictionary_string_keys(closure)

	assert_eq(actual_ids, expected_ids, "RPG Save Dialogue preset 只应包含叙事保存工作流的运行时闭包。")
	assert_false(actual_ids.has("gf.standard.ui"), "RPG Save Dialogue preset 不应隐式拉入 UI aggregate。")
	assert_false(_contains_editor_package(actual_ids), "RPG Save Dialogue runtime preset 不能拉入 editor-only package。")


func test_bundled_extensions_do_not_call_global_gf_facade() -> void:
	var files: Array[String] = []
	_collect_gd_files(EXTENSIONS_ROOT, files)
	var issues: Array[String] = []
	for path: String in files:
		var source: String = _read_text(path)
		if source.contains("Gf."):
			issues.append("%s calls global Gf facade" % path)

	assert_eq(
		issues,
		[],
		"GF 内置扩展运行时代码不能直接调用全局 Gf facade；需要依赖时应通过注入、局部上下文或项目显式赋值获得。"
	)


func test_known_extension_soft_collaboration_protocols_do_not_return() -> void:
	var issues: Array[String] = []
	for extension_name_variant: Variant in EXTENSION_FORBIDDEN_SOFT_REFERENCES.keys():
		var extension_name: String = GF_VARIANT_ACCESS.to_text(extension_name_variant)
		var extension_root: String = EXTENSIONS_ROOT.path_join(extension_name)
		var files: Array[String] = []
		_collect_gd_files(extension_root, files)
		var forbidden_texts: Array = GF_VARIANT_ACCESS.get_option_array(
			EXTENSION_FORBIDDEN_SOFT_REFERENCES,
			extension_name,
			[]
		)
		for path: String in files:
			var source: String = _read_text(path)
			for forbidden_text_variant: Variant in forbidden_texts:
				var forbidden_text: String = GF_VARIANT_ACCESS.to_text(forbidden_text_variant)
				if source.contains(forbidden_text):
					issues.append("%s contains soft collaboration marker %s" % [path, forbidden_text])

	assert_eq(
		issues,
		[],
		"已移除的内置扩展软协作协议不能回到 GF 扩展层；组合应放在项目或外部插件。"
	)


# --- 私有/辅助方法 ---

func _collect_gd_files(root_path: String, result: Array[String]) -> void:
	var dir: DirAccess = DirAccess.open(root_path)
	if dir == null:
		return

	var _list_dir_begin_result_291: Variant = dir.list_dir_begin()
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


func _collect_immediate_directory_names(root_path: String) -> Array[String]:
	var result: Array[String] = []
	var dir: DirAccess = DirAccess.open(root_path)
	if dir == null:
		return result

	var _list_dir_begin_result_310: Variant = dir.list_dir_begin()
	var entry: String = dir.get_next()
	while not entry.is_empty():
		if dir.current_is_dir() and not entry.begins_with("."):
			result.append(entry)
		entry = dir.get_next()
	dir.list_dir_end()
	result.sort()
	return result


func _collect_extension_ids() -> Array[String]:
	var result: Array[String] = []
	for extension_name: String in _collect_immediate_directory_names(EXTENSIONS_ROOT):
		result.append("gf.%s" % extension_name)
	return result


func _collect_manifest_by_extension_name(extension_names: Array[String]) -> Dictionary:
	var result: Dictionary = {}
	for extension_name: String in extension_names:
		var manifest_path: String = EXTENSIONS_ROOT.path_join(extension_name).path_join("gf_extension.json")
		var manifest_data: Dictionary = _read_json_dictionary(manifest_path)
		if manifest_data.is_empty():
			continue
		result[extension_name] = manifest_data
	return result


func _collect_package_manifests(root_path: String) -> Dictionary:
	var files: Array[String] = []
	_collect_json_files(root_path, files)
	var result: Dictionary = {}
	for path: String in files:
		var manifest_data: Dictionary = _read_json_dictionary(path)
		var package_id: String = GF_VARIANT_ACCESS.get_option_string(manifest_data, "id")
		if package_id.is_empty():
			continue
		result[package_id] = manifest_data
	return result


func _collect_json_files(root_path: String, result: Array[String]) -> void:
	var dir: DirAccess = DirAccess.open(root_path)
	if dir == null:
		return

	var _list_dir_begin_result_json: Variant = dir.list_dir_begin()
	var entry: String = dir.get_next()
	while not entry.is_empty():
		var path: String = root_path.path_join(entry)
		if dir.current_is_dir():
			if not entry.begins_with("."):
				_collect_json_files(path, result)
		elif entry.ends_with(".json"):
			result.append(path)
		entry = dir.get_next()
	dir.list_dir_end()


func _resolve_package_closure(root_package_id: String, manifests_by_id: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	var visiting: Dictionary = {}
	_resolve_package_closure_recursive(root_package_id, manifests_by_id, result, visiting)
	return result


func _resolve_package_closure_recursive(
	package_id: String,
	manifests_by_id: Dictionary,
	result: Dictionary,
	visiting: Dictionary
) -> void:
	if result.has(package_id) or visiting.has(package_id):
		return

	visiting[package_id] = true
	result[package_id] = true
	var manifest_data: Dictionary = GF_VARIANT_ACCESS.get_option_dictionary(manifests_by_id, package_id, {})
	var child_ids: Array = GF_VARIANT_ACCESS.get_option_array(manifest_data, "dependencies", [])
	if GF_VARIANT_ACCESS.get_option_string(manifest_data, "kind") == "preset":
		child_ids = GF_VARIANT_ACCESS.get_option_array(manifest_data, "packages", [])
	for child_id_variant: Variant in child_ids:
		var child_id: String = GF_VARIANT_ACCESS.to_text(child_id_variant)
		_resolve_package_closure_recursive(child_id, manifests_by_id, result, visiting)
	var _remove_visiting_result: bool = visiting.erase(package_id)


func _sorted_dictionary_string_keys(source: Dictionary) -> Array[String]:
	var result: Array[String] = []
	for key_variant: Variant in source.keys():
		result.append(GF_VARIANT_ACCESS.to_text(key_variant))
	result.sort()
	return result


func _contains_editor_package(package_ids: Array[String]) -> bool:
	for package_id: String in package_ids:
		if package_id.contains(".editor"):
			return true
	return false


func _read_text(path: String) -> String:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	var text: String = file.get_as_text()
	file.close()
	return text


func _read_json_dictionary(path: String) -> Dictionary:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if parsed is Dictionary:
		return GF_VARIANT_ACCESS.as_dictionary(parsed)
	return {}


func _collect_class_names(root_path: String) -> Array[String]:
	var files: Array[String] = []
	_collect_gd_files(root_path, files)

	var result: Array[String] = []
	var regex: RegEx = RegEx.new()
	var _compile_result_365: Variant = regex.compile("(?m)^\\s*class_name\\s+([A-Za-z_]\\w*)")
	for path: String in files:
		var source: String = _read_text(path)
		for match_result: RegExMatch in regex.search_all(source):
			var discovered_class_name: String = match_result.get_string(1)
			if not result.has(discovered_class_name):
				result.append(discovered_class_name)
	result.sort()
	return result


func _collect_extension_class_root_by_name() -> Dictionary:
	var files: Array[String] = []
	_collect_gd_files(EXTENSIONS_ROOT, files)

	var result: Dictionary = {}
	var regex: RegEx = RegEx.new()
	var _compile_result_382: Variant = regex.compile("(?m)^\\s*class_name\\s+([A-Za-z_]\\w*)")
	for path: String in files:
		var extension_root: String = _get_extension_root(path)
		var source: String = _read_text(path)
		for match_result: RegExMatch in regex.search_all(source):
			result[match_result.get_string(1)] = extension_root
	return result


func _get_extension_root(path: String) -> String:
	var marker: String = EXTENSIONS_ROOT + "/"
	if not path.begins_with(marker):
		return ""

	var slash_index: int = path.find("/", marker.length())
	if slash_index == -1:
		return ""
	return path.substr(0, slash_index)


func _collect_forbidden_class_reference_issues(
	files: Array[String],
	forbidden_class_names: Array[String]
) -> Array[String]:
	var issues: Array[String] = []
	for path: String in files:
		var source: String = _read_text(path)
		for forbidden_class_name: String in forbidden_class_names:
			if _contains_identifier(source, forbidden_class_name):
				issues.append("%s references %s" % [path, forbidden_class_name])
	return issues


func _contains_identifier(source: String, identifier: String) -> bool:
	var regex: RegEx = RegEx.new()
	var _compile_result_417: Variant = regex.compile("(?<![A-Za-z0-9_])%s(?![A-Za-z0-9_])" % identifier)
	return regex.search(source) != null
