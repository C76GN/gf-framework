@tool

## GFResourceRegistryTools: 通用资源注册表扫描和生成工具。
##
## 面向编辑器工具、构建脚本和项目安装器复用；它只从路径生成
## `GFResourceRegistry` / `GFResourceRegistryEntry`，不解释业务字段。
## [br]
## @api public
## [br]
## @category tool_api
## [br]
## @since 3.23.0
class_name GFResourceRegistryTools
extends RefCounted


# --- 枚举 ---

## 从资源路径生成条目 ID 的方式。
## [br]
## @api public
enum EntryIdMode {
	## 使用文件名，不包含扩展名。
	BASENAME,
	## 使用相对 base_path 的路径，不包含扩展名。
	RELATIVE_PATH,
	## 使用完整资源路径，不包含扩展名。
	FULL_PATH,
}


# --- 常量 ---

const _GF_PATH_TOOLS = preload("res://addons/gf/kernel/core/gf_path_tools.gd")

## 默认资源扩展名白名单，不包含点号。
## [br]
## @api public
const RESOURCE_EXTENSIONS: PackedStringArray = [
	"tres",
	"res",
	"tscn",
	"scn",
	"png",
	"jpg",
	"jpeg",
	"webp",
	"svg",
	"bmp",
	"tga",
	"exr",
	"hdr",
	"ktx",
	"ctex",
	"ogg",
	"wav",
	"mp3",
	"opus",
	"glb",
	"gltf",
	"obj",
	"fbx",
	"dae",
	"blend",
	"material",
	"shader",
	"gdshader",
	"gd",
	"cs",
]

## 默认排除的扫描路径。
## [br]
## @api public
const DEFAULT_EXCLUDED_PATHS: PackedStringArray = ["res://addons"]

## 默认递归扫描深度上限。
## [br]
## @api public
const DEFAULT_MAX_SCAN_DEPTH: int = 32

## 默认单次扫描收集的资源路径数量上限。
## [br]
## @api public
const DEFAULT_MAX_RESOURCE_PATHS: int = 10000

## 默认单次资源扫描访问的目录项数量上限。
## [br]
## @api public
## [br]
## @since 8.0.0
const DEFAULT_MAX_SCANNED_ENTRIES: int = 100000

## 默认路径字段：资源扩展名。
## [br]
## @api public
const FIELD_EXTENSION: StringName = &"extension"

## 默认路径字段：相对目录。
## [br]
## @api public
const FIELD_DIRECTORY: StringName = &"directory"

## 默认路径字段：文件基础名。
## [br]
## @api public
const FIELD_BASENAME: StringName = &"basename"

## 默认路径字段：相对路径。
## [br]
## @api public
const FIELD_RELATIVE_PATH: StringName = &"relative_path"

## 默认路径字段：由相对目录段推导的标签集合。
## [br]
## @api public
const FIELD_TAGS: StringName = &"tags"

## 默认路径字段：相对目录的第一段。
## [br]
## @api public
const FIELD_CATEGORY: StringName = &"category"

const _DEFAULT_TYPE_HINTS_BY_EXTENSION: Dictionary = {
	"tscn": "PackedScene",
	"scn": "PackedScene",
	"glb": "PackedScene",
	"gltf": "PackedScene",
	"png": "Texture2D",
	"jpg": "Texture2D",
	"jpeg": "Texture2D",
	"webp": "Texture2D",
	"svg": "Texture2D",
	"bmp": "Texture2D",
	"tga": "Texture2D",
	"exr": "Texture2D",
	"hdr": "Texture2D",
	"ktx": "Texture2D",
	"ctex": "Texture2D",
	"ogg": "AudioStream",
	"wav": "AudioStream",
	"mp3": "AudioStream",
	"opus": "AudioStream",
	"material": "Material",
	"shader": "Shader",
	"gdshader": "Shader",
	"gd": "Script",
	"cs": "Script",
}


# --- 公共方法 ---

## 判断路径是否指向受支持的资源扩展名。
## [br]
## @api public
## [br]
## @param path: 资源路径或文件名。
## [br]
## @param extensions: 可选扩展名白名单，不包含点号。
## [br]
## @return 是受支持资源路径时返回 true。
static func is_resource_path(path: String, extensions: PackedStringArray = RESOURCE_EXTENSIONS) -> bool:
	var extension: String = path.get_extension().to_lower()
	return not extension.is_empty() and _normalize_extensions(extensions).has(extension)


## 递归扫描资源路径。
## [br]
## @api public
## [br]
## @since 3.23.0
## [br]
## @param root_path: 扫描起点，通常是 res:// 下的目录。
## [br]
## @param options: 可选项，支持 recursive、include_addons、excluded_paths、extensions、include_patterns、exclude_patterns、pattern_base_path、include_hidden、include_import_sidecars、max_scan_depth、max_resource_paths 与 max_scanned_entries。
## [br]
## @return 按字典序排序的资源路径。
## [br]
## @schema options: Dictionary，可包含 recursive、include_addons、excluded_paths、extensions、include_patterns、exclude_patterns、pattern_base_path、include_hidden、include_import_sidecars、max_scan_depth、max_resource_paths 和 max_scanned_entries 字段。
static func scan_resource_paths(root_path: String = "res://", options: Dictionary = {}) -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	var normalized_root: String = _normalize_dir_path(root_path)
	var extensions: PackedStringArray = _get_extensions(options)
	var recursive: bool = GFVariantData.get_option_bool(options, "recursive", true)
	var excluded_paths: PackedStringArray = _get_excluded_paths(options)
	var pattern_base_path: String = _get_pattern_base_path(options, normalized_root)
	var include_patterns: Array[RegEx] = _compile_glob_patterns(
		GFVariantData.get_option_packed_string_array(options, "include_patterns", PackedStringArray())
	)
	var exclude_patterns: Array[RegEx] = _compile_glob_patterns(
		GFVariantData.get_option_packed_string_array(options, "exclude_patterns", PackedStringArray())
	)
	var include_hidden: bool = GFVariantData.get_option_bool(options, "include_hidden", false)
	var include_import_sidecars: bool = GFVariantData.get_option_bool(options, "include_import_sidecars", false)
	var max_scan_depth: int = maxi(GFVariantData.get_option_int(options, "max_scan_depth", DEFAULT_MAX_SCAN_DEPTH), 0)
	var max_resource_paths: int = maxi(GFVariantData.get_option_int(options, "max_resource_paths", DEFAULT_MAX_RESOURCE_PATHS), 0)
	var max_scanned_entries: int = maxi(
		GFVariantData.get_option_int(options, "max_scanned_entries", DEFAULT_MAX_SCANNED_ENTRIES),
		0
	)
	var scan_state: Dictionary = _make_scan_state()
	var enumeration_options: Dictionary = {
		"recursive": recursive,
		"include_hidden": include_hidden,
		"extensions": extensions,
		"excluded_paths": excluded_paths,
		"file_filter": func(candidate_path: String) -> bool:
			return _can_include_file_entry(
				candidate_path.get_file(),
				candidate_path,
				extensions,
				pattern_base_path,
				include_patterns,
				exclude_patterns,
				include_import_sidecars
			),
		"max_scan_depth": max_scan_depth,
		"max_file_count": max_resource_paths,
		"max_entry_count": max_scanned_entries,
		"sort": false,
	}
	var scan_report: Dictionary = GFPathEnumerationTools.scan_files(normalized_root, enumeration_options)
	result = GFVariantData.get_option_packed_string_array(scan_report, "paths")

	if GFVariantData.get_option_bool(scan_report, "truncated"):
		var limit_kind: String = GFVariantData.get_option_string(scan_report, "limit_kind", "")
		if limit_kind == "count":
			_warn_resource_path_limit(max_resource_paths, scan_state)
		elif limit_kind == "entry_count":
			_warn_scanned_entry_limit(max_scanned_entries, scan_state)
		elif limit_kind == "depth":
			_warn_scan_depth_limit(
				GFVariantData.get_option_string(scan_report, "limit_path", normalized_root),
				max_scan_depth,
				scan_state
			)
	result.sort()
	return result


## 从路径列表创建新的资源注册表。
## [br]
## @api public
## [br]
## @param paths: 资源路径列表。
## [br]
## @param options: 可选项，支持 id_mode、base_path、path_separator、strip_extension、type_hint、default_type_hint、type_hints_by_extension、extra_fields、fields_by_path、fields_by_id、include_path_fields、include_tags、include_category、tag_field 和 category_field。
## [br]
## @return 新建的资源注册表。
## [br]
## @schema options: Dictionary，可包含路径导入、ID 生成、类型提示和字段生成选项。
static func create_registry_from_paths(paths: PackedStringArray, options: Dictionary = {}) -> GFResourceRegistry:
	var registry: GFResourceRegistry = GFResourceRegistry.new()
	var import_options: Dictionary = GFVariantData.to_dictionary(options)
	import_options["overwrite"] = true
	var _import_report: GFValidationReport = add_paths_to_registry(registry, paths, import_options)
	return registry


## 扫描目录并创建新的资源注册表。
## [br]
## @api public
## [br]
## @param root_path: 扫描起点，通常是 res://assets。
## [br]
## @param options: 可选项，同时传给 scan_resource_paths() 与 create_registry_from_paths()。
## [br]
## @return 新建的资源注册表。
## [br]
## @schema options: Dictionary，可同时包含扫描选项和条目导入选项。
static func create_registry_from_scan(root_path: String = "res://", options: Dictionary = {}) -> GFResourceRegistry:
	var paths: PackedStringArray = scan_resource_paths(root_path, options)
	return create_registry_from_paths(paths, options)


## 收集资源的依赖路径。
##
## 该方法只读取 Godot `ResourceLoader.get_dependencies()` 暴露的依赖关系，
## 不打包 PCK、不改写 remap，也不解释资源业务含义。返回结果适合继续交给
## `create_registry_from_paths()`、`GFAssetUtility.preload_group_async()` 或渲染预热清单。
## [br]
## @api public
## [br]
## @param resource_path: 入口资源路径。
## [br]
## @param options: 可选项，支持 recursive、include_root、extensions、excluded_paths、max_scan_depth 与 max_dependency_paths。
## [br]
## @return 排序后的依赖路径。
## [br]
## @schema options: Dictionary，可包含 recursive、include_root、extensions、excluded_paths、max_scan_depth 和 max_dependency_paths 字段。
static func collect_dependency_paths(resource_path: String, options: Dictionary = {}) -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	var normalized_path: String = _normalize_resource_path(resource_path)
	if normalized_path.is_empty():
		return result

	var extensions: PackedStringArray = _get_extensions(options)
	var excluded_paths: PackedStringArray = GFVariantData.get_option_packed_string_array(options, "excluded_paths", PackedStringArray())
	var max_scan_depth: int = maxi(GFVariantData.get_option_int(options, "max_scan_depth", DEFAULT_MAX_SCAN_DEPTH), 0)
	var max_dependency_paths: int = maxi(GFVariantData.get_option_int(options, "max_dependency_paths", DEFAULT_MAX_RESOURCE_PATHS), 0)
	var recursive: bool = GFVariantData.get_option_bool(options, "recursive", true)
	var scan_state: Dictionary = _make_scan_state()
	var visited: Dictionary = {}

	if GFVariantData.get_option_bool(options, "include_root", false):
		var _root_appended: bool = _append_dependency_path(
			result,
			normalized_path,
			extensions,
			excluded_paths,
			max_dependency_paths,
			scan_state
		)

	_collect_dependency_paths_recursive(
		normalized_path,
		recursive,
		extensions,
		excluded_paths,
		result,
		visited,
		0,
		max_scan_depth,
		max_dependency_paths,
		scan_state
	)
	result.sort()
	return result


## 构建资源依赖诊断报告。
##
## 报告保留路径闭包、直接依赖、缺失依赖、排除依赖、循环和上限命中信息，
## 适合编辑器检查、构建预检、资源注册表生成前检查和预热清单诊断。
## [br]
## @api public
## [br]
## @param resource_path: 入口资源路径。
## [br]
## @param options: 可选项，支持 recursive、include_root、extensions、excluded_paths、max_scan_depth、max_dependency_paths 与 include_direct_dependencies。
## [br]
## @return 依赖诊断报告。
## [br]
## @schema options: Dictionary，可包含 recursive、include_root、extensions、excluded_paths、max_scan_depth、max_dependency_paths 和 include_direct_dependencies 字段。
## [br]
## @schema return: Dictionary，包含 ok、healthy、root_path、paths、resources、missing、excluded、cycles、issues、resource_count、missing_count、excluded_count、cycle_count、limit_reached、depth_limit_reached、error_count、warning_count、issue_count、summary 与 next_action 字段。
static func build_dependency_report(resource_path: String, options: Dictionary = {}) -> Dictionary:
	var normalized_path: String = _normalize_resource_path(resource_path)
	var report: Dictionary = _make_dependency_report(normalized_path)
	if normalized_path.is_empty():
		_append_dependency_report_issue(
			report,
			"error",
			"empty_resource_path",
			"",
			"",
			0,
			"Dependency report root path is empty."
		)
		return _finalize_dependency_report(report)

	var extensions: PackedStringArray = _get_extensions(options)
	var excluded_paths: PackedStringArray = GFVariantData.get_option_packed_string_array(options, "excluded_paths", PackedStringArray())
	var max_scan_depth: int = maxi(GFVariantData.get_option_int(options, "max_scan_depth", DEFAULT_MAX_SCAN_DEPTH), 0)
	var max_dependency_paths: int = maxi(GFVariantData.get_option_int(options, "max_dependency_paths", DEFAULT_MAX_RESOURCE_PATHS), 0)
	var recursive: bool = GFVariantData.get_option_bool(options, "recursive", true)
	var include_root: bool = GFVariantData.get_option_bool(options, "include_root", true)
	var include_direct_dependencies: bool = GFVariantData.get_option_bool(options, "include_direct_dependencies", true)
	var visited: Dictionary = {}
	var active_paths: Dictionary = {}
	var scan_state: Dictionary = _make_dependency_report_state()

	_collect_dependency_report_recursive(
		normalized_path,
		"",
		include_root,
		true,
		recursive,
		extensions,
		excluded_paths,
		report,
		visited,
		active_paths,
		scan_state,
		0,
		max_scan_depth,
		max_dependency_paths,
		include_direct_dependencies
	)
	return _finalize_dependency_report(report)


## 将路径列表加入资源注册表。
## [br]
## @api public
## [br]
## @param registry: 要写入的资源注册表。
## [br]
## @param paths: 资源路径列表。
## [br]
## @param options: 可选项，支持 id_mode、base_path、path_separator、strip_extension、overwrite、type_hint、default_type_hint、type_hints_by_extension、extra_fields、fields_by_path、fields_by_id、include_path_fields、include_tags、include_category、tag_field 和 category_field。
## [br]
## @return 导入报告。
## [br]
## @schema options: Dictionary，可包含路径导入、ID 生成、类型提示和字段生成选项。
static func add_paths_to_registry(
	registry: GFResourceRegistry,
	paths: PackedStringArray,
	options: Dictionary = {}
) -> GFValidationReport:
	var report: GFValidationReport = GFValidationReport.new("GFResourceRegistryTools.add_paths_to_registry")
	if registry == null:
		var _missing_registry_issue: RefCounted = report.add_error(&"missing_resource_registry", "Resource registry is null.")
		return report

	var overwrite: bool = GFVariantData.get_option_bool(options, "overwrite", false)
	var extensions: PackedStringArray = _get_extensions(options)
	var added_count: int = 0
	var skipped_count: int = 0
	for path: String in paths:
		if not is_resource_path(path, extensions):
			var _invalid_path_issue: RefCounted = report.add_warning(
				&"invalid_resource_path",
				"Path is not a supported resource file.",
				path,
				path
			)
			skipped_count += 1
			continue

		var entry_id: StringName = make_entry_id(path, options)
		if entry_id == &"":
			var _empty_id_issue: RefCounted = report.add_warning(
				&"empty_resource_entry_id",
				"Generated registry entry id is empty.",
				path,
				path
			)
			skipped_count += 1
			continue

		if registry.has_entry(entry_id) and not overwrite:
			var _duplicate_id_issue: RefCounted = report.add_warning(
				&"resource_entry_id_exists",
				"Registry entry id already exists and overwrite is disabled.",
				entry_id,
				path
			)
			skipped_count += 1
			continue

		var entry: GFResourceRegistryEntry = GFResourceRegistryEntry.new()
		var _configured_entry: Resource = entry.configure(entry_id, path, make_type_hint(path, options), make_entry_fields(path, options))
		var _entry_stored: bool = registry.set_entry(entry)
		added_count += 1

	report.metadata["added_count"] = added_count
	report.metadata["skipped_count"] = skipped_count
	return report


## 扫描目录并同步到已有资源注册表。
## [br]
## @api public
## [br]
## @param registry: 要写入的资源注册表。
## [br]
## @param root_path: 扫描起点，通常是 res://assets。
## [br]
## @param options: 可选项，同时传给 scan_resource_paths() 与 add_paths_to_registry()。
## [br]
## @return 导入报告。
## [br]
## @schema options: Dictionary，可同时包含扫描选项和条目导入选项。
static func sync_registry_from_scan(
	registry: GFResourceRegistry,
	root_path: String = "res://",
	options: Dictionary = {}
) -> GFValidationReport:
	var paths: PackedStringArray = scan_resource_paths(root_path, options)
	var report: GFValidationReport = add_paths_to_registry(registry, paths, options)
	report.metadata["root_path"] = root_path
	report.metadata["scanned_count"] = paths.size()
	return report


## 按选项从路径生成稳定条目 ID。
## [br]
## @api public
## [br]
## @since 3.23.0
## [br]
## @param path: 资源路径。
## [br]
## @param options: 可选项，支持 id_mode、base_path、path_separator、strip_extension。
## [br]
## @return 条目 ID。
## [br]
## @schema options: Dictionary，可包含 id_mode、base_path、path_separator 和 strip_extension 字段。
static func make_entry_id(path: String, options: Dictionary = {}) -> StringName:
	var mode: EntryIdMode = _resolve_id_mode(GFVariantData.get_option_value(options, "id_mode", EntryIdMode.BASENAME))
	var identity: GFResourceIdentity = _make_resource_identity(path, "", &"")
	var id_text: String = _get_identity_load_path(identity)
	match mode:
		EntryIdMode.BASENAME:
			id_text = id_text.get_file()
		EntryIdMode.RELATIVE_PATH:
			id_text = _make_relative_path(id_text, GFVariantData.get_option_string(options, "base_path", "res://"))
		EntryIdMode.FULL_PATH:
			pass

	if GFVariantData.get_option_bool(options, "strip_extension", true):
		id_text = id_text.get_basename()
	id_text = id_text.replace("/", GFVariantData.get_option_string(options, "path_separator", "/")).strip_edges()
	return StringName(id_text)


## 按选项从路径推导资源类型提示。
## [br]
## @api public
## [br]
## @param path: 资源路径。
## [br]
## @param options: 可选项，支持 type_hint、default_type_hint 与 type_hints_by_extension。
## [br]
## @return ResourceLoader 类型提示。
## [br]
## @schema options: Dictionary，可包含 type_hint、default_type_hint 和 type_hints_by_extension 字段。
static func make_type_hint(path: String, options: Dictionary = {}) -> String:
	var explicit_type_hint: String = GFVariantData.get_option_string(options, "type_hint", "")
	if not explicit_type_hint.is_empty():
		return explicit_type_hint

	var type_hints: Dictionary = GFVariantData.get_option_dictionary(
		options,
		"type_hints_by_extension",
		_DEFAULT_TYPE_HINTS_BY_EXTENSION
	)
	var identity: GFResourceIdentity = _make_resource_identity(path, "", &"")
	var extension: String = identity.extension
	var type_hint: Variant = GFVariantData.get_option_value(type_hints, extension, "")
	var type_hint_text: String = GFVariantData.to_text(type_hint)
	if not type_hint_text.is_empty():
		return type_hint_text
	return GFVariantData.get_option_string(options, "default_type_hint", "")


## 按选项从路径生成可索引字段。
## [br]
## @api public
## [br]
## @since 3.23.0
## [br]
## @param path: 资源路径。
## [br]
## @param options: 可选项，支持 base_path、extra_fields、fields_by_path、fields_by_id、include_path_fields、include_tags、include_category、tag_field 和 category_field。
## [br]
## @return 字段字典。
## [br]
## @schema options: Dictionary，可包含路径字段、目录标签和调用方附加字段选项。
## [br]
## @schema return: Dictionary keyed by field id with scalar, Array, or PackedStringArray values. include_path_fields adds extension, basename, directory, relative_path, and cache_key.
static func make_entry_fields(path: String, options: Dictionary = {}) -> Dictionary:
	var fields: Dictionary = GFVariantData.get_option_dictionary(options, "extra_fields", {})
	var identity: GFResourceIdentity = _make_resource_identity(path, make_type_hint(path, options), make_entry_id(path, options))
	var normalized_path: String = _get_identity_load_path(identity)
	var relative_path: String = _make_relative_path(
		normalized_path,
		GFVariantData.get_option_string(options, "base_path", "res://")
	)
	var entry_id: StringName = make_entry_id(path, options)

	if GFVariantData.get_option_bool(options, "include_path_fields", true):
		fields[FIELD_EXTENSION] = normalized_path.get_extension().to_lower()
		fields[FIELD_BASENAME] = normalized_path.get_file().get_basename()
		fields[FIELD_DIRECTORY] = _get_relative_directory(relative_path)
		fields[FIELD_RELATIVE_PATH] = relative_path
		fields[&"cache_key"] = identity.cache_key

	if GFVariantData.get_option_bool(options, "include_tags", true):
		var tags: PackedStringArray = _make_path_tags(relative_path)
		if not tags.is_empty():
			fields[GFVariantData.get_option_string_name(options, "tag_field", FIELD_TAGS)] = tags

	if GFVariantData.get_option_bool(options, "include_category", true):
		var category: String = _make_path_category(relative_path)
		if not category.is_empty():
			fields[GFVariantData.get_option_string_name(options, "category_field", FIELD_CATEGORY)] = category

	var _path_override_merge: Dictionary = GFVariantData.merge_dictionary(fields, _get_path_override_fields(path, options), true, true)
	var _id_override_merge: Dictionary = GFVariantData.merge_dictionary(fields, _get_id_override_fields(entry_id, options), true, true)
	return fields


# --- 私有/辅助方法 ---

static func _make_resource_identity(
	path: String,
	type_hint: String,
	resource_key: StringName
) -> GFResourceIdentity:
	return GFResourceIdentity.from_path(path, resource_key, type_hint, { "check_exists": false })


static func _get_identity_load_path(identity: GFResourceIdentity) -> String:
	if identity == null:
		return ""
	if not identity.canonical_path.is_empty():
		return identity.canonical_path
	return identity.raw_path


static func _collect_dependency_paths_recursive(
	resource_path: String,
	recursive: bool,
	extensions: PackedStringArray,
	excluded_paths: PackedStringArray,
	result: PackedStringArray,
	visited: Dictionary,
	depth: int,
	max_scan_depth: int,
	max_dependency_paths: int,
	scan_state: Dictionary
) -> void:
	if visited.has(resource_path):
		return
	visited[resource_path] = true
	if not _can_collect_more_resource_paths(result, max_dependency_paths):
		_warn_dependency_path_limit(max_dependency_paths, scan_state)
		return
	if not _can_scan_dependency_deeper(resource_path, depth, max_scan_depth, scan_state):
		return

	var dependencies: PackedStringArray = ResourceLoader.get_dependencies(resource_path)
	for dependency: String in dependencies:
		if not _can_collect_more_resource_paths(result, max_dependency_paths):
			_warn_dependency_path_limit(max_dependency_paths, scan_state)
			break

		var dependency_path: String = _normalize_resource_path(_get_dependency_resource_path(dependency))
		if dependency_path.is_empty():
			continue

		var appended: bool = _append_dependency_path(
			result,
			dependency_path,
			extensions,
			excluded_paths,
			max_dependency_paths,
			scan_state
		)
		if recursive and (appended or not visited.has(dependency_path)):
			_collect_dependency_paths_recursive(
				dependency_path,
				recursive,
				extensions,
				excluded_paths,
				result,
				visited,
				depth + 1,
				max_scan_depth,
				max_dependency_paths,
				scan_state
			)


static func _collect_dependency_report_recursive(
	resource_path: String,
	parent_path: String,
	include_current_path: bool,
	traverse_children: bool,
	recursive: bool,
	extensions: PackedStringArray,
	excluded_paths: PackedStringArray,
	report: Dictionary,
	visited: Dictionary,
	active_paths: Dictionary,
	scan_state: Dictionary,
	depth: int,
	max_scan_depth: int,
	max_dependency_paths: int,
	include_direct_dependencies: bool
) -> void:
	if resource_path.is_empty():
		return
	if active_paths.has(resource_path):
		_append_dependency_report_cycle(report, resource_path, parent_path, depth, scan_state)
		return

	var path_exists: bool = _resource_path_exists(resource_path)
	if not path_exists:
		_append_dependency_report_missing(report, resource_path, parent_path, depth, scan_state)
		return

	var resource_index: int = -1
	if include_current_path:
		if _can_include_dependency_path(resource_path, extensions, excluded_paths):
			resource_index = _append_dependency_report_resource(report, resource_path, parent_path, depth, max_dependency_paths)
			if resource_index < 0 and GFVariantData.get_option_bool(report, "limit_reached"):
				return
		else:
			_append_dependency_report_excluded(
				report,
				resource_path,
				parent_path,
				depth,
				_get_dependency_filter_reason(resource_path, extensions, excluded_paths),
				scan_state
			)

	if visited.has(resource_path):
		return
	visited[resource_path] = true
	if not traverse_children:
		return
	if not _can_scan_dependency_report_deeper(resource_path, depth, max_scan_depth, report, scan_state):
		return

	active_paths[resource_path] = true
	var direct_dependencies: Array = _get_dependency_resource_paths(resource_path)
	_update_dependency_report_resource_dependencies(report, resource_index, direct_dependencies, include_direct_dependencies)
	for dependency_value: Variant in direct_dependencies:
		var dependency_path: String = GFVariantData.to_text(dependency_value)
		if dependency_path.is_empty():
			continue
		_collect_dependency_report_recursive(
			dependency_path,
			resource_path,
			true,
			recursive,
			recursive,
			extensions,
			excluded_paths,
			report,
			visited,
			active_paths,
			scan_state,
			depth + 1,
			max_scan_depth,
			max_dependency_paths,
			include_direct_dependencies
		)
	var _active_path_erased: bool = active_paths.erase(resource_path)


static func _can_include_file_entry(
	entry: String,
	path: String,
	extensions: PackedStringArray,
	pattern_base_path: String,
	include_patterns: Array[RegEx],
	exclude_patterns: Array[RegEx],
	include_import_sidecars: bool
) -> bool:
	if not include_import_sidecars and entry.ends_with(".import"):
		return false
	if not is_resource_path(entry, extensions):
		return false
	return _matches_scan_patterns(path, pattern_base_path, include_patterns, exclude_patterns)


static func _can_scan_dependency_deeper(
	path: String,
	current_depth: int,
	max_scan_depth: int,
	scan_state: Dictionary
) -> bool:
	if max_scan_depth <= 0 or current_depth < max_scan_depth:
		return true
	_warn_dependency_depth_limit(path, max_scan_depth, scan_state)
	return false


static func _can_collect_more_resource_paths(result: PackedStringArray, max_resource_paths: int) -> bool:
	return max_resource_paths <= 0 or result.size() < max_resource_paths


static func _make_scan_state() -> Dictionary:
	return {
		"count_warning_emitted": false,
		"entry_warning_emitted": false,
		"depth_warning_emitted": false,
	}


static func _make_dependency_report(root_path: String) -> Dictionary:
	return {
		"ok": true,
		"healthy": true,
		"root_path": root_path,
		"paths": [],
		"resources": [],
		"missing": [],
		"excluded": [],
		"cycles": [],
		"issues": [],
		"resource_count": 0,
		"missing_count": 0,
		"excluded_count": 0,
		"cycle_count": 0,
		"limit_reached": false,
		"depth_limit_reached": false,
		"error_count": 0,
		"warning_count": 0,
		"issue_count": 0,
		"summary": "",
		"next_action": "",
	}


static func _make_dependency_report_state() -> Dictionary:
	return {
		"missing_paths": {},
		"excluded_keys": {},
		"cycle_keys": {},
		"limit_issue_emitted": false,
		"depth_issue_emitted": false,
	}


static func _warn_resource_path_limit(max_resource_paths: int, scan_state: Dictionary) -> void:
	if max_resource_paths <= 0 or GFVariantData.get_option_bool(scan_state, "count_warning_emitted"):
		return
	scan_state["count_warning_emitted"] = true
	push_warning("[GFResourceRegistryTools] scan_resource_paths 已达到 max_resource_paths=%d，后续资源已跳过。" % max_resource_paths)


static func _warn_scanned_entry_limit(max_scanned_entries: int, scan_state: Dictionary) -> void:
	if max_scanned_entries <= 0 or GFVariantData.get_option_bool(scan_state, "entry_warning_emitted"):
		return
	scan_state["entry_warning_emitted"] = true
	push_warning("[GFResourceRegistryTools] scan_resource_paths 已达到 max_scanned_entries=%d，后续目录项已跳过。" % max_scanned_entries)


static func _warn_scan_depth_limit(path: String, max_scan_depth: int, scan_state: Dictionary) -> void:
	if max_scan_depth <= 0 or GFVariantData.get_option_bool(scan_state, "depth_warning_emitted"):
		return
	scan_state["depth_warning_emitted"] = true
	push_warning("[GFResourceRegistryTools] scan_resource_paths 已达到 max_scan_depth=%d，已跳过更深目录：%s。" % [max_scan_depth, path])


static func _warn_dependency_path_limit(max_dependency_paths: int, scan_state: Dictionary) -> void:
	if max_dependency_paths <= 0 or GFVariantData.get_option_bool(scan_state, "count_warning_emitted"):
		return
	scan_state["count_warning_emitted"] = true
	push_warning("[GFResourceRegistryTools] collect_dependency_paths 已达到 max_dependency_paths=%d，后续依赖已跳过。" % max_dependency_paths)


static func _warn_dependency_depth_limit(path: String, max_scan_depth: int, scan_state: Dictionary) -> void:
	if max_scan_depth <= 0 or GFVariantData.get_option_bool(scan_state, "depth_warning_emitted"):
		return
	scan_state["depth_warning_emitted"] = true
	push_warning("[GFResourceRegistryTools] collect_dependency_paths 已达到 max_scan_depth=%d，已跳过更深依赖：%s。" % [max_scan_depth, path])


static func _get_extensions(options: Dictionary) -> PackedStringArray:
	return _normalize_extensions(
		GFVariantData.get_option_packed_string_array(options, "extensions", RESOURCE_EXTENSIONS)
	)


static func _get_excluded_paths(options: Dictionary) -> PackedStringArray:
	if GFVariantData.get_option_bool(options, "include_addons", false):
		return PackedStringArray()
	var paths: PackedStringArray = GFVariantData.get_option_packed_string_array(options, "excluded_paths", DEFAULT_EXCLUDED_PATHS)
	return _GF_PATH_TOOLS.normalize_root_paths(paths, false)


static func _get_pattern_base_path(options: Dictionary, normalized_root: String) -> String:
	var configured_base: String = GFVariantData.get_option_string(options, "pattern_base_path", normalized_root)
	if configured_base.strip_edges().is_empty():
		return normalized_root
	return _normalize_dir_path(configured_base)


static func _compile_glob_patterns(patterns: PackedStringArray) -> Array[RegEx]:
	var result: Array[RegEx] = []
	for pattern: String in patterns:
		var normalized_pattern: String = _normalize_glob_pattern(pattern)
		if normalized_pattern.is_empty():
			continue

		var regex: RegEx = RegEx.new()
		var compile_error: Error = regex.compile(_glob_to_regex(normalized_pattern))
		if compile_error == OK:
			result.append(regex)
	return result


static func _normalize_glob_pattern(pattern: String) -> String:
	var result: String = pattern.replace("\\", "/").strip_edges()
	while result.begins_with("./"):
		result = result.substr(2)
	return result.trim_prefix("/")


static func _glob_to_regex(pattern: String) -> String:
	var result: String = "^"
	var index: int = 0
	while index < pattern.length():
		var current: String = pattern.substr(index, 1)
		if current == "*":
			if index + 1 < pattern.length() and pattern.substr(index + 1, 1) == "*":
				if index + 2 < pattern.length() and pattern.substr(index + 2, 1) == "/":
					result += "(?:.*/)?"
					index += 3
				else:
					result += ".*"
					index += 2
			else:
				result += "[^/]*"
				index += 1
		elif current == "?":
			result += "[^/]"
			index += 1
		else:
			result += _escape_regex_character(current)
			index += 1
	result += "$"
	return result


static func _escape_regex_character(character: String) -> String:
	if ".+()[]{}^$|\\".contains(character):
		return "\\" + character
	return character


static func _matches_scan_patterns(
	path: String,
	pattern_base_path: String,
	include_patterns: Array[RegEx],
	exclude_patterns: Array[RegEx]
) -> bool:
	var normalized_path: String = _normalize_resource_path(path)
	var relative_path: String = _make_relative_path(normalized_path, pattern_base_path)
	var basename: String = normalized_path.get_file()
	if not include_patterns.is_empty() and not _matches_any_pattern(include_patterns, normalized_path, relative_path, basename):
		return false
	if _matches_any_pattern(exclude_patterns, normalized_path, relative_path, basename):
		return false
	return true


static func _matches_any_pattern(
	patterns: Array[RegEx],
	normalized_path: String,
	relative_path: String,
	basename: String
) -> bool:
	for regex: RegEx in patterns:
		if regex.search(relative_path) != null:
			return true
		if regex.search(normalized_path) != null:
			return true
		if regex.search(basename) != null:
			return true
	return false


static func _normalize_extensions(extensions: PackedStringArray) -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	for extension: String in extensions:
		var normalized: String = extension.strip_edges().to_lower()
		if normalized.begins_with("."):
			normalized = normalized.substr(1)
		if not normalized.is_empty() and not result.has(normalized):
			var _extension_appended: bool = result.append(normalized)
	return result


static func _resolve_id_mode(value: Variant) -> EntryIdMode:
	if value is int:
		var mode_value: int = value
		return _int_to_entry_id_mode(mode_value)

	match GFVariantData.to_text(value).strip_edges().to_lower():
		"relative", "relative_path":
			return EntryIdMode.RELATIVE_PATH
		"full", "full_path", "path":
			return EntryIdMode.FULL_PATH
		_:
			return EntryIdMode.BASENAME


static func _make_relative_path(path: String, base_path: String) -> String:
	var relative_path: String = _GF_PATH_TOOLS.make_relative_path(path, base_path)
	if relative_path.is_empty():
		return _GF_PATH_TOOLS.normalize_resource_path(path, "", false)
	return relative_path


static func _get_relative_directory(relative_path: String) -> String:
	var directory: String = relative_path.get_base_dir()
	if directory == ".":
		return ""
	return directory


static func _make_path_tags(relative_path: String) -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	var directory: String = _get_relative_directory(relative_path)
	if directory.is_empty():
		return result

	for segment: String in directory.split("/", false):
		var tag: String = segment.strip_edges()
		if not tag.is_empty() and not result.has(tag):
			var _tag_appended: bool = result.append(tag)
	return result


static func _make_path_category(relative_path: String) -> String:
	var tags: PackedStringArray = _make_path_tags(relative_path)
	if tags.is_empty():
		return ""
	return tags[0]


static func _get_path_override_fields(path: String, options: Dictionary) -> Dictionary:
	var fields_by_path: Dictionary = GFVariantData.get_option_dictionary(options, "fields_by_path", {})
	var identity: GFResourceIdentity = _make_resource_identity(path, "", &"")
	var normalized_path: String = _get_identity_load_path(identity)
	var value: Variant = GFVariantData.get_option_value(
		fields_by_path,
		normalized_path,
		GFVariantData.get_option_value(fields_by_path, path, {})
	)
	return GFVariantData.to_dictionary(value)


static func _append_dependency_path(
	result: PackedStringArray,
	path: String,
	extensions: PackedStringArray,
	excluded_paths: PackedStringArray,
	max_dependency_paths: int,
	scan_state: Dictionary
) -> bool:
	if not _can_collect_more_resource_paths(result, max_dependency_paths):
		_warn_dependency_path_limit(max_dependency_paths, scan_state)
		return false
	if not _can_include_dependency_path(path, extensions, excluded_paths):
		return false
	if result.has(path):
		return false
	var _path_appended: bool = result.append(path)
	return true


static func _can_include_dependency_path(
	path: String,
	extensions: PackedStringArray,
	excluded_paths: PackedStringArray
) -> bool:
	if path.is_empty():
		return false
	if _is_excluded_path(path, excluded_paths):
		return false
	if path.begins_with("uid://"):
		return true
	return is_resource_path(path, extensions)


static func _get_dependency_resource_path(dependency: String) -> String:
	var fallback_uid: String = ""
	var parts: PackedStringArray = dependency.split("::", false)
	for index: int in range(parts.size() - 1, -1, -1):
		var part: String = parts[index].strip_edges()
		if part.begins_with("res://") or part.begins_with("user://"):
			return part
		if fallback_uid.is_empty() and part.begins_with("uid://"):
			fallback_uid = part
	return fallback_uid


static func _normalize_resource_path(path: String) -> String:
	return _get_identity_load_path(_make_resource_identity(path, "", &""))


static func _get_id_override_fields(entry_id: StringName, options: Dictionary) -> Dictionary:
	var fields_by_id: Dictionary = GFVariantData.get_option_dictionary(options, "fields_by_id", {})
	var value: Variant = GFVariantData.get_option_value(
		fields_by_id,
		entry_id,
		GFVariantData.get_option_value(fields_by_id, String(entry_id), {})
	)
	return GFVariantData.to_dictionary(value)


static func _int_to_entry_id_mode(value: int) -> EntryIdMode:
	match clampi(value, EntryIdMode.BASENAME, EntryIdMode.FULL_PATH):
		EntryIdMode.RELATIVE_PATH:
			return EntryIdMode.RELATIVE_PATH
		EntryIdMode.FULL_PATH:
			return EntryIdMode.FULL_PATH
		_:
			return EntryIdMode.BASENAME


static func _normalize_dir_path(path: String) -> String:
	return _GF_PATH_TOOLS.normalize_root_path(path, "", false)


static func _is_excluded_path(path: String, excluded_paths: PackedStringArray) -> bool:
	return _GF_PATH_TOOLS.is_path_excluded(path, excluded_paths)


static func _append_dependency_report_resource(
	report: Dictionary,
	path: String,
	parent_path: String,
	depth: int,
	max_dependency_paths: int
) -> int:
	var paths: Array = GFVariantData.as_array(GFVariantData.get_option_value(report, "paths", []))
	if paths.has(path):
		return -1
	if max_dependency_paths > 0 and paths.size() >= max_dependency_paths:
		_mark_dependency_report_limit(report, path, parent_path, depth, max_dependency_paths)
		return -1

	paths.append(path)
	report["paths"] = paths
	var resources: Array = GFVariantData.as_array(GFVariantData.get_option_value(report, "resources", []))
	resources.append({
		"path": path,
		"parent_path": parent_path,
		"depth": depth,
		"extension": path.get_extension().to_lower(),
		"type_hint": make_type_hint(path),
		"children_scanned": false,
		"direct_dependency_count": 0,
		"direct_dependencies": [],
	})
	report["resources"] = resources
	return resources.size() - 1


static func _update_dependency_report_resource_dependencies(
	report: Dictionary,
	resource_index: int,
	direct_dependencies: Array,
	include_direct_dependencies: bool
) -> void:
	if resource_index < 0:
		return
	var resources: Array = GFVariantData.as_array(GFVariantData.get_option_value(report, "resources", []))
	if resource_index >= resources.size():
		return
	var record_value: Variant = resources[resource_index]
	if not record_value is Dictionary:
		return
	var record: Dictionary = record_value
	record["children_scanned"] = true
	record["direct_dependency_count"] = direct_dependencies.size()
	if include_direct_dependencies:
		record["direct_dependencies"] = direct_dependencies.duplicate()
	resources[resource_index] = record
	report["resources"] = resources


static func _append_dependency_report_missing(
	report: Dictionary,
	path: String,
	parent_path: String,
	depth: int,
	scan_state: Dictionary
) -> void:
	var missing_paths: Dictionary = GFVariantData.as_dictionary(GFVariantData.get_option_value(scan_state, "missing_paths", {}))
	if missing_paths.has(path):
		return
	missing_paths[path] = true
	scan_state["missing_paths"] = missing_paths
	var missing: Array = GFVariantData.as_array(GFVariantData.get_option_value(report, "missing", []))
	missing.append({
		"path": path,
		"parent_path": parent_path,
		"depth": depth,
	})
	report["missing"] = missing
	_append_dependency_report_issue(
		report,
		"error",
		"missing_resource" if parent_path.is_empty() else "missing_dependency",
		path,
		parent_path,
		depth,
		"Dependency resource is missing."
	)


static func _append_dependency_report_excluded(
	report: Dictionary,
	path: String,
	parent_path: String,
	depth: int,
	reason: String,
	scan_state: Dictionary
) -> void:
	var key: String = _make_dependency_report_key(path, parent_path)
	var excluded_keys: Dictionary = GFVariantData.as_dictionary(GFVariantData.get_option_value(scan_state, "excluded_keys", {}))
	if excluded_keys.has(key):
		return
	excluded_keys[key] = true
	scan_state["excluded_keys"] = excluded_keys
	var excluded: Array = GFVariantData.as_array(GFVariantData.get_option_value(report, "excluded", []))
	excluded.append({
		"path": path,
		"parent_path": parent_path,
		"depth": depth,
		"reason": reason,
	})
	report["excluded"] = excluded


static func _append_dependency_report_cycle(
	report: Dictionary,
	path: String,
	parent_path: String,
	depth: int,
	scan_state: Dictionary
) -> void:
	var key: String = _make_dependency_report_key(path, parent_path)
	var cycle_keys: Dictionary = GFVariantData.as_dictionary(GFVariantData.get_option_value(scan_state, "cycle_keys", {}))
	if cycle_keys.has(key):
		return
	cycle_keys[key] = true
	scan_state["cycle_keys"] = cycle_keys
	var cycles: Array = GFVariantData.as_array(GFVariantData.get_option_value(report, "cycles", []))
	cycles.append({
		"path": path,
		"parent_path": parent_path,
		"depth": depth,
	})
	report["cycles"] = cycles
	_append_dependency_report_issue(
		report,
		"warning",
		"dependency_cycle",
		path,
		parent_path,
		depth,
		"Dependency graph contains a cycle."
	)


static func _append_dependency_report_issue(
	report: Dictionary,
	severity: String,
	kind: String,
	path: String,
	parent_path: String,
	depth: int,
	message: String
) -> void:
	var issues: Array = GFVariantData.as_array(GFVariantData.get_option_value(report, "issues", []))
	var issue: Dictionary = {
		"severity": severity,
		"kind": kind,
		"message": message,
		"path": path,
		"parent_path": parent_path,
		"depth": depth,
	}
	issues.append(issue)
	report["issues"] = issues


static func _mark_dependency_report_limit(
	report: Dictionary,
	path: String,
	parent_path: String,
	depth: int,
	max_dependency_paths: int
) -> void:
	if GFVariantData.get_option_bool(report, "limit_reached"):
		return
	report["limit_reached"] = true
	_append_dependency_report_issue(
		report,
		"warning",
		"dependency_count_limit",
		path,
		parent_path,
		depth,
		"Dependency report reached max_dependency_paths=%d." % max_dependency_paths
	)


static func _can_scan_dependency_report_deeper(
	path: String,
	current_depth: int,
	max_scan_depth: int,
	report: Dictionary,
	scan_state: Dictionary
) -> bool:
	if max_scan_depth <= 0 or current_depth < max_scan_depth:
		return true
	if GFVariantData.get_option_bool(scan_state, "depth_issue_emitted"):
		return false
	scan_state["depth_issue_emitted"] = true
	report["depth_limit_reached"] = true
	_append_dependency_report_issue(
		report,
		"warning",
		"dependency_depth_limit",
		path,
		"",
		current_depth,
		"Dependency report reached max_scan_depth=%d." % max_scan_depth
	)
	return false


static func _finalize_dependency_report(report: Dictionary) -> Dictionary:
	var paths: Array = GFVariantData.as_array(GFVariantData.get_option_value(report, "paths", []))
	paths.sort()
	report["paths"] = paths
	var issues: Array = GFVariantData.as_array(GFVariantData.get_option_value(report, "issues", []))
	var error_count: int = 0
	var warning_count: int = 0
	for issue_value: Variant in issues:
		if not issue_value is Dictionary:
			continue
		var issue: Dictionary = issue_value
		match GFVariantData.get_option_string(issue, "severity", ""):
			"error":
				error_count += 1
			"warning":
				warning_count += 1

	var missing: Array = GFVariantData.as_array(GFVariantData.get_option_value(report, "missing", []))
	var excluded: Array = GFVariantData.as_array(GFVariantData.get_option_value(report, "excluded", []))
	var cycles: Array = GFVariantData.as_array(GFVariantData.get_option_value(report, "cycles", []))
	report["resource_count"] = paths.size()
	report["missing_count"] = missing.size()
	report["excluded_count"] = excluded.size()
	report["cycle_count"] = cycles.size()
	report["error_count"] = error_count
	report["warning_count"] = warning_count
	report["issue_count"] = issues.size()
	report["ok"] = error_count == 0
	report["healthy"] = issues.is_empty()
	_update_dependency_report_summary(report)
	return report


static func _update_dependency_report_summary(report: Dictionary) -> void:
	var resource_count: int = GFVariantData.get_option_int(report, "resource_count")
	var missing_count: int = GFVariantData.get_option_int(report, "missing_count")
	var excluded_count: int = GFVariantData.get_option_int(report, "excluded_count")
	var issue_count: int = GFVariantData.get_option_int(report, "issue_count")
	if missing_count > 0:
		report["summary"] = "Dependency report found %d missing resource(s)." % missing_count
		report["next_action"] = "Restore, reimport, or remap the missing resource path(s) before using the dependency closure."
	elif GFVariantData.get_option_bool(report, "limit_reached"):
		report["summary"] = "Dependency report reached the configured path limit after %d resource(s)." % resource_count
		report["next_action"] = "Increase max_dependency_paths or narrow the entry resource before trusting this report as complete."
	elif GFVariantData.get_option_bool(report, "depth_limit_reached"):
		report["summary"] = "Dependency report reached the configured depth limit after %d resource(s)." % resource_count
		report["next_action"] = "Increase max_scan_depth or inspect the skipped branch before trusting this report as complete."
	elif issue_count > 0:
		report["summary"] = "Dependency report collected %d resource(s) with %d issue(s)." % [resource_count, issue_count]
		report["next_action"] = "Inspect issues before using the dependency closure in build or preload tooling."
	else:
		report["summary"] = "Dependency report is healthy with %d resource(s) and %d excluded path(s)." % [resource_count, excluded_count]
		report["next_action"] = ""


static func _get_dependency_resource_paths(resource_path: String) -> Array:
	var result: Array = []
	var dependencies: PackedStringArray = ResourceLoader.get_dependencies(resource_path)
	for dependency: String in dependencies:
		var dependency_path: String = _normalize_resource_path(_get_dependency_resource_path(dependency))
		if not dependency_path.is_empty() and not result.has(dependency_path):
			result.append(dependency_path)
	return result


static func _resource_path_exists(path: String) -> bool:
	if path.is_empty():
		return false
	if ResourceLoader.exists(path):
		return true
	if path.begins_with("uid://"):
		return false
	return FileAccess.file_exists(path)


static func _get_dependency_filter_reason(
	path: String,
	extensions: PackedStringArray,
	excluded_paths: PackedStringArray
) -> String:
	if _is_excluded_path(path, excluded_paths):
		return "excluded_path"
	if not path.begins_with("uid://") and not is_resource_path(path, extensions):
		return "unsupported_extension"
	return "filtered"


static func _make_dependency_report_key(path: String, parent_path: String) -> String:
	return "%s <- %s" % [path, parent_path]
