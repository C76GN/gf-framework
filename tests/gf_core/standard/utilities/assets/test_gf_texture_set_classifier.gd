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
