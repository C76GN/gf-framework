## 测试纹理集分类和导入计划构建。
extends GutTest


const ROLE_ORM: StringName = &"orm"


func test_texture_set_classifier_groups_common_pbr_suffixes() -> void:
	var report: Dictionary = GFTextureSetClassifier.classify_files(PackedStringArray([
		"res://textures/stone_albedo.png",
		"res://textures/stone_normal.png",
		"res://textures/stone_roughness.png",
		"res://textures/stone_ORM.png",
		"res://textures/readme.txt",
	]))
	var sets: Array = GFVariantData.get_option_array(report, "sets")
	var texture_set: Dictionary = GFVariantData.as_dictionary(sets[0])
	var textures: Dictionary = GFVariantData.get_option_dictionary(texture_set, "textures")

	assert_true(GFVariantData.get_option_bool(report, "ok"), "至少匹配一个纹理集时分类应成功。")
	assert_eq(sets.size(), 1, "同一 base_name 的贴图应合并为一个集合。")
	assert_eq(GFVariantData.get_option_string(textures, GFTextureSetClassifier.ROLE_ALBEDO), "res://textures/stone_albedo.png", "albedo 后缀应识别。")
	assert_eq(GFVariantData.get_option_string(textures, GFTextureSetClassifier.ROLE_NORMAL), "res://textures/stone_normal.png", "normal 后缀应识别。")
	assert_eq(GFVariantData.get_option_string(textures, ROLE_ORM), "res://textures/stone_ORM.png", "packed ORM 后缀应识别。")
	assert_eq(GFVariantData.get_option_int(report, "unmatched_count"), 1, "不支持扩展名应进入 unmatched。")


func test_texture_set_classifier_builds_import_plan_with_source_trace() -> void:
	var plan: GFImportPlan = GFTextureSetClassifier.build_material_import_plan(PackedStringArray([
		"res://textures/wood_basecolor.png",
		"res://textures/wood_metallic.png",
		"res://textures/wood_rma.png",
	]), "res://generated/materials")
	var entries: Array[Dictionary] = plan.get_entries()
	var entry: Dictionary = entries[0]
	var trace: Dictionary = GFVariantData.get_option_dictionary(entry, "source_trace")
	var metadata: Dictionary = GFVariantData.get_option_dictionary(entry, "metadata")

	assert_eq(entries.size(), 1, "一个纹理集应生成一个导入计划条目。")
	assert_eq(GFVariantData.get_option_string(entry, "target_path"), "res://generated/materials/wood.tres", "目标材质路径应使用 base_name。")
	assert_eq(GFVariantData.get_option_string(entry, "source_format"), "texture_set", "导入计划应标记 source_format。")
	assert_eq(GFVariantData.get_option_string(trace, "set_id"), "res://textures/wood", "source trace 应保留纹理集标识。")
	assert_true(GFVariantData.get_option_dictionary(metadata, "textures").has(GFTextureSetClassifier.ROLE_METALLIC), "metadata 应包含纹理角色映射。")
	assert_true(GFVariantData.get_option_dictionary(metadata, "textures").has(ROLE_ORM), "metadata 应包含 packed ORM 角色映射。")


func test_texture_set_classifier_reports_duplicate_roles_deterministically() -> void:
	var paths: PackedStringArray = PackedStringArray([
		"res://textures/stone_normalgl.png",
		"res://textures/stone_albedo.png",
		"res://textures/stone_normaldx.png",
	])
	var reversed_paths: PackedStringArray = paths.duplicate()
	reversed_paths.reverse()

	var report: Dictionary = GFTextureSetClassifier.classify_files(paths)
	var reversed_report: Dictionary = GFTextureSetClassifier.classify_files(reversed_paths)
	var sets: Array = GFVariantData.get_option_array(report, "sets")
	var texture_set: Dictionary = GFVariantData.as_dictionary(sets[0])
	var textures: Dictionary = GFVariantData.get_option_dictionary(texture_set, "textures")
	var duplicate_roles: Array = GFVariantData.get_option_array(texture_set, "duplicate_roles")
	var duplicate_role: Dictionary = {}
	if not duplicate_roles.is_empty():
		duplicate_role = GFVariantData.as_dictionary(duplicate_roles[0])

	assert_false(GFVariantData.get_option_bool(report, "ok"), "同一纹理集的重复角色应使分类报告失败。")
	assert_eq(GFVariantData.get_option_int(report, "invalid_set_count"), 1, "含重复角色的集合应计为无效。")
	assert_eq(GFVariantData.get_option_int(report, "duplicate_role_count"), 1, "GL/DX normal 冲突应形成一个角色诊断。")
	assert_eq(duplicate_roles.size(), 1, "纹理集应包含一个重复角色详情。")
	assert_false(textures.has(GFTextureSetClassifier.ROLE_NORMAL), "歧义角色不应静默选择任一路径。")
	assert_eq(GFVariantData.get_option_string_name(duplicate_role, "role"), GFTextureSetClassifier.ROLE_NORMAL, "诊断应指出冲突角色。")
	assert_eq(GFVariantData.get_option_array(duplicate_role, "paths"), [
		"res://textures/stone_normaldx.png",
		"res://textures/stone_normalgl.png",
	], "冲突路径应稳定排序。")
	assert_eq(report, reversed_report, "分类结果不应受输入路径顺序影响。")


func test_texture_set_classifier_validates_required_roles_and_allows_partial_sets_by_default() -> void:
	var paths: PackedStringArray = PackedStringArray([
		"res://textures/brick_albedo.png",
		"res://textures/brick_normal.png",
	])
	var partial_report: Dictionary = GFTextureSetClassifier.classify_files(paths)
	var strict_report: Dictionary = GFTextureSetClassifier.classify_files(paths, {
		"required_roles": [
			GFTextureSetClassifier.ROLE_ALBEDO,
			GFTextureSetClassifier.ROLE_NORMAL,
			ROLE_ORM,
		],
	})
	var strict_sets: Array = GFVariantData.get_option_array(strict_report, "sets")
	var strict_set: Dictionary = GFVariantData.as_dictionary(strict_sets[0])

	assert_true(GFVariantData.get_option_bool(partial_report, "ok"), "未配置 required_roles 时应允许部分纹理集。")
	assert_false(GFVariantData.get_option_bool(strict_report, "ok"), "缺少必需角色时分类报告应失败。")
	assert_eq(GFVariantData.get_option_array(strict_set, "missing_roles"), [ROLE_ORM], "集合应列出缺失的必需角色。")
	assert_eq(GFVariantData.get_option_int(strict_report, "missing_role_count"), 1, "报告应汇总缺失角色数量。")


func test_texture_set_classifier_preserves_custom_rule_priority() -> void:
	var suffix_rules: Dictionary = {}
	suffix_rules[&"preferred"] = ["mask"]
	suffix_rules[&"fallback"] = ["mask"]
	var report: Dictionary = GFTextureSetClassifier.classify_files(
		PackedStringArray(["res://textures/stone_mask.png"]),
		{ "suffix_rules": suffix_rules }
	)
	var sets: Array = GFVariantData.get_option_array(report, "sets")
	var texture_set: Dictionary = GFVariantData.as_dictionary(sets[0])
	var textures: Dictionary = GFVariantData.get_option_dictionary(texture_set, "textures")

	assert_true(textures.has(&"preferred"), "重叠自定义规则应保留调用方声明的优先顺序。")
	assert_false(textures.has(&"fallback"), "分类诊断不应把自定义规则改成字母序优先。")


func test_texture_set_classifier_skips_invalid_sets_and_keeps_plan_diagnostics() -> void:
	var plan: GFImportPlan = GFTextureSetClassifier.build_material_import_plan(PackedStringArray([
		"res://textures/stone_albedo.png",
		"res://textures/stone_normalgl.png",
		"res://textures/stone_normaldx.png",
		"res://textures/wood_albedo.png",
	]), "res://generated/materials")
	var entries: Array[Dictionary] = plan.get_entries()

	assert_eq(entries.size(), 1, "导入计划只应包含通过完整性校验且无歧义的纹理集。")
	assert_eq(GFVariantData.get_option_string(entries[0], "target_path"), "res://generated/materials/wood.tres", "有效集合仍应生成计划条目。")
	assert_eq(GFVariantData.get_option_int(plan.metadata, "texture_set_count"), 2, "计划 metadata 应保留全部集合数量。")
	assert_eq(GFVariantData.get_option_int(plan.metadata, "valid_texture_set_count"), 1, "计划 metadata 应汇总有效集合。")
	assert_eq(GFVariantData.get_option_int(plan.metadata, "invalid_texture_set_count"), 1, "计划 metadata 应汇总无效集合。")
	assert_eq(GFVariantData.get_option_int(plan.metadata, "duplicate_role_count"), 1, "计划 metadata 应保留重复角色摘要。")
	assert_eq(GFVariantData.get_option_array(plan.metadata, "texture_set_issues").size(), 1, "计划 metadata 应保留可展示的集合诊断。")
