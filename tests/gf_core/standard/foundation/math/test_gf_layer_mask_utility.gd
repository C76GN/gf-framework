## 测试 GFLayerMaskUtility 的层名、索引和 bitmask 互转。
extends GutTest


# --- 常量 ---

const GF_LAYER_MASK_UTILITY = preload("res://addons/gf/standard/foundation/math/gf_layer_mask_utility.gd")


# --- 测试 ---

func test_names_to_mask_uses_layer_name_order() -> void:
	var layer_names: Array[String] = [
		"Player",
		"Enemy",
		"World",
		"Projectile",
	]
	var mask: int = GF_LAYER_MASK_UTILITY.names_to_mask(
		["Player", "World"],
		layer_names
	)

	assert_eq(
		mask,
		5,
		"第 1 层和第 3 层应生成 bitmask 0b0101。"
	)


func test_mask_to_names_returns_enabled_names_in_layer_order() -> void:
	var layer_names: Array[String] = [
		"Player",
		"Enemy",
		"World",
		"Projectile",
	]
	var names: PackedStringArray = GF_LAYER_MASK_UTILITY.mask_to_names(10, layer_names)

	assert_eq(
		names,
		PackedStringArray(["Enemy", "Projectile"]),
		"bitmask 应按层索引还原层名。"
	)


func test_case_insensitive_lookup_and_missing_names() -> void:
	var layer_names: Array[String] = [
		"Player",
		"Enemy",
		"World",
	]
	var mask: int = GF_LAYER_MASK_UTILITY.names_to_mask(
		["player", "WORLD"],
		layer_names,
		false
	)
	var missing: PackedStringArray = GF_LAYER_MASK_UTILITY.get_missing_names(
		[
			"enemy",
			"Unknown",
			"unknown",
		],
		layer_names,
		false
	)

	assert_eq(
		mask,
		5,
		"关闭大小写敏感后应能匹配层名。"
	)
	assert_eq(
		missing,
		PackedStringArray(["Unknown"]),
		"缺失层名报告应按首次出现顺序去重。"
	)


func test_layer_index_to_mask_rejects_invalid_indices() -> void:
	assert_eq(
		GF_LAYER_MASK_UTILITY.layer_index_to_mask(0),
		1,
		"零基索引 0 应对应第 1 层。"
	)
	assert_eq(
		GF_LAYER_MASK_UTILITY.layer_index_to_mask(31),
		1 << 31,
		"默认支持 32 层 bitmask。"
	)
	assert_eq(
		GF_LAYER_MASK_UTILITY.layer_index_to_mask(-1),
		0,
		"负索引应返回空 mask。"
	)
	assert_eq(
		GF_LAYER_MASK_UTILITY.layer_index_to_mask(32),
		0,
		"超过 32 层应返回空 mask。"
	)
	assert_false(
		GF_LAYER_MASK_UTILITY.is_layer_index_valid(4, 4),
		"自定义层数量上限应生效。"
	)


func test_mask_to_names_can_include_default_names_for_unnamed_layers() -> void:
	var names: PackedStringArray = GF_LAYER_MASK_UTILITY.mask_to_names(
		1 << 4,
		[],
		true
	)

	assert_eq(
		names,
		PackedStringArray(["Layer 5"]),
		"启用 include_unnamed 时应返回默认层名。"
	)


func test_project_physics_layer_names_rejects_invalid_dimension() -> void:
	assert_true(
		GF_LAYER_MASK_UTILITY.get_project_physics_layer_names(4).is_empty(),
		"只应支持 2D 或 3D 物理层名称。"
	)
