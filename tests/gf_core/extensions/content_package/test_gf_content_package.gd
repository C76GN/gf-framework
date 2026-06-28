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


func test_manifest_requires_supported_schema_version_in_dictionary() -> void:
	var missing_schema: GFContentPackageManifest = GFContentPackageManifest.from_dictionary({
		"package_id": "author.missing_schema",
		"version": "1.0.0",
		"resources": [],
	}, TEMP_ROOT.path_join("missing_schema"))
	var unsupported_schema: GFContentPackageManifest = GFContentPackageManifest.from_dictionary({
		"schema_version": 2,
		"package_id": "author.unsupported_schema",
		"version": "1.0.0",
		"resources": [],
	}, TEMP_ROOT.path_join("unsupported_schema"))
	var invalid_schema: GFContentPackageManifest = GFContentPackageManifest.from_dictionary({
		"schema_version": "1",
		"package_id": "author.invalid_schema",
		"version": "1.0.0",
		"resources": [],
	}, TEMP_ROOT.path_join("invalid_schema"))

	assert_eq(
		GFVariantData.get_option_string(_find_issue(missing_schema.get_validation_report(), "missing_schema_version"), "kind"),
		"missing_schema_version",
		"字典 manifest 必须显式声明 schema_version。"
	)
	assert_eq(
		GFVariantData.get_option_string(_find_issue(unsupported_schema.get_validation_report(), "unsupported_schema_version"), "kind"),
		"unsupported_schema_version",
		"未来 schema_version 应被拒绝而不是按当前结构误读。"
	)
	assert_eq(
		GFVariantData.get_option_string(_find_issue(invalid_schema.get_validation_report(), "invalid_schema_version"), "kind"),
		"invalid_schema_version",
		"schema_version 不能使用字符串等宽松类型。"
	)


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


func test_catalog_remove_manifest_clears_duplicate_package_id_state() -> void:
	var catalog: GFContentPackageCatalog = GFContentPackageCatalog.new()
	var first_manifest: GFContentPackageManifest = _make_manifest(&"author.duplicate")
	var second_manifest: GFContentPackageManifest = _make_manifest(&"author.duplicate")
	var _first_added: bool = catalog.add_manifest(first_manifest)
	var _second_added: bool = catalog.add_manifest(second_manifest)

	var duplicate_report: Dictionary = catalog.get_graph_report()
	var removed: bool = catalog.remove_manifest(&"author.duplicate")
	var clean_report: Dictionary = catalog.get_graph_report()

	assert_false(GFVariantData.get_option_bool(duplicate_report, "ok"), "重复 package_id 应进入诊断。")
	assert_true(removed, "应能移除已注册 manifest。")
	assert_true(GFVariantData.get_option_bool(clean_report, "ok"), "移除重复 package_id 后重复状态不应残留。")
	assert_true(GFVariantData.get_option_packed_string_array(clean_report, "duplicate_package_ids").is_empty(), "重复 ID 缓存应同步清空。")


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


func test_catalog_register_resources_clears_previous_content_package_owned_keys() -> void:
	var manifest: GFContentPackageManifest = _make_manifest(
		&"author.base",
		[],
		[
			{
				"key": "shared.icon",
				"path": "assets/base_icon.tres",
			},
		],
		TEMP_ROOT.path_join("base")
	)
	var catalog: GFContentPackageCatalog = GFContentPackageCatalog.new()
	var _catalog_updated: GFContentPackageCatalog = catalog.set_manifests([manifest])
	var resolver: GFResourceResolverUtility = GFResourceResolverUtility.new()
	resolver.init()
	var _first_report: Dictionary = catalog.register_resources(resolver, { "check_resource_exists": false })
	var metadata: Dictionary = GFVariantData.get_option_dictionary(
		resolver.resolve(&"shared.icon", "", { "check_exists": false }),
		"metadata"
	)

	var empty_catalog: GFContentPackageCatalog = GFContentPackageCatalog.new()
	var _second_report: Dictionary = empty_catalog.register_resources(resolver, { "check_resource_exists": false })

	assert_true(GFVariantData.get_option_bool(metadata, "_gf_content_package_resource"), "内容包注册的资源应带 owned 标记。")
	assert_false(resolver.has_registered_key(&"shared.icon"), "下一次同步应清理上一轮内容包拥有的旧资源键。")
	resolver.dispose()


func test_utility_discovers_direct_child_package_manifests() -> void:
	_write_manifest_file(
		TEMP_ROOT.path_join("base/gf_content_package.json"),
		{
			"schema_version": 1,
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
			"schema_version": 1,
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


func test_utility_keeps_previous_catalog_when_manual_replacement_is_invalid() -> void:
	var utility: GFContentPackageUtility = GFContentPackageUtility.new()
	utility.init()
	var valid_manifest: GFContentPackageManifest = _make_manifest(&"author.valid")
	var duplicate_a: GFContentPackageManifest = _make_manifest(&"author.duplicate")
	var duplicate_b: GFContentPackageManifest = _make_manifest(&"author.duplicate")
	var _valid_report: Dictionary = utility.set_manifests([valid_manifest])
	watch_signals(utility)

	var invalid_report: Dictionary = utility.set_manifests([duplicate_a, duplicate_b])

	assert_false(GFVariantData.get_option_bool(invalid_report, "ok"), "无效候选 catalog 不应替换当前 catalog。")
	assert_true(utility.get_catalog().has_package(&"author.valid"), "替换失败时应保留上一份有效 catalog。")
	assert_false(utility.get_catalog().has_package(&"author.duplicate"), "替换失败时不应泄露候选 catalog。")
	assert_signal_not_emitted(utility, "catalog_rebuilt", "失败替换不应发出 catalog_rebuilt。")
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


func test_export_plan_artifact_report_includes_file_metadata() -> void:
	var root_path: String = TEMP_ROOT.path_join("artifact")
	var resource_path: String = root_path.path_join("assets/icon.txt")
	_write_manifest_file(root_path.path_join("gf_content_package.json"), {
		"schema_version": 1,
		"package_id": "author.artifact",
		"version": "1.0.0",
		"resources": [],
	})
	_write_text_file(resource_path, "icon-data")
	var expected_sha256: String = FileAccess.get_sha256(resource_path).to_lower()
	var expected_size: int = _read_file_size(resource_path)
	var manifest: GFContentPackageManifest = _make_manifest(
		&"author.artifact",
		[],
		[
			{
				"key": "icon",
				"path": "assets/icon.txt",
				"metadata": {
					"expected_sha256": expected_sha256,
					"expected_size_bytes": expected_size,
				},
			},
		],
		root_path
	)

	var plan: GFContentPackageExportPlan = GFContentPackageExportPlan.from_manifest(manifest)
	var report: Dictionary = plan.get_artifact_report()
	var artifacts: Array = GFVariantData.get_option_array(report, "artifacts")
	var resource_artifact: Dictionary = _find_export_entry(artifacts, &"resource")

	assert_true(GFVariantData.get_option_bool(report, "ok"), "artifact 元数据匹配时报告应通过。")
	assert_eq(GFVariantData.get_option_int(report, "artifact_count"), 2, "报告应包含 manifest 和资源 artifact。")
	assert_eq(
		GFVariantData.get_option_int(resource_artifact, "size_bytes"),
		expected_size,
		"资源 artifact 应报告源文件大小。"
	)
	assert_eq(
		GFVariantData.get_option_string(resource_artifact, "sha256"),
		expected_sha256,
		"资源 artifact 应报告 sha256，供项目构建或安装器复用。"
	)


func test_export_plan_from_catalog_propagates_graph_errors() -> void:
	var manifest: GFContentPackageManifest = _make_manifest(
		&"author.feature",
		PackedStringArray(["author.missing"])
	)
	var catalog: GFContentPackageCatalog = GFContentPackageCatalog.new()
	var _catalog_updated: GFContentPackageCatalog = catalog.set_manifests([manifest])

	var plan: GFContentPackageExportPlan = GFContentPackageExportPlan.from_catalog(catalog)
	var report: Dictionary = plan.get_validation_report()

	assert_false(GFVariantData.get_option_bool(report, "ok"), "catalog 依赖图错误应传播到导出计划。")
	assert_eq(
		GFVariantData.get_option_string(_find_issue(report, "missing_dependency"), "kind"),
		"missing_dependency",
		"导出计划应保留 catalog graph issue kind。"
	)


func test_export_plan_rejects_unsafe_archive_paths() -> void:
	var plan: GFContentPackageExportPlan = GFContentPackageExportPlan.new()

	var parent_escape_added: bool = plan.add_entry("res://icon.txt", "../escape/icon.txt")
	var absolute_added: bool = plan.add_entry("res://icon.txt", "/escape/icon.txt")
	var drive_added: bool = plan.add_entry("res://icon.txt", "C:/escape/icon.txt")
	var report: Dictionary = plan.get_validation_report()

	assert_false(parent_escape_added, "归档路径不应允许父级越界。")
	assert_false(absolute_added, "归档路径不应允许绝对路径。")
	assert_false(drive_added, "归档路径不应允许平台盘符或 scheme。")
	assert_eq(GFVariantData.get_option_int(report, "error_count"), 3, "所有非法归档路径都应进入诊断。")
	assert_eq(
		GFVariantData.get_option_string(_find_issue(report, "invalid_archive_path"), "kind"),
		"invalid_archive_path",
		"非法归档路径应使用稳定 issue kind。"
	)


func test_export_plan_artifact_report_detects_expected_metadata_mismatch() -> void:
	var root_path: String = TEMP_ROOT.path_join("artifact_mismatch")
	var resource_path: String = root_path.path_join("assets/icon.txt")
	_write_text_file(resource_path, "actual-data")
	var manifest: GFContentPackageManifest = _make_manifest(
		&"author.artifact_mismatch",
		[],
		[
			{
				"key": "icon",
				"path": "assets/icon.txt",
				"metadata": {
					"expected_sha256": "0000000000000000000000000000000000000000000000000000000000000000",
					"expected_size_bytes": 999,
				},
			},
		],
		root_path
	)

	var plan: GFContentPackageExportPlan = GFContentPackageExportPlan.from_manifest(manifest, {
		"include_manifest": false,
	})
	var report: Dictionary = plan.get_artifact_report()
	var size_issue: Dictionary = _find_issue(report, "artifact_size_mismatch")
	var sha_issue: Dictionary = _find_issue(report, "artifact_sha256_mismatch")

	assert_false(GFVariantData.get_option_bool(report, "ok"), "expected metadata 不匹配时 artifact 报告应失败。")
	assert_eq(
		GFVariantData.get_option_string(size_issue, "kind"),
		"artifact_size_mismatch",
		"大小不匹配应使用稳定 issue kind。"
	)
	assert_eq(
		GFVariantData.get_option_string(sha_issue, "kind"),
		"artifact_sha256_mismatch",
		"sha256 不匹配应使用稳定 issue kind。"
	)


func test_export_plan_artifact_report_can_skip_sha256_calculation() -> void:
	var root_path: String = TEMP_ROOT.path_join("artifact_no_sha")
	var resource_path: String = root_path.path_join("assets/icon.txt")
	_write_text_file(resource_path, "actual-data")
	var manifest: GFContentPackageManifest = _make_manifest(
		&"author.artifact_no_sha",
		[],
		[
			{
				"key": "icon",
				"path": "assets/icon.txt",
				"metadata": {
					"expected_sha256": "0000000000000000000000000000000000000000000000000000000000000000",
					"expected_size_bytes": _read_file_size(resource_path),
				},
			},
		],
		root_path
	)

	var plan: GFContentPackageExportPlan = GFContentPackageExportPlan.from_manifest(manifest, {
		"include_manifest": false,
	})
	var report: Dictionary = plan.get_artifact_report({
		"include_sha256": false,
	})
	var artifacts: Array = GFVariantData.get_option_array(report, "artifacts")
	var resource_artifact: Dictionary = _find_export_entry(artifacts, &"resource")

	assert_true(GFVariantData.get_option_bool(report, "ok"), "关闭 sha256 计算时不应执行 sha256 metadata 校验。")
	assert_false(resource_artifact.has("sha256"), "关闭 include_sha256 后 artifact 不应输出 sha256。")


func test_export_plan_preflight_merges_profile_and_artifact_checks() -> void:
	var root_path: String = TEMP_ROOT.path_join("preflight")
	var resource_path: String = root_path.path_join("assets/icon.txt")
	_write_text_file(resource_path, "actual-data")
	var manifest: GFContentPackageManifest = _make_manifest(
		&"author.preflight",
		[],
		[
			{
				"key": "icon",
				"path": "assets/icon.txt",
			},
		],
		root_path
	)
	var plan: GFContentPackageExportPlan = GFContentPackageExportPlan.from_manifest(manifest, {
		"include_manifest": false,
	})
	var profile: GFCompatibilityProfile = GFCompatibilityProfile.new()
	var _configured_profile: GFCompatibilityProfile = profile.configure(
		&"desktop",
		"4.7.0",
		"6.0.0",
		PackedStringArray(["Windows"]),
		PackedStringArray(["content_package"])
	)

	var report: Dictionary = plan.get_preflight_report(profile, {
		"minimum_godot_version": "4.8.0",
		"required_features": PackedStringArray(["offline_bundle"]),
	})

	assert_false(GFVariantData.get_option_bool(report, "ok"), "不满足显式 Profile 要求时内容包预检应失败。")
	assert_false(_find_issue(report, "godot_version_below_minimum").is_empty(), "Godot 版本要求应进入内容包预检。")
	assert_false(_find_issue(report, "feature_missing").is_empty(), "功能要求应进入内容包预检。")
	assert_eq(GFVariantData.get_option_string_name(report, "target_id"), &"author.preflight", "预检应标识内容包 ID。")


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


func _read_file_size(path: String) -> int:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return -1
	var size_bytes: int = int(file.get_length())
	file.close()
	return size_bytes


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
