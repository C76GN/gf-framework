## 测试 GFSaveSlotMetadata 的字典序列化、校验与深拷贝。
extends GutTest


func test_from_dict_roundtrip_preserves_fields() -> void:
	var data: Dictionary = {
		"slot_id": &"slot_a",
		"display_name": "A",
		"schema_version": 2,
		"app_version": "1.0.0",
		"elapsed_seconds": 120.5,
		"tags": PackedStringArray(["a", "b"]),
		"custom_metadata": { "k": 1 },
	}
	var meta: GFSaveSlotMetadata = GFSaveSlotMetadata.from_dict(data)
	assert_eq(meta.slot_id, &"slot_a")
	assert_eq(meta.display_name, "A")
	assert_eq(meta.schema_version, 2)
	assert_eq(meta.app_version, "1.0.0")
	assert_almost_eq(meta.elapsed_seconds, 120.5, 0.0001)
	assert_eq(meta.tags.size(), 2)
	assert_eq(GFVariantData.get_option_int(meta.custom_metadata, "k"), 1)


func test_apply_dict_clamps_schema_version_and_elapsed() -> void:
	var meta: GFSaveSlotMetadata = GFSaveSlotMetadata.new()
	meta.apply_dict({ "schema_version": 0, "elapsed_seconds": -5.0 })
	assert_eq(meta.schema_version, 1, "schema_version 应钳制到至少为 1。")
	assert_eq(meta.elapsed_seconds, 0.0, "elapsed_seconds 不应为负。")


func test_apply_dict_tags_from_generic_array() -> void:
	var meta: GFSaveSlotMetadata = GFSaveSlotMetadata.new()
	var raw: Array = ["x", "y"]
	meta.apply_dict({ "tags": raw })
	assert_eq(meta.tags.size(), 2)
	assert_eq(meta.tags[0], "x")
	assert_eq(meta.tags[1], "y")


func test_to_dict_exclude_empty_omits_default_like_fields() -> void:
	var meta: GFSaveSlotMetadata = GFSaveSlotMetadata.new()
	meta.slot_id = &"only"
	meta.display_name = ""
	meta.schema_version = 1
	meta.elapsed_seconds = 0.0
	var patch: Dictionary = meta.to_dict(false)
	assert_true(patch.has("slot_id"), "非空 slot_id 应保留。")
	assert_false(patch.has("display_name"), "空字符串字段在排除模式下可省略。")


func test_to_patch_dict_matches_to_dict_false() -> void:
	var meta: GFSaveSlotMetadata = GFSaveSlotMetadata.new()
	meta.slot_id = &"s"
	assert_eq(meta.to_patch_dict(), meta.to_dict(false))


func test_get_display_name_uses_fallback_when_empty() -> void:
	var meta: GFSaveSlotMetadata = GFSaveSlotMetadata.new()
	meta.display_name = ""
	assert_eq(meta.get_display_name("默认"), "默认", "空展示名应返回兜底文本。")
	meta.display_name = "有"
	assert_eq(meta.get_display_name("默认"), "有", "有展示名时不应使用兜底。")


func test_validate_metadata_reports_warnings_and_errors() -> void:
	var empty_id: GFSaveSlotMetadata = GFSaveSlotMetadata.new()
	empty_id.schema_version = 1
	var r0: Dictionary = empty_id.validate_metadata()
	var warning_issues: Array = GFVariantData.get_option_array(r0, "issues")
	var warning_issue: Dictionary = GFVariantData.as_dictionary(warning_issues[0])
	assert_true(GFVariantData.get_option_bool(r0, "ok"), "仅有 warning 时不应标记 ok 为 false。")
	assert_false(GFVariantData.get_option_bool(r0, "healthy"), "包含 warning 时不应视为完全健康。")
	assert_eq(GFVariantData.get_option_int(r0, "warning_count"), 1, "校验报告应统计 warning 数量。")
	assert_eq(GFVariantData.get_option_int(r0, "issue_count"), 1, "校验报告应统计问题总数。")
	assert_eq(warning_issues.size(), 1)
	assert_eq(GFVariantData.get_option_string(warning_issue, "severity"), "warning")
	assert_eq(GFVariantData.get_option_string(warning_issue, "kind"), "empty_slot_id")

	var bad_version: GFSaveSlotMetadata = GFSaveSlotMetadata.new()
	bad_version.slot_id = &"x"
	bad_version.schema_version = 0
	var r1: Dictionary = bad_version.validate_metadata()
	assert_false(GFVariantData.get_option_bool(r1, "ok"), "非法 schema_version 应标记为不通过。")
	assert_eq(GFVariantData.get_option_int(r1, "error_count"), 1, "非法 schema_version 应统计为 error。")

	var bad_elapsed: GFSaveSlotMetadata = GFSaveSlotMetadata.new()
	bad_elapsed.slot_id = &"x"
	bad_elapsed.schema_version = 1
	bad_elapsed.elapsed_seconds = -1.0
	var r2: Dictionary = bad_elapsed.validate_metadata()
	var elapsed_issues: Array = GFVariantData.get_option_array(r2, "issues")
	var elapsed_issue: Dictionary = GFVariantData.as_dictionary(elapsed_issues[0])
	assert_false(GFVariantData.get_option_bool(r2, "ok"), "负游玩时长应产生 error。")
	assert_eq(GFVariantData.get_option_string(elapsed_issue, "path"), "elapsed_seconds")


func test_duplicate_metadata_deep_copies_custom_metadata() -> void:
	var meta: GFSaveSlotMetadata = GFSaveSlotMetadata.new()
	meta.slot_id = &"copy"
	meta.custom_metadata = { "n": 1 }
	var dup: GFSaveSlotMetadata = meta.duplicate_metadata()
	dup.custom_metadata["n"] = 99
	assert_eq(GFVariantData.get_option_int(meta.custom_metadata, "n"), 1, "深拷贝不应共享 custom_metadata。")


func test_from_values_sets_slot_and_timestamps() -> void:
	var meta: GFSaveSlotMetadata = GFSaveSlotMetadata.from_values(
		&"p1",
		"标题",
		{ "x": true },
		1700000000
	)
	assert_eq(meta.slot_id, &"p1")
	assert_eq(meta.display_name, "标题")
	assert_true(GFVariantData.get_option_bool(meta.custom_metadata, "x"))
	assert_eq(meta.created_at_unix, 1700000000)
	assert_eq(meta.updated_at_unix, meta.created_at_unix)


func test_from_values_does_not_read_hidden_system_time() -> void:
	var meta: GFSaveSlotMetadata = GFSaveSlotMetadata.from_values(&"p1")

	assert_eq(meta.created_at_unix, 0, "未提供时间戳时值对象不得自行读取系统时间。")
	assert_eq(meta.updated_at_unix, 0, "未知更新时间应保持显式 0。")
