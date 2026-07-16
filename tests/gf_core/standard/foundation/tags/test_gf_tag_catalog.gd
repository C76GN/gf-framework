## 测试可选标签目录、重定向和标签源规范化。
extends GutTest


func test_tag_catalog_registers_tags_and_redirects() -> void:
	var catalog: GFTagCatalog = GFTagCatalog.new()
	var added_tag: bool = catalog.add_tag(&"state.burning", {
		"description": "Burning state.",
	})
	var added_redirect: bool = catalog.add_redirect(&"state.fire", &"state.burning")

	assert_true(added_tag, "应能添加正式标签定义。")
	assert_true(added_redirect, "应能添加重定向定义。")
	assert_true(catalog.has_tag(&"state.burning", false), "正式标签应可查询。")
	assert_true(catalog.has_tag(&"state.fire"), "include_redirects 默认为 true 时应识别重定向源。")
	assert_false(catalog.has_tag(&"state.fire", false), "重定向源不应混入正式标签列表。")
	assert_eq(catalog.resolve_tag(&"state.fire"), &"state.burning", "重定向源应解析到目标标签。")
	assert_eq(catalog.get_tags(), PackedStringArray(["state.burning"]), "正式标签列表不应包含重定向源。")
	assert_eq(catalog.get_redirect_tags(), PackedStringArray(["state.fire"]), "重定向列表应只包含重定向源。")


func test_tag_catalog_normalizes_redirected_tag_sources() -> void:
	var catalog: GFTagCatalog = GFTagCatalog.new()
	var _added_target: bool = catalog.add_tag(&"state.burning")
	var _added_redirect: bool = catalog.add_redirect(&"state.fire", &"state.burning")
	var source: Dictionary = {
		"tag_counts": {
			&"state.fire": 2,
			&"state.burning": 1,
			&"rank.elite": 1,
		},
	}

	var normalized: GFTagSet = catalog.normalize_tag_source(source)

	assert_eq(normalized.get_tag_count(&"state.burning"), 3, "规范化时应把重定向源层数合并到目标标签。")
	assert_eq(normalized.get_tag_count(&"state.fire"), 0, "规范化结果不应保留已重定向的源标签。")
	assert_eq(normalized.get_tag_count(&"rank.elite"), 1, "默认不应丢弃未声明标签。")


func test_tag_catalog_can_drop_undefined_tags_when_normalizing() -> void:
	var catalog: GFTagCatalog = GFTagCatalog.new()
	var _added_tag: bool = catalog.add_tag(&"state.burning")
	var source: PackedStringArray = PackedStringArray(["state.burning", "state.unknown"])

	var normalized: GFTagSet = catalog.normalize_tag_source(source, {
		"drop_undefined": true,
	})

	assert_eq(normalized.get_tags(), PackedStringArray(["state.burning"]), "显式要求丢弃时，目录外标签不应进入结果。")


func test_tag_catalog_reports_undefined_tags_when_strict() -> void:
	var catalog: GFTagCatalog = GFTagCatalog.new()
	catalog.allow_undefined_tags = false
	var _added_tag: bool = catalog.add_tag(&"state.burning")
	var source: PackedStringArray = PackedStringArray(["state.burning", "state.unknown"])

	var report: GFValidationReport = catalog.validate_tag_source(source)
	var report_data: Dictionary = report.to_dict()
	var issue_counts_by_kind: Dictionary = GFVariantData.get_option_dictionary(report_data, "issue_counts_by_kind")

	assert_false(report.is_ok(), "严格目录应把目录外标签报告为错误。")
	assert_eq(GFVariantData.get_option_int(report_data, "error_count"), 1, "应报告一个未知标签错误。")
	assert_eq(GFVariantData.get_option_int(issue_counts_by_kind, &"undefined_tag"), 1, "问题类别应稳定。")


func test_tag_catalog_configure_empty_definitions_still_applies_options() -> void:
	var catalog: GFTagCatalog = GFTagCatalog.new()
	var _configured: GFTagCatalog = catalog.configure(&"combat", [], {
		"allow_undefined_tags": false,
		"metadata": {
			"domain": "combat",
		},
	})

	var report: GFValidationReport = catalog.validate_tag_source(PackedStringArray(["state.unknown"]))

	assert_false(catalog.allow_undefined_tags, "空 definitions 配置也应应用 strict 选项。")
	assert_eq(GFVariantData.get_option_string(catalog.metadata, "domain"), "combat", "空 definitions 配置也应应用 metadata。")
	assert_false(report.is_ok(), "strict 空目录应拒绝未知标签。")


func test_tag_catalog_reports_redirect_info_without_failing() -> void:
	var catalog: GFTagCatalog = GFTagCatalog.new()
	var _added_tag: bool = catalog.add_tag(&"state.burning")
	var _added_redirect: bool = catalog.add_redirect(&"state.fire", &"state.burning")

	var report: GFValidationReport = catalog.validate_tag_source(PackedStringArray(["state.fire"]))
	var report_data: Dictionary = report.to_dict()
	var issue_counts_by_kind: Dictionary = GFVariantData.get_option_dictionary(report_data, "issue_counts_by_kind")

	assert_true(report.is_ok(), "重定向提示不应导致校验失败。")
	assert_eq(GFVariantData.get_option_int(report_data, "info_count"), 1, "重定向应作为信息问题记录。")
	assert_eq(GFVariantData.get_option_int(issue_counts_by_kind, &"redirected_tag"), 1, "重定向问题类别应稳定。")


func test_tag_catalog_cache_tracks_direct_definition_metadata_changes() -> void:
	var catalog: GFTagCatalog = GFTagCatalog.new()
	var _added_tag: bool = catalog.add_tag(&"state.burning", {
		"metadata": { "severity": 1 },
	})
	var cached_definition: Dictionary = catalog.get_tag_definition(&"state.burning")
	var cached_metadata: Dictionary = GFVariantData.get_option_dictionary(cached_definition, "metadata")

	var changed_definition: Dictionary = catalog.tag_definitions[0]
	changed_definition["metadata"] = { "severity": 2 }
	catalog.tag_definitions[0] = changed_definition
	var updated_definition: Dictionary = catalog.get_tag_definition(&"state.burning")
	var updated_metadata: Dictionary = GFVariantData.get_option_dictionary(updated_definition, "metadata")

	assert_eq(GFVariantData.get_option_int(cached_metadata, "severity"), 1, "第一次读取应建立旧缓存。")
	assert_eq(GFVariantData.get_option_int(updated_metadata, "severity"), 2, "直接修改导出定义元数据后应刷新缓存。")


func test_tag_catalog_definition_validation_reports_cycles_and_missing_targets() -> void:
	var catalog: GFTagCatalog = GFTagCatalog.new()
	var _added_first_redirect: bool = catalog.add_redirect(&"old.a", &"old.b")
	var _added_second_redirect: bool = catalog.add_redirect(&"old.b", &"old.a")
	var _added_missing_target: bool = catalog.add_redirect(&"old.c", &"new.c")

	var report: GFValidationReport = catalog.validate_definition()
	var report_data: Dictionary = report.to_dict()
	var issue_counts_by_kind: Dictionary = GFVariantData.get_option_dictionary(report_data, "issue_counts_by_kind")

	assert_false(report.is_ok(), "重定向循环应让定义校验失败。")
	assert_eq(GFVariantData.get_option_int(issue_counts_by_kind, &"redirect_cycle"), 2, "循环链上的两个源标签都应报告。")
	assert_eq(GFVariantData.get_option_int(issue_counts_by_kind, &"missing_redirect_target"), 1, "缺失目标应报告为 warning。")


func test_tag_catalog_serialization_and_duplicate_keep_definitions_independent() -> void:
	var catalog: GFTagCatalog = GFTagCatalog.new()
	var _configured: GFTagCatalog = catalog.configure(&"combat", [
		{ "tag": &"state.burning", "metadata": { "severity": 2 } },
	], {
		"allow_undefined_tags": false,
		"metadata": { "domain": "combat" },
	})

	var copy: GFTagCatalog = catalog.duplicate_catalog()
	var restored: GFTagCatalog = GFTagCatalog.from_dictionary(catalog.to_dictionary())
	var _added_copy_tag: bool = copy.add_tag(&"state.frozen")

	assert_eq(restored.catalog_id, &"combat", "序列化应保留目录 ID。")
	assert_false(restored.allow_undefined_tags, "序列化应保留严格模式。")
	assert_true(restored.has_tag(&"state.burning", false), "序列化应保留标签定义。")
	assert_false(catalog.has_tag(&"state.frozen", false), "duplicate_catalog 不应共享定义数组。")
