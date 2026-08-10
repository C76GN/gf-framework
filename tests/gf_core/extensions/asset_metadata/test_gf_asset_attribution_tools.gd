## 测试 GFAssetAttributionTools 的归因归一、覆盖报告和通知文本。
extends GutTest

const GF_ASSET_ATTRIBUTION_TOOLS = preload("res://addons/gf/extensions/asset_metadata/runtime/gf_asset_attribution_tools.gd")


func test_normalize_attribution_accepts_common_aliases() -> void:
	var normalized: Dictionary = GF_ASSET_ATTRIBUTION_TOOLS.normalize_attribution({
		"resource_path": "res://assets/../assets\\tree.png",
		"license": " MIT ",
		"name": "Tree",
		"authors": ["A", "B"],
		"source": "https://example.test/tree",
		"metadata": {
			"pack": "demo",
		},
	})
	var metadata: Dictionary = GFVariantData.get_option_dictionary(normalized, "metadata")

	assert_eq(GFVariantData.get_option_string(normalized, "path"), "res://assets/tree.png")
	assert_eq(GFVariantData.get_option_string(normalized, "license_id"), "MIT")
	assert_eq(GFVariantData.get_option_string(normalized, "title"), "Tree")
	assert_eq(GFVariantData.get_option_string(normalized, "creator"), "A, B")
	assert_eq(GFVariantData.get_option_string(normalized, "source_url"), "https://example.test/tree")
	assert_eq(GFVariantData.get_option_string(metadata, "pack"), "demo")


func test_normalize_attribution_resolves_uid_to_canonical_resource_path() -> void:
	var script_path: String = "res://addons/gf/extensions/asset_metadata/runtime/gf_asset_attribution_tools.gd"
	var uid: int = ResourceLoader.get_resource_uid(script_path)
	assert_ne(uid, ResourceUID.INVALID_ID, "测试资源应具有稳定 UID。")

	var normalized: Dictionary = GF_ASSET_ATTRIBUTION_TOOLS.normalize_attribution({
		"path": ResourceUID.id_to_text(uid),
		"license_id": "MIT",
	})

	assert_eq(
		GFVariantData.get_option_string(normalized, "path"),
		script_path,
		"归因路径应复用统一资源身份解析，而不是保留可漂移的 UID 文本。"
	)


func test_report_accepts_asset_metadata_records() -> void:
	var record: GFAssetMetadataRecord = GFAssetMetadataRecord.new()
	var _configured: GFAssetMetadataRecord = record.configure("res://assets/tree.png", NodePath("Root"), &"node", {
		"attribution": {
			"license_id": "CC0-1.0",
			"title": "Tree",
		},
	})

	var report: Dictionary = GF_ASSET_ATTRIBUTION_TOOLS.build_attribution_report([record])
	var entries: Array = GFVariantData.get_option_array(report, "entries")
	var first_entry: Dictionary = GFVariantData.as_dictionary(entries[0])

	assert_true(GFVariantData.get_option_bool(report, "ok"), "合法 GFAssetMetadataRecord 归因应通过报告。")
	assert_eq(GFVariantData.get_option_string(first_entry, "path"), "res://assets/tree.png")
	assert_eq(GFVariantData.get_option_string(first_entry, "license_id"), "CC0-1.0")
	assert_eq(GFVariantData.get_option_string(first_entry, "subject_path"), "Root")
	assert_eq(GFVariantData.get_option_string(first_entry, "subject_kind"), "node")


func test_nested_attribution_inherits_metadata_sibling_source_path() -> void:
	var normalized: Dictionary = GF_ASSET_ATTRIBUTION_TOOLS.normalize_attribution({
		"metadata": {
			"source_path": "res://assets/tree.png",
			"subject_path": "Root",
			"subject_kind": "node",
			"attribution": {
				"license_id": "CC0-1.0",
				"title": "Tree",
			},
		},
	})

	assert_eq(GFVariantData.get_option_string(normalized, "path"), "res://assets/tree.png")
	assert_eq(GFVariantData.get_option_string(normalized, "subject_path"), "Root")
	assert_eq(GFVariantData.get_option_string(normalized, "subject_kind"), "node")


func test_report_rejects_conflicting_aliases_without_exposing_values() -> void:
	var report: Dictionary = GF_ASSET_ATTRIBUTION_TOOLS.build_attribution_report([
		{
			"path": "res://assets/tree.png",
			"license_id": "MIT",
			"license": "GPL-3.0-only",
		},
	])
	var counts: Dictionary = GFVariantData.get_option_dictionary(report, "issue_counts_by_kind")
	var issues: Array = GFVariantData.get_option_array(report, "issues")
	var conflict_issue: Dictionary = {}
	for issue_value: Variant in issues:
		var issue: Dictionary = GFVariantData.as_dictionary(issue_value)
		if GFVariantData.get_option_string(issue, "kind") == "conflicting_attribution_field":
			conflict_issue = issue
			break
	var metadata: Dictionary = GFVariantData.get_option_dictionary(conflict_issue, "metadata")
	var source_fields: PackedStringArray = GFVariantData.get_option_packed_string_array(
		metadata,
		"source_fields"
	)

	assert_false(GFVariantData.get_option_bool(report, "ok"), "矛盾的授权别名不得静默择一。")
	assert_eq(GFVariantData.get_option_int(counts, "conflicting_attribution_field"), 1)
	assert_eq(GFVariantData.get_option_int(metadata, "index"), 0)
	assert_eq(GFVariantData.get_option_string(metadata, "field_name"), "license_id")
	assert_eq(source_fields, PackedStringArray(["license_id", "license"]))
	assert_false(metadata.has("values"), "冲突诊断不得复制归因值。")
	assert_false(metadata.has("path"), "冲突诊断不得顺带复制资源路径。")


func test_report_accepts_equivalent_aliases_after_field_normalization() -> void:
	var report: Dictionary = GF_ASSET_ATTRIBUTION_TOOLS.build_attribution_report([
		{
			"path": "res://assets/./tree.png",
			"resource_path": "res://assets/tree.png",
			"license_id": " MIT ",
			"license": "MIT",
		},
	])
	var counts: Dictionary = GFVariantData.get_option_dictionary(report, "issue_counts_by_kind")

	assert_true(GFVariantData.get_option_bool(report, "ok"), "规范化后等价的别名不应误报冲突。")
	assert_eq(GFVariantData.get_option_int(counts, "conflicting_attribution_field"), 0)


func test_report_rejects_nested_and_top_level_attribution_conflicts() -> void:
	var report: Dictionary = GF_ASSET_ATTRIBUTION_TOOLS.build_attribution_report([
		{
			"license_id": "Apache-2.0",
			"metadata": {
				"attribution": {
					"path": "res://assets/tree.png",
					"license_id": "MIT",
				},
			},
		},
	])
	var counts: Dictionary = GFVariantData.get_option_dictionary(report, "issue_counts_by_kind")

	assert_false(GFVariantData.get_option_bool(report, "ok"), "嵌套与顶层归因声明冲突时报告必须失败。")
	assert_eq(GFVariantData.get_option_int(counts, "conflicting_attribution_field"), 1)


func test_report_resolves_parent_attribution_coverage() -> void:
	var report: Dictionary = GF_ASSET_ATTRIBUTION_TOOLS.build_attribution_report(
		[
			{
				"path": "res://assets/ui",
				"license_id": "CC0-1.0",
				"title": "UI Pack",
			},
		],
		PackedStringArray([
			"res://assets/ui/icon.png",
			"res://assets/audio/theme.ogg",
		])
	)
	var covered_paths: Array = GFVariantData.get_option_array(report, "covered_paths")
	var first_covered: Dictionary = GFVariantData.as_dictionary(covered_paths[0])
	var uncovered_paths: PackedStringArray = GFVariantData.get_option_packed_string_array(report, "uncovered_paths")

	assert_false(GFVariantData.get_option_bool(report, "ok"), "未覆盖资源路径应让归因报告失败。")
	assert_eq(GFVariantData.get_option_string(first_covered, "path"), "res://assets/ui/icon.png")
	assert_eq(GFVariantData.get_option_string(first_covered, "attribution_path"), "res://assets/ui")
	assert_true(GFVariantData.get_option_bool(first_covered, "inherited"), "子资源应继承父目录归因。")
	assert_eq(uncovered_paths, PackedStringArray(["res://assets/audio/theme.ogg"]))


func test_report_accounts_for_invalid_and_duplicate_resource_path_inputs() -> void:
	var report: Dictionary = GF_ASSET_ATTRIBUTION_TOOLS.build_attribution_report(
		[
			{
				"path": "res://assets/tree.png",
				"license_id": "MIT",
			},
		],
		PackedStringArray([
			"",
			" \t\r\n ",
			"res://assets/tree.png",
			"res://assets/./tree.png",
		])
	)
	var counts: Dictionary = GFVariantData.get_option_dictionary(report, "issue_counts_by_kind")
	var issues: Array = GFVariantData.get_option_array(report, "issues")
	var invalid_issue_metadata: Array[Dictionary] = []
	for issue_value: Variant in issues:
		var issue: Dictionary = GFVariantData.as_dictionary(issue_value)
		if GFVariantData.get_option_string(issue, "kind") != "invalid_resource_path":
			continue
		invalid_issue_metadata.append(GFVariantData.get_option_dictionary(issue, "metadata"))

	assert_false(GFVariantData.get_option_bool(report, "ok"), "无效覆盖输入不得从报告分母静默消失。")
	assert_eq(GFVariantData.get_option_int(report, "resource_path_input_count"), 4)
	assert_eq(GFVariantData.get_option_int(report, "resource_path_count"), 1)
	assert_eq(GFVariantData.get_option_int(report, "valid_resource_path_count"), 1)
	assert_eq(GFVariantData.get_option_int(report, "invalid_resource_path_count"), 2)
	assert_eq(GFVariantData.get_option_int(report, "duplicate_resource_path_count"), 1)
	assert_eq(GFVariantData.get_option_int(counts, "invalid_resource_path"), 2)
	assert_eq(invalid_issue_metadata.size(), 2)
	for metadata: Dictionary in invalid_issue_metadata:
		assert_true(metadata.has("input_index"), "无效路径诊断应保留输入位置。")
		assert_eq(GFVariantData.get_option_string(metadata, "reason"), "empty_after_normalization")
		assert_false(metadata.has("path"), "无效路径诊断不得复制原始路径。")
		assert_false(metadata.has("value"), "无效路径诊断不得复制原始值。")


func test_duplicate_paths_and_missing_license_are_errors() -> void:
	var report: Dictionary = GF_ASSET_ATTRIBUTION_TOOLS.build_attribution_report([
		{
			"path": "res://assets/tree.png",
			"license_id": "MIT",
		},
		{
			"path": "res://assets/tree.png",
		},
	])
	var counts: Dictionary = GFVariantData.get_option_dictionary(report, "issue_counts_by_kind")

	assert_false(GFVariantData.get_option_bool(report, "ok"), "重复路径和缺少 license_id 应报告错误。")
	assert_eq(GFVariantData.get_option_int(counts, "duplicate_attribution_path"), 1)
	assert_eq(GFVariantData.get_option_int(counts, "missing_license_id"), 1)


func test_issue_metadata_is_minimal_for_missing_license() -> void:
	var report: Dictionary = GF_ASSET_ATTRIBUTION_TOOLS.build_attribution_report([
		{
			"path": "res://assets/tree.png",
			"notice": "Long notice should stay out of issue metadata.",
			"source_url": "https://example.test/tree",
			"metadata": {
				"preview": Resource.new(),
			},
		},
	])
	var issues: Array = GFVariantData.get_option_array(report, "issues")
	var first_issue: Dictionary = GFVariantData.as_dictionary(issues[0])
	var metadata: Dictionary = GFVariantData.get_option_dictionary(first_issue, "metadata")

	assert_eq(GFVariantData.get_option_string(first_issue, "kind"), "missing_license_id")
	assert_eq(GFVariantData.get_option_int(metadata, "index"), 0)
	assert_eq(GFVariantData.get_option_string(metadata, "path"), "res://assets/tree.png")
	assert_eq(GFVariantData.get_option_string(metadata, "field_name"), "license_id")
	assert_false(metadata.has("notice"), "issue metadata 不应复制完整归因 entry。")
	assert_false(metadata.has("source_url"), "issue metadata 不应复制 source_url。")
	assert_false(metadata.has("metadata"), "issue metadata 不应复制任意嵌套 metadata。")


func test_attribution_report_entries_are_json_safe_by_default() -> void:
	var report: Dictionary = GF_ASSET_ATTRIBUTION_TOOLS.build_attribution_report([
		{
			"path": "res://assets/tree.png",
			"license_id": "MIT",
			"metadata": {
				"preview": Resource.new(),
				"offset": Vector2(1.0, 2.0),
			},
		},
	])
	var entries: Array = GFVariantData.get_option_array(report, "entries")
	var first_entry: Dictionary = GFVariantData.as_dictionary(entries[0])
	var metadata: Dictionary = GFVariantData.get_option_dictionary(first_entry, "metadata")
	var encoded_offset: Dictionary = GFVariantData.get_option_dictionary(metadata, "offset")
	var encoded_preview: Dictionary = GFVariantData.get_option_dictionary(metadata, "preview")
	var preview_marker: Dictionary = GFVariantData.get_option_dictionary(
		encoded_preview,
		"__gf_report_value__"
	)

	assert_eq(
		GFVariantData.get_option_string(preview_marker, "type"),
		"Object",
		"Resource 应由统一报告编码器转为脱敏 marker。"
	)
	assert_true(encoded_offset.has(GFVariantJsonCodec.JSON_MARKER_KEY), "Godot Variant 应编码为 JSON-safe typed marker。")
	var json_text: String = JSON.stringify(report)
	assert_true(JSON.parse_string(json_text) is Dictionary, "归因报告应可真实 JSON stringify/parse round-trip。")


func test_format_notice_text_groups_by_license() -> void:
	var report: Dictionary = GF_ASSET_ATTRIBUTION_TOOLS.build_attribution_report([
		{
			"path": "res://assets/tree.png",
			"license_id": "MIT",
			"title": "Tree",
			"creator": "Studio",
			"source_url": "https://example.test/tree",
		},
	])

	var text: String = GF_ASSET_ATTRIBUTION_TOOLS.format_notice_text(report, {
		"title": "Credits",
	})

	assert_true(text.contains("Credits"), "通知文本应包含自定义标题。")
	assert_true(text.contains("MIT"), "通知文本应按 license_id 分组。")
	assert_true(text.contains("- Tree (res://assets/tree.png)"), "通知文本应包含资产标题和路径。")
	assert_true(text.contains("Creator: Studio"), "通知文本应包含 creator。")
	assert_true(text.contains("Source: https://example.test/tree"), "通知文本应包含 source_url。")


func test_format_notice_text_preserves_structure_for_untrusted_multiline_fields() -> void:
	var report: Dictionary = GF_ASSET_ATTRIBUTION_TOOLS.build_attribution_report([
		{
			"path": "res://assets/tree.png",
			"license_id": "MIT\nForged license",
			"title": "Tree\r\n- Forged entry",
			"creator": "Studio\tTeam",
			"source_url": "https://example.test/tree" + String.chr(0x2028) + "mirror",
			"copyright": "2026" + String.chr(0x1f) + "Example",
			"notice": "First line\n- Forged notice\r\nFinal line",
		},
	])

	var text: String = GF_ASSET_ATTRIBUTION_TOOLS.format_notice_text(report, {
		"title": "Credits\nForged heading",
	})

	assert_eq(
		text,
		"Credits Forged heading\n\nMIT Forged license\n"
		+ "- Tree - Forged entry (res://assets/tree.png)\n"
		+ "  Creator: Studio Team\n"
		+ "  Source: https://example.test/tree mirror\n"
		+ "  Copyright: 2026 Example\n"
		+ "  Notice: First line\n"
		+ "    - Forged notice\n"
		+ "    Final line",
		"结构字段必须收束为单行，多行 notice 的每个续行必须固定缩进。"
	)
