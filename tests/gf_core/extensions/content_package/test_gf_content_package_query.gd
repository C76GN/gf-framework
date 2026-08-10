## 测试内容包查询、资产目录适配和 source root 所有权契约。
extends GutTest


# --- 测试用例 ---

func test_query_returns_dependency_first_snapshot_without_leaking_manifest_mutation() -> void:
	var base_manifest: GFContentPackageManifest = _make_manifest(
		&"author.base",
		PackedStringArray(),
		PackedStringArray(["theme"]),
		{"channel": "stable"},
		[{
			"key": "base.palette",
			"path": "assets/palette.tres",
		}]
	)
	var ui_manifest: GFContentPackageManifest = _make_manifest(
		&"author.ui",
		PackedStringArray(["author.base"]),
		PackedStringArray(["ui", "theme"]),
		{"channel": "stable"},
		[{
			"key": "ui.save",
			"path": "assets/save.png",
		}]
	)
	var catalog: GFContentPackageCatalog = GFContentPackageCatalog.new().set_manifests([
		ui_manifest,
		base_manifest,
	])
	var query: GFContentPackageQuery = GFContentPackageQuery.new()
	query.required_content_types = PackedStringArray(["ui"])
	query.required_metadata = {"channel": "stable"}
	query.include_dependencies = true

	var result: GFContentPackageQueryResult = catalog.query_packages(query)
	ui_manifest.display_name = "mutated outside catalog"
	var result_manifest: GFContentPackageManifest = result.get_manifest(&"author.ui")

	assert_true(result.is_successful(), "有效查询应返回成功终态。")
	assert_eq(result.get_direct_package_ids(), PackedStringArray(["author.ui"]))
	assert_eq(
		result.get_package_ids(),
		PackedStringArray(["author.base", "author.ui"]),
		"依赖闭包应按 dependency-first 顺序返回。"
	)
	assert_not_null(result_manifest)
	if result_manifest != null:
		assert_ne(result_manifest.display_name, "mutated outside catalog", "结果必须持有隔离的 manifest 快照。")


func test_query_applies_strict_filters_and_limit_before_dependency_expansion() -> void:
	var base_manifest: GFContentPackageManifest = _make_manifest(
		&"author.base",
		PackedStringArray(),
		PackedStringArray(["shared"]),
		{},
		[{"key": "base", "path": "base.tres"}]
	)
	var first_manifest: GFContentPackageManifest = _make_manifest(
		&"author.first",
		PackedStringArray(["author.base"]),
		PackedStringArray(["ui"]),
		{"channel": "stable"},
		[{"key": "first", "path": "first.tres"}]
	)
	var second_manifest: GFContentPackageManifest = _make_manifest(
		&"author.second",
		PackedStringArray(["author.base"]),
		PackedStringArray(["ui"]),
		{"channel": "stable"},
		[{"key": "second", "path": "second.tres"}]
	)
	var catalog: GFContentPackageCatalog = GFContentPackageCatalog.new().set_manifests([
		second_manifest,
		first_manifest,
		base_manifest,
	])
	var query: GFContentPackageQuery = GFContentPackageQuery.new()
	query.package_ids = PackedStringArray(["author.first", "author.second"])
	query.required_content_types = PackedStringArray(["ui"])
	query.required_resource_keys = PackedStringArray(["first"])
	query.required_metadata = {"channel": "stable"}
	query.max_results = 1
	query.include_dependencies = true

	var result: GFContentPackageQueryResult = catalog.query_packages(query)

	assert_true(result.is_successful())
	assert_eq(result.get_direct_package_ids(), PackedStringArray(["author.first"]))
	assert_eq(result.get_package_ids(), PackedStringArray(["author.base", "author.first"]))


func test_query_fails_closed_for_null_query_and_invalid_catalog_graph() -> void:
	var catalog: GFContentPackageCatalog = GFContentPackageCatalog.new()
	var invalid_manifest: GFContentPackageManifest = _make_manifest(
		&"author.invalid",
		PackedStringArray(["author.missing"]),
		PackedStringArray(),
		{},
		[]
	)
	var _manifest_added: bool = catalog.add_manifest(invalid_manifest)

	var null_result: GFContentPackageQueryResult = catalog.query_packages(null)
	var graph_result: GFContentPackageQueryResult = catalog.query_packages(GFContentPackageQuery.new())

	assert_false(null_result.is_successful(), "空 query 必须返回可诊断失败结果。")
	assert_eq(null_result.get_status(), GFContentPackageQueryResult.STATUS_INVALID_QUERY)
	assert_false(graph_result.is_successful(), "无效依赖图不应产出部分查询结果。")
	assert_eq(graph_result.get_status(), GFContentPackageQueryResult.STATUS_INVALID_CATALOG)
	assert_eq(graph_result.get_package_ids(), PackedStringArray())


func test_content_package_provider_builds_qualified_generic_asset_entries() -> void:
	var manifest: GFContentPackageManifest = _make_manifest(
		&"author.ui",
		PackedStringArray(),
		PackedStringArray(["ui"]),
		{"channel": "stable"},
		[{
			"key": "save",
			"path": "icons/save.png",
			"type_hint": "Texture2D",
			"metadata": {
				"title": "Save",
				"description": "Toolbar icon",
				"tags": PackedStringArray(["ui", "icon"]),
				"category": "interface",
				"preview_path": "icons/save_preview.png",
			},
		}]
	)
	var content_catalog: GFContentPackageCatalog = GFContentPackageCatalog.new().set_manifests([manifest])
	var provider: GFContentPackageAssetCatalogProvider = GFContentPackageAssetCatalogProvider.new()
	var configured_provider: GFContentPackageAssetCatalogProvider = provider.configure_catalog(
		content_catalog,
		&"content_packages"
	)

	var asset_catalog: GFAssetCatalog = configured_provider.build_catalog()
	var entry: GFAssetCatalogEntry = asset_catalog.get_entry(&"author.ui/save")

	assert_not_null(entry, "默认 qualified asset ID 应避免不同内容包的资源键碰撞。")
	if entry == null:
		return
	assert_eq(entry.title, "Save")
	assert_eq(entry.description, "Toolbar icon")
	assert_eq(entry.tags, PackedStringArray(["icon", "ui"]))
	assert_eq(entry.category, &"interface")
	assert_eq(entry.type_hint, "Texture2D")
	assert_eq(entry.resource_entry_ids, PackedStringArray(["save"]))
	assert_eq(entry.source_id, &"content_packages")
	assert_eq(
		GFVariantData.get_option_string_name(entry.metadata, "content_package_id"),
		&"author.ui"
	)
	assert_eq(
		GFVariantData.get_option_string_name(entry.metadata, "content_package_resource_key"),
		&"save"
	)


func test_content_package_provider_fails_closed_on_qualified_asset_id_collision() -> void:
	var nested_package_manifest: GFContentPackageManifest = _make_manifest(
		&"a/b",
		PackedStringArray(),
		PackedStringArray(),
		{},
		[{ "key": "c", "path": "c.tres" }]
	)
	var nested_resource_manifest: GFContentPackageManifest = _make_manifest(
		&"a",
		PackedStringArray(),
		PackedStringArray(),
		{},
		[{ "key": "b/c", "path": "b/c.tres" }]
	)
	var content_catalog: GFContentPackageCatalog = GFContentPackageCatalog.new().set_manifests([
		nested_package_manifest,
		nested_resource_manifest,
	])
	var provider: GFContentPackageAssetCatalogProvider = GFContentPackageAssetCatalogProvider.new()
	var _configured_provider: GFContentPackageAssetCatalogProvider = provider.configure_catalog(content_catalog)

	assert_null(
		provider.build_catalog(),
		"不同 package/resource 二元组映射到同一 asset_id 时必须拒绝整份目录，不能覆盖后返回部分结果。"
	)


func test_query_and_provider_debug_reports_are_json_safe() -> void:
	var circular_metadata: Dictionary = {}
	circular_metadata["self"] = circular_metadata
	var query: GFContentPackageQuery = GFContentPackageQuery.new()
	query.required_metadata = { "heat": NAN }
	query.metadata = {
		"resource": Resource.new(),
		"heat": INF,
		"cycle": circular_metadata,
	}
	var query_report_text: String = JSON.stringify(query.to_report_dictionary())
	var provider: GFContentPackageAssetCatalogProvider = GFContentPackageAssetCatalogProvider.new()
	var _configured_provider: GFContentPackageAssetCatalogProvider = provider.configure_catalog(
		GFContentPackageCatalog.new(),
		&"content_packages",
		query
	)
	var provider_report_text: String = JSON.stringify(provider.get_debug_snapshot())

	assert_true(query_report_text.contains("__gf_report_value__"), "query 报告应编码 Resource 和循环引用。")
	assert_true(query_report_text.contains("__gf_variant__"), "query 报告应编码非有限浮点。")
	assert_true(provider_report_text.contains("__gf_report_value__"), "Provider debug snapshot 必须消费 JSON-safe query 报告。")


func test_owner_scoped_roots_preserve_shared_roots_until_last_owner_releases() -> void:
	var utility: GFContentPackageUtility = GFContentPackageUtility.new()
	utility.init()

	assert_true(utility.register_source_root_for_owner(&"feature.a", "res://content/shared"))
	assert_true(utility.register_source_root_for_owner(&"feature.b", "res://content/shared/"))
	assert_eq(utility.get_source_roots(), PackedStringArray(["res://content/shared"]))

	assert_eq(utility.clear_owner_source_roots(&"feature.a"), 1)
	assert_eq(
		utility.get_source_roots(),
		PackedStringArray(["res://content/shared"]),
		"另一个 owner 仍持有根目录时不应移除有效来源。"
	)
	assert_eq(utility.clear_owner_source_roots(&"feature.b"), 1)
	assert_eq(utility.get_source_roots(), PackedStringArray())


func test_owner_root_replacement_is_transactional_and_legacy_scope_is_explicit() -> void:
	var utility: GFContentPackageUtility = GFContentPackageUtility.new()
	utility.init()
	var initial_report: GFValidationReport = utility.replace_owner_source_roots(
		&"feature.a",
		PackedStringArray(["res://content/a", "user://content/b"])
	)
	var rejected_report: GFValidationReport = utility.replace_owner_source_roots(
		&"feature.a",
		PackedStringArray(["res://content/new", "C:/outside"])
	)

	assert_true(initial_report.is_ok())
	assert_false(rejected_report.is_ok(), "任一无效 root 都必须拒绝整次替换。")
	assert_eq(
		utility.get_owner_source_roots(&"feature.a"),
		PackedStringArray(["res://content/a", "user://content/b"]),
		"失败替换不得破坏上一份 owner 快照。"
	)

	assert_true(utility.register_source_root("res://content/manual"))
	assert_eq(
		utility.get_owner_source_roots(GFContentPackageUtility.DEFAULT_SOURCE_ROOT_OWNER_ID),
		PackedStringArray(["res://content/manual"]),
		"旧入口只能写入明确的 manual owner scope。"
	)
	utility.clear_source_roots()
	assert_eq(utility.get_owner_source_roots(&"feature.a").size(), 2)


# --- 私有/辅助方法 ---

func _make_manifest(
	package_id: StringName,
	dependencies: PackedStringArray,
	content_types: PackedStringArray,
	metadata: Dictionary,
	resources: Array[Dictionary]
) -> GFContentPackageManifest:
	return GFContentPackageManifest.new().configure(
		package_id,
		"1.0.0",
		resources,
		String(package_id),
		content_types,
		dependencies,
		metadata,
		"res://content/%s" % String(package_id).replace(".", "_")
	)
