extends GutTest


# --- 常量 ---

const GF_RESOURCE_PROPERTY_PATCH_SCRIPT = preload("res://addons/gf/standard/utilities/assets/gf_resource_property_patch.gd")
const GF_RESOURCE_OVERLAY_SCRIPT = preload("res://addons/gf/standard/utilities/assets/gf_resource_overlay.gd")


# --- 测试方法 ---

func test_build_resource_duplicates_base_and_applies_declared_values() -> void:
	var base: StyleBoxFlat = StyleBoxFlat.new()
	base.bg_color = Color.BLUE
	base.corner_radius_top_left = 2
	var definitions: Array = [
		GF_RESOURCE_PROPERTY_PATCH_SCRIPT.make_definition(&"bg_color", TYPE_COLOR, {
			"group": "Fill",
		}),
		GF_RESOURCE_PROPERTY_PATCH_SCRIPT.make_definition(&"corner_radius_top_left", TYPE_INT, {
			"group": "Radius",
		}),
	]
	var patch_values: Dictionary = {
		&"bg_color": Color.RED,
		&"corner_radius_top_left": 8,
	}

	var report: Dictionary = GF_RESOURCE_PROPERTY_PATCH_SCRIPT.build_resource(base, definitions, patch_values)
	var resource: Resource = _get_resource(GFVariantData.get_option_value(report, "resource"))
	var patched: StyleBoxFlat = _get_stylebox_flat(resource)

	assert_true(GFVariantData.get_option_bool(report, "ok"), "合法补丁应成功应用。")
	assert_not_same(base, patched, "默认应复制 base resource，避免修改共享资源。")
	assert_eq(patched.bg_color, Color.RED)
	assert_eq(patched.corner_radius_top_left, 8)
	assert_eq(base.bg_color, Color.BLUE, "base resource 不应被修改。")


func test_apply_values_rejects_undefined_and_missing_properties() -> void:
	var target: StyleBoxFlat = StyleBoxFlat.new()
	var definitions: Array = [
		GF_RESOURCE_PROPERTY_PATCH_SCRIPT.make_definition(&"bg_color", TYPE_COLOR),
		GF_RESOURCE_PROPERTY_PATCH_SCRIPT.make_definition(&"not_a_property", TYPE_INT),
	]
	var patch_values: Dictionary = {
		&"bg_color": Color.GREEN,
		&"not_a_property": 1,
		&"shadow_size": 4,
	}

	var report: Dictionary = GF_RESOURCE_PROPERTY_PATCH_SCRIPT.apply_values(target, definitions, patch_values)
	var errors: Array = GFVariantData.get_option_array(report, "errors")
	var kinds: PackedStringArray = _collect_error_kinds(errors)

	assert_false(GFVariantData.get_option_bool(report, "ok"), "未声明或缺失属性应让报告失败。")
	assert_eq(GFVariantData.get_option_int(report, "applied_count"), 1)
	assert_eq(GFVariantData.get_option_int(report, "failed_count"), 2)
	assert_eq(target.bg_color, Color.GREEN)
	assert_true(kinds.has("missing_property"))
	assert_true(kinds.has("undefined_property"))


func test_make_property_list_marks_active_values_and_resource_hints() -> void:
	var definitions: Array = [
		GF_RESOURCE_PROPERTY_PATCH_SCRIPT.make_definition(&"texture", TYPE_OBJECT, {
			"hint": PROPERTY_HINT_RESOURCE_TYPE,
			"hint_string": "Texture2D",
			"group": "Resources",
		}),
	]
	var patch_values: Dictionary = {
		&"texture": ImageTexture.new(),
	}

	var entries: Array[Dictionary] = GF_RESOURCE_PROPERTY_PATCH_SCRIPT.make_property_list(definitions, patch_values, {
		"group_prefix": "Patch",
	})
	var group_entry: Dictionary = _find_entry(entries, "Patch/Resources")
	var texture_entry: Dictionary = _find_entry(entries, "texture")
	var usage: int = GFVariantData.get_option_int(texture_entry, "usage")

	assert_eq(GFVariantData.get_option_int(group_entry, "usage"), PROPERTY_USAGE_GROUP)
	assert_eq(GFVariantData.get_option_int(texture_entry, "type"), TYPE_OBJECT)
	assert_eq(GFVariantData.get_option_int(texture_entry, "hint"), PROPERTY_HINT_RESOURCE_TYPE)
	assert_eq(GFVariantData.get_option_string(texture_entry, "hint_string"), "Texture2D")
	assert_true((usage & PROPERTY_USAGE_STORAGE) != 0, "已有补丁值的属性应标记为可存储。")


func test_patch_resource_collects_and_clears_declared_values() -> void:
	var target: StyleBoxFlat = StyleBoxFlat.new()
	target.bg_color = Color.YELLOW
	var patch: Resource = GF_RESOURCE_PROPERTY_PATCH_SCRIPT.new()
	patch.set("definitions", [
		GF_RESOURCE_PROPERTY_PATCH_SCRIPT.make_definition(&"bg_color", TYPE_COLOR),
	])

	var collected: Dictionary = patch.call("collect_from", target)
	var set_result: Variant = patch.call("set_patch_value", &"bg_color", Color.PURPLE)
	var clear_result: Variant = patch.call("clear_patch_value", &"bg_color")
	var rejected_result: Variant = patch.call("set_patch_value", &"shadow_size", 4)
	var collected_color: Color = _get_color(GFVariantData.get_option_value(collected, &"bg_color"))

	assert_eq(collected_color, Color.YELLOW)
	assert_true(GFVariantData.to_bool(set_result), "已声明属性应可设置补丁值。")
	assert_true(GFVariantData.to_bool(clear_result), "已存在补丁值应可清理。")
	assert_false(GFVariantData.to_bool(rejected_result), "未声明属性不应写入补丁。")


func test_resource_overlay_applies_patch_chain_in_order_and_reports_each_patch() -> void:
	var base: StyleBoxFlat = StyleBoxFlat.new()
	base.bg_color = Color.BLUE
	base.corner_radius_top_left = 2
	var first_patch: Resource = _make_stylebox_patch({
		&"bg_color": Color.GREEN,
	})
	var second_patch: Resource = _make_stylebox_patch({
		&"bg_color": Color.RED,
		&"corner_radius_top_left": 9,
	})
	var overlay: Resource = GF_RESOURCE_OVERLAY_SCRIPT.new()
	var _configured_overlay: Variant = overlay.call("configure", base, [first_patch, second_patch], {
		"profile": "test",
	})

	var report: Dictionary = GFVariantData.as_dictionary(overlay.call("resolve"))
	var patched: StyleBoxFlat = _get_stylebox_flat(GFVariantData.get_option_value(report, "resource"))
	var patch_reports: Array = GFVariantData.get_option_array(report, "patch_reports")
	var report_metadata: Dictionary = GFVariantData.get_option_dictionary(report, "metadata")

	assert_true(GFVariantData.get_option_bool(report, "ok"), "覆盖链应成功应用。")
	assert_not_same(base, patched, "覆盖链默认应复制 base resource。")
	assert_eq(patched.bg_color, Color.RED, "后应用的补丁应覆盖同一属性。")
	assert_eq(patched.corner_radius_top_left, 9, "覆盖链应累计不同属性。")
	assert_eq(base.bg_color, Color.BLUE, "base resource 不应被覆盖链修改。")
	assert_eq(GFVariantData.get_option_int(report, "patch_count"), 2, "报告应统计有效补丁数量。")
	assert_eq(patch_reports.size(), 2, "报告应保留每个补丁的应用结果。")
	assert_eq(GFVariantData.get_option_string(report_metadata, "profile"), "test", "覆盖链 metadata 应进入报告。")


func test_apply_patch_chain_can_modify_existing_object_without_resource_overlay() -> void:
	var target: StyleBoxFlat = StyleBoxFlat.new()
	target.bg_color = Color.BLUE
	var first_patch: Resource = _make_stylebox_patch({
		&"bg_color": Color.GREEN,
	})
	var second_patch: Resource = _make_stylebox_patch({
		&"bg_color": Color.YELLOW,
	})

	var report: Dictionary = GF_RESOURCE_PROPERTY_PATCH_SCRIPT.apply_patch_chain(target, [first_patch, second_patch])

	assert_true(GFVariantData.get_option_bool(report, "ok"), "直接应用补丁链应成功。")
	assert_eq(target.bg_color, Color.YELLOW, "后应用的补丁应写入目标对象。")
	assert_eq(GFVariantData.get_option_int(report, "applied_count"), 2, "报告应累计每个补丁的写入。")


# --- 私有/辅助方法 ---

func _make_stylebox_patch(patch_values: Dictionary) -> Resource:
	var patch: Resource = GF_RESOURCE_PROPERTY_PATCH_SCRIPT.new()
	patch.set("definitions", [
		GF_RESOURCE_PROPERTY_PATCH_SCRIPT.make_definition(&"bg_color", TYPE_COLOR),
		GF_RESOURCE_PROPERTY_PATCH_SCRIPT.make_definition(&"corner_radius_top_left", TYPE_INT),
	])
	for property_path: Variant in patch_values.keys():
		var _set_result: Variant = patch.call(
			"set_patch_value",
			GFVariantData.to_string_name(property_path),
			patch_values[property_path]
		)
	return patch

func _get_resource(value: Variant) -> Resource:
	if value is Resource:
		var resource: Resource = value
		return resource
	return null


func _get_stylebox_flat(value: Variant) -> StyleBoxFlat:
	if value is StyleBoxFlat:
		var stylebox: StyleBoxFlat = value
		return stylebox
	return null


func _get_color(value: Variant) -> Color:
	if value is Color:
		var color: Color = value
		return color
	return Color.TRANSPARENT


func _collect_error_kinds(errors: Array) -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	for error_variant: Variant in errors:
		var error: Dictionary = GFVariantData.as_dictionary(error_variant)
		var kind: String = GFVariantData.get_option_string(error, "kind")
		if not kind.is_empty():
			var _appended: bool = result.append(kind)
	result.sort()
	return result


func _find_entry(entries: Array[Dictionary], property_path: String) -> Dictionary:
	for entry: Dictionary in entries:
		if GFVariantData.get_option_string(entry, "name") == property_path:
			return entry
	return {}
