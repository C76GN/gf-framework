## 测试源码文本范围补丁工具。
extends GutTest


func test_apply_text_edits_supports_lsp_shaped_godot_character_ranges() -> void:
	var source_text: String = "func old():\n\treturn old\n"
	var report: Dictionary = GFSourceTextPatchTools.apply_text_edits(source_text, [
		{
			"range": {
				"start": { "line": 0, "character": 5 },
				"end": { "line": 0, "character": 8 },
			},
			"newText": "new",
		},
		GFSourceTextPatchTools.make_replacement_edit(1, 8, 1, 11, "new"),
	])

	assert_true(GFVariantData.get_option_bool(report, "ok"), "有效 edit 集合应成功应用。")
	assert_eq(
		GFVariantData.get_option_string(report, "text"),
		"func new():\n\treturn new\n",
		"范围替换应按原始文本坐标应用。"
	)
	assert_eq(GFVariantData.get_option_int(report, "applied_count"), 2, "应记录已应用 edit 数。")


func test_apply_text_edits_uses_godot_character_coordinates_for_emoji() -> void:
	var source_text: String = "a😀b\n"
	var report: Dictionary = GFSourceTextPatchTools.apply_text_edits(source_text, [
		GFSourceTextPatchTools.make_replacement_edit(0, 1, 0, 2, "X"),
	])

	assert_true(GFVariantData.get_option_bool(report, "ok"), "emoji 范围应按 Godot String 字符索引计算。")
	assert_eq(
		GFVariantData.get_option_string(report, "text"),
		"aXb\n",
		"单个 emoji 应占一个 Godot character，而不是两个 UTF-16 code units。"
	)


func test_apply_text_edits_sorts_ranges_before_applying() -> void:
	var report: Dictionary = GFSourceTextPatchTools.apply_text_edits("alpha beta gamma", [
		GFSourceTextPatchTools.make_replacement_edit(0, 11, 0, 16, "delta"),
		GFSourceTextPatchTools.make_replacement_edit(0, 0, 0, 5, "omega"),
	])

	assert_true(GFVariantData.get_option_bool(report, "ok"), "无重叠 edit 不要求调用方排序。")
	assert_eq(
		GFVariantData.get_option_string(report, "text"),
		"omega beta delta",
		"倒序应用应保持原始 offset 有效。"
	)


func test_apply_text_edits_supports_insert_and_delete_across_crlf_lines() -> void:
	var source_text: String = "a\r\nbc\r\n"
	var report: Dictionary = GFSourceTextPatchTools.apply_text_edits(source_text, [
		GFSourceTextPatchTools.make_replacement_edit(1, 1, 1, 1, "X"),
		GFSourceTextPatchTools.make_replacement_edit(0, 0, 1, 0, ""),
	])

	assert_true(GFVariantData.get_option_bool(report, "ok"), "CRLF 文本坐标应按行内容计算。")
	assert_eq(
		GFVariantData.get_option_string(report, "text"),
		"bXc\r\n",
		"跨行删除和行内插入应共用原始坐标。"
	)


func test_validate_text_edits_rejects_out_of_bounds_range() -> void:
	var report: Dictionary = GFSourceTextPatchTools.validate_text_edits("short", [
		GFSourceTextPatchTools.make_replacement_edit(0, 20, 0, 20, "x"),
	])

	assert_false(GFVariantData.get_option_bool(report, "ok"), "越界 edit 不应通过校验。")
	assert_eq(
		GFVariantData.get_option_string_name(report, "error"),
		GFSourceTextPatchTools.ERROR_RANGE_OUT_OF_BOUNDS,
		"错误类型应标记范围越界。"
	)


func test_apply_text_edits_rejects_overlapping_ranges_without_mutating_text() -> void:
	var source_text: String = "abcdef"
	var report: Dictionary = GFSourceTextPatchTools.apply_text_edits(source_text, [
		GFSourceTextPatchTools.make_replacement_edit(0, 1, 0, 4, "X"),
		GFSourceTextPatchTools.make_replacement_edit(0, 3, 0, 5, "Y"),
	])

	assert_false(GFVariantData.get_option_bool(report, "ok"), "重叠 edit 应被拒绝。")
	assert_eq(GFVariantData.get_option_string(report, "text"), source_text, "失败时不应返回半应用文本。")
	assert_eq(
		GFVariantData.get_option_string_name(report, "error"),
		GFSourceTextPatchTools.ERROR_OVERLAPPING_EDITS,
		"错误类型应标记重叠范围。"
	)


func test_make_replacement_edit_copies_metadata() -> void:
	var metadata: Dictionary = { "source": { "id": "rename" } }
	var edit: Dictionary = GFSourceTextPatchTools.make_replacement_edit(0, 0, 0, 0, "x", metadata)
	metadata["source"]["id"] = "changed"

	var edit_metadata: Dictionary = GFVariantData.get_option_dictionary(edit, "metadata")
	var source_metadata: Dictionary = GFVariantData.get_option_dictionary(edit_metadata, "source")
	assert_eq(GFVariantData.get_option_string(source_metadata, "id"), "rename", "edit metadata 应深拷贝。")
