## 测试 Content Package 扩展的 manifest、依赖诊断和资源解析注册。
extends GutTest


# --- 常量 ---

const GF_CONTENT_PACKAGE_EXTENSION = preload("res://addons/gf/extensions/content_package/extension.gd")
const TEMP_ROOT: String = "res://tests/gf_core/tmp_content_packages"
const TEMP_USER_ROOT: String = "user://gf_tmp_content_packages"


# --- 测试生命周期 ---

func before_each() -> void:
	_remove_path_if_exists(TEMP_ROOT)
	_remove_path_if_exists(TEMP_USER_ROOT)


func after_each() -> void:
	_remove_path_if_exists(TEMP_ROOT)
	_remove_path_if_exists(TEMP_USER_ROOT)


# --- 测试用例 ---

func test_manifest_normalizes_relative_resources() -> void:
	var manifest: GFContentPackageManifest = _make_manifest(
		&"author.base",
		[],
		[
			{
				"key": "icon",
				"path": "assets/icon.tres",
				"type_hint": "Resource",
				"metadata": {
					"role": "test",
				},
			},
		],
		TEMP_ROOT.path_join("base")
	)

	var resources: Array[Dictionary] = manifest.get_normalized_resources()
	var first_resource: Dictionary = resources[0]
	var metadata: Dictionary = GFVariantData.get_option_dictionary(first_resource, "metadata")

	assert_true(manifest.is_valid(), "有效内容包 manifest 应通过基础校验。")
	assert_eq(
		GFVariantData.get_option_string(first_resource, "path"),
		TEMP_ROOT.path_join("base/assets/icon.tres"),
		"相对资源路径应归一化到内容包根目录下。"
	)
	assert_eq(GFVariantData.get_option_string(metadata, "role"), "test", "资源 metadata 应保留项目自定义字段。")
	assert_eq(
		GFVariantData.get_option_string_name(metadata, "package_id"),
		&"author.base",
		"资源 metadata 应标识来源内容包。"
	)


func test_manifest_rejects_paths_outside_package_root() -> void:
	var manifest: GFContentPackageManifest = _make_manifest(
		&"author.base",
		[],
		[
			{
				"key": "escape",
				"path": "../escape.tres",
			},
		],
		TEMP_ROOT.path_join("base")
	)
	var report: Dictionary = manifest.get_validation_report()
	var issue: Dictionary = _find_issue(report, "resource_path_outside_package")

	assert_false(GFVariantData.get_option_bool(report, "ok"), "越过内容包根目录的资源路径应失败。")
	assert_eq(
		GFVariantData.get_option_string(issue, "kind"),
		"resource_path_outside_package",
		"路径越界应使用稳定 issue kind。"
	)


func test_manifest_rejects_uid_resources_because_package_root_cannot_be_verified() -> void:
	var manifest: GFContentPackageManifest = _make_manifest(
		&"author.base",
		[],
		[
			{
				"key": "uid_asset",
				"path": "uid://outside-package",
			},
		],
		TEMP_ROOT.path_join("base")
	)
	var report: Dictionary = manifest.get_validation_report()
	var issue: Dictionary = _find_issue(report, "resource_path_not_allowed")

	assert_false(GFVariantData.get_option_bool(report, "ok"), "uid:// 不能证明资源仍在内容包根目录内，应失败。")
	assert_eq(
		GFVariantData.get_option_string(issue, "kind"),
		"resource_path_not_allowed",
		"被拒绝的 uid:// 路径应使用稳定 issue kind。"
	)


func test_manifest_accepts_user_resources_inside_user_root() -> void:
	var manifest: GFContentPackageManifest = _make_manifest(
		&"author.runtime",
		[],
		[
			{
				"key": "runtime.data",
				"path": "assets/data.tres",
			},
		],
		TEMP_USER_ROOT.path_join("runtime")
	)
	var resources: Array[Dictionary] = manifest.get_normalized_resources()
	var first_resource: Dictionary = resources[0]

	assert_true(manifest.is_valid(), "user:// source root 内的资源路径应可用于运行时内容包。")
	assert_eq(
		GFVariantData.get_option_string(first_resource, "path"),
		TEMP_USER_ROOT.path_join("runtime/assets/data.tres"),
		"user:// 相对资源路径应归一到 user:// 内容包根目录。"
	)


func test_manifest_rejects_code_resources_for_data_only_packages() -> void:
	var manifest: GFContentPackageManifest = _make_manifest(
		&"author.data",
		[],
		[
			{
				"key": "script",
				"path": "scripts/tool.gd",
			},
		],
		TEMP_ROOT.path_join("data")
	)
	var report: Dictionary = manifest.get_validation_report()
	var issue: Dictionary = _find_issue(report, "resource_extension_forbidden")

	assert_false(GFVariantData.get_option_bool(report, "ok"), "data_only 内容包不应接受脚本资源。")
	assert_eq(
		GFVariantData.get_option_string(issue, "kind"),
		"resource_extension_forbidden",
		"安全分类拒绝扩展名时应使用稳定 issue kind。"
	)


func test_manifest_allows_code_resources_for_trusted_developer_packages() -> void:
	var manifest: GFContentPackageManifest = _make_manifest(
		&"author.tooling",
		[],
		[
			{
				"key": "script",
				"path": "scripts/tool.gd",
			},
		],
		TEMP_ROOT.path_join("tooling")
	)
	manifest.safety_kind = GFContentPackageManifest.SAFETY_KIND_TRUSTED_DEVELOPER

	assert_true(manifest.is_valid(), "trusted_developer 内容包可显式承载开发者代码资源。")


func test_catalog_orders_dependencies_before_dependents() -> void:
	var base_manifest: GFContentPackageManifest = _make_manifest(&"author.base")
	var feature_manifest: GFContentPackageManifest = _make_manifest(
		&"author.feature",
		PackedStringArray(["author.base"])
	)
	var catalog: GFContentPackageCatalog = GFContentPackageCatalog.new()
	var manifests: Array[GFContentPackageManifest] = [feature_manifest, base_manifest]
	var _catalog_updated: GFContentPackageCatalog = catalog.set_manifests(manifests)

	var ordered: PackedStringArray = catalog.get_ordered_package_ids()

	assert_eq(Array(ordered), ["author.base", "author.feature"], "依赖包应先于依赖方注册。")


func test_catalog_reports_missing_dependencies_and_cycles() -> void:
	var missing_manifest: GFContentPackageManifest = _make_manifest(
		&"author.feature",
		PackedStringArray(["author.missing"])
	)
	var first_manifest: GFContentPackageManifest = _make_manifest(
		&"author.first",
		PackedStringArray(["author.second"])
	)
	var second_manifest: GFContentPackageManifest = _make_manifest(
		&"author.second",
		PackedStringArray(["author.first"])
	)
	var catalog: GFContentPackageCatalog = GFContentPackageCatalog.new()
	var manifests: Array[GFContentPackageManifest] = [missing_manifest, first_manifest, second_manifest]
	var _catalog_updated: GFContentPackageCatalog = catalog.set_manifests(manifests)
	var report: Dictionary = catalog.get_graph_report()

	assert_false(GFVariantData.get_option_bool(report, "ok"), "缺失依赖和循环依赖应让图诊断失败。")
	assert_eq(
		GFVariantData.get_option_string(_find_issue(report, "missing_dependency"), "kind"),
		"missing_dependency",
		"缺失依赖应有稳定 issue kind。"
	)
	assert_eq(
		GFVariantData.get_option_string(_find_issue(report, "dependency_cycle"), "kind"),
		"dependency_cycle",
		"循环依赖应有稳定 issue kind。"
	)


func test_catalog_registers_resources_to_resolver_in_dependency_order() -> void:
	var base_manifest: GFContentPackageManifest = _make_manifest(
		&"author.base",
		[],
		[
			{
				"key": "shared.icon",
				"path": "assets/base_icon.tres",
				"type_hint": "Resource",
			},
		],
		TEMP_ROOT.path_join("base")
	)
	var feature_manifest: GFContentPackageManifest = _make_manifest(
		&"author.feature",
		PackedStringArray(["author.base"]),
		[
			{
				"key": "shared.icon",
				"path": "assets/feature_icon.tres",
				"type_hint": "Resource",
			},
		],
		TEMP_ROOT.path_join("feature")
	)
	var catalog: GFContentPackageCatalog = GFContentPackageCatalog.new()
	var manifests: Array[GFContentPackageManifest] = [feature_manifest, base_manifest]
	var _catalog_updated: GFContentPackageCatalog = catalog.set_manifests(manifests)
	var resolver: GFResourceResolverUtility = GFResourceResolverUtility.new()
	resolver.init()

	var report: Dictionary = catalog.register_resources(resolver, { "check_resource_exists": false })
	var resolved: Dictionary = resolver.resolve(&"shared.icon", "Resource", { "check_exists": false })

	assert_true(GFVariantData.get_option_bool(report, "ok"), "有效内容包目录应可注册到资源解析器。")
	assert_eq(GFVariantData.get_option_int(report, "registered_count"), 2, "两个内容包资源都应参与注册。")
	assert_eq(
		GFVariantData.get_option_string(resolved, "path"),
		TEMP_ROOT.path_join("feature/assets/feature_icon.tres"),
		"依赖方后注册时应可覆盖依赖包的同名资源键。"
	)
	resolver.dispose()


func test_utility_discovers_direct_child_package_manifests() -> void:
	_write_manifest_file(
		TEMP_ROOT.path_join("base/gf_content_package.json"),
		{
			"package_id": "author.base",
			"version": "1.0.0",
			"resources": [],
		}
	)
	var utility: GFContentPackageUtility = GFContentPackageUtility.new()
	utility.init()
	var registered: bool = utility.register_source_root(TEMP_ROOT)
	var paths: PackedStringArray = utility.discover_manifest_paths()
	var report: Dictionary = utility.rebuild_catalog()

	assert_true(registered, "res:// source root 应可注册。")
	assert_eq(paths.size(), 1, "source root 的直接子目录 manifest 应被发现。")
	assert_true(GFVariantData.get_option_bool(report, "ok"), "发现到的有效 manifest 应能重建目录。")
	assert_true(utility.get_catalog().has_package(&"author.base"), "重建后的目录应包含内容包。")
	utility.dispose()


func test_utility_reports_invalid_manifest_files() -> void:
	_write_text_file(TEMP_ROOT.path_join("broken/gf_content_package.json"), "{not-json")
	var utility: GFContentPackageUtility = GFContentPackageUtility.new()
	utility.init()
	var _registered: bool = utility.register_source_root(TEMP_ROOT)

	var report: Dictionary = utility.rebuild_catalog()
	var issue: Dictionary = _find_issue(report, "invalid_manifest_file")

	assert_false(GFVariantData.get_option_bool(report, "ok"), "坏 manifest JSON 不应被静默跳过。")
	assert_eq(GFVariantData.get_option_int(report, "error_count"), 1, "坏 manifest 文件应计入错误数量。")
	assert_eq(GFVariantData.get_option_int(report, "issue_count"), 1, "坏 manifest 文件应计入问题数量。")
	assert_eq(
		GFVariantData.get_option_string(issue, "kind"),
		"invalid_manifest_file",
		"坏 manifest 文件应有稳定 issue kind。"
	)
	utility.dispose()


func test_utility_discovers_user_source_root_manifests() -> void:
	_write_manifest_file(
		TEMP_USER_ROOT.path_join("runtime/gf_content_package.json"),
		{
			"package_id": "author.runtime",
			"version": "1.0.0",
			"resources": [],
		}
	)
	var utility: GFContentPackageUtility = GFContentPackageUtility.new()
	utility.init()
	var registered: bool = utility.register_source_root(TEMP_USER_ROOT)
	var paths: PackedStringArray = utility.discover_manifest_paths()
	var report: Dictionary = utility.rebuild_catalog()

	assert_true(registered, "user:// source root 应可注册。")
	assert_eq(paths.size(), 1, "user:// source root 的直接子目录 manifest 应被发现。")
	assert_true(GFVariantData.get_option_bool(report, "ok"), "user:// 内容包 manifest 应能重建目录。")
	assert_true(utility.get_catalog().has_package(&"author.runtime"), "重建后的目录应包含 user:// 内容包。")
	utility.dispose()


func test_export_plan_builds_manifest_and_resource_entries() -> void:
	var manifest: GFContentPackageManifest = _make_manifest(
		&"author.base",
		[],
		[
			{
				"key": "icon",
				"path": "assets/icon.tres",
				"type_hint": "Resource",
			},
		],
		TEMP_ROOT.path_join("base")
	)

	var plan: GFContentPackageExportPlan = GFContentPackageExportPlan.from_manifest(manifest, {
		"archive_root": "packages/base",
	})
	var report: Dictionary = plan.get_validation_report()
	var entries: Array = GFVariantData.get_option_array(report, "entries")
	var resource_entry: Dictionary = _find_export_entry(entries, &"resource")

	assert_true(GFVariantData.get_option_bool(report, "ok"), "有效 manifest 应能构建导出计划。")
	assert_eq(GFVariantData.get_option_int(report, "entry_count"), 2, "计划应包含 manifest 和资源条目。")
	assert_eq(
		GFVariantData.get_option_string(resource_entry, "archive_path"),
		"packages/base/assets/icon.tres",
		"归档路径应按内容包根目录生成，不依赖项目业务规则。"
	)


func test_extension_installer_registers_content_package_utility() -> void:
	var architecture: GFArchitecture = GFArchitecture.new()
	var installer: GFInstaller = GF_CONTENT_PACKAGE_EXTENSION.new()

	installer.install(architecture)

	assert_not_null(
		architecture.get_local_utility(GFContentPackageUtility),
		"启用 Content Package 扩展应注册 GFContentPackageUtility。"
	)
	architecture.dispose()


# --- 私有/辅助方法 ---

func _make_manifest(
	package_id: StringName,
	dependencies: PackedStringArray = PackedStringArray(),
	resources: Array[Dictionary] = [],
	root_path: String = ""
) -> GFContentPackageManifest:
	var manifest: GFContentPackageManifest = GFContentPackageManifest.new()
	var _configured_manifest: GFContentPackageManifest = manifest.configure(
		package_id,
		"1.0.0",
		resources,
		String(package_id),
		PackedStringArray(["test"]),
		dependencies,
		{},
		root_path,
		root_path.path_join("gf_content_package.json") if not root_path.is_empty() else ""
	)
	return manifest


func _find_issue(report: Dictionary, kind: String) -> Dictionary:
	for issue_variant: Variant in GFVariantData.get_option_array(report, "issues"):
		var issue: Dictionary = GFVariantData.as_dictionary(issue_variant)
		if GFVariantData.get_option_string(issue, "kind") == kind:
			return issue
	return {}


func _find_export_entry(entries: Array, role: StringName) -> Dictionary:
	for entry_value: Variant in entries:
		var entry: Dictionary = GFVariantData.as_dictionary(entry_value)
		if GFVariantData.get_option_string_name(entry, "role") == role:
			return entry
	return {}


func _write_manifest_file(path: String, data: Dictionary) -> void:
	_write_text_file(path, JSON.stringify(data))


func _write_text_file(path: String, text: String) -> void:
	var directory_path: String = path.get_base_dir()
	var _mkdir_result: Error = DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory_path))
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return
	var _stored_text: bool = file.store_string(text)
	file.close()


func _remove_path_if_exists(path: String) -> void:
	var absolute_path: String = ProjectSettings.globalize_path(path)
	if not FileAccess.file_exists(path) and not DirAccess.dir_exists_absolute(absolute_path):
		return
	_remove_absolute_path(absolute_path)


func _remove_absolute_path(path: String) -> void:
	if FileAccess.file_exists(path):
		var _remove_file_result: Error = DirAccess.remove_absolute(path)
		return
	if not DirAccess.dir_exists_absolute(path):
		return

	var dir: DirAccess = DirAccess.open(path)
	if dir == null:
		return
	var _list_result: Error = dir.list_dir_begin()
	var entry: String = dir.get_next()
	while not entry.is_empty():
		if entry != "." and entry != "..":
			_remove_absolute_path(path.path_join(entry))
		entry = dir.get_next()
	dir.list_dir_end()
	var _remove_dir_result: Error = DirAccess.remove_absolute(path)
