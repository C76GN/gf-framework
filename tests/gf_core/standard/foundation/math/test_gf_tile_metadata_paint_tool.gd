## 测试 GFTileMetadataPaintTool 的 patch、UndoRedo 和 overlay 辅助行为。
extends GutTest


# --- 常量 ---

const GF_TILE_METADATA_PAINT_TOOL_SCRIPT = preload("res://addons/gf/standard/foundation/math/editor/gf_tile_metadata_paint_tool.gd")


# --- 测试方法 ---

func test_make_and_apply_paint_patch_changes_only_target_cells() -> void:
	var layer: GFTileMetadataLayer = GFTileMetadataLayer.new()
	layer.set_cell_value(Vector2i(0, 0), &"blocked", false)

	var patch: Dictionary = GF_TILE_METADATA_PAINT_TOOL_SCRIPT.make_paint_patch(
		layer,
		[Vector2i(1, 0), Vector2i(0, 0), Vector2i(1, 0)],
		&"blocked",
		true
	)

	assert_true(GFVariantData.get_option_bool(patch, "ok"), "有效参数应生成可应用 patch。")
	assert_eq(GFVariantData.get_option_int(patch, "changed_count"), 2, "重复格子应去重，且只记录实际变化。")
	assert_false(GFVariantData.to_bool(layer.get_cell_value(Vector2i(0, 0), &"blocked")), "make_paint_patch 不应立即修改 layer。")

	var report: Dictionary = GF_TILE_METADATA_PAINT_TOOL_SCRIPT.apply_paint_patch(layer, patch)

	assert_true(GFVariantData.get_option_bool(report, "ok"), "apply 应成功。")
	assert_true(GFVariantData.to_bool(layer.get_cell_value(Vector2i(0, 0), &"blocked")), "已有格子字段应被绘制值覆盖。")
	assert_true(GFVariantData.to_bool(layer.get_cell_value(Vector2i(1, 0), &"blocked")), "新格子字段应被写入。")


func test_erase_patch_removes_empty_cells_and_can_revert() -> void:
	var layer: GFTileMetadataLayer = GFTileMetadataLayer.new()
	layer.set_cell_value(Vector2i(2, 2), &"flag", true)

	var patch: Dictionary = GF_TILE_METADATA_PAINT_TOOL_SCRIPT.make_paint_patch(
		layer,
		[Vector2i(2, 2)],
		&"flag",
		null,
		true
	)
	var _apply_report: Dictionary = GF_TILE_METADATA_PAINT_TOOL_SCRIPT.apply_paint_patch(layer, patch)

	assert_false(layer.has_cell(Vector2i(2, 2)), "擦除最后一个字段后应移除空格子。")

	var _revert_report: Dictionary = GF_TILE_METADATA_PAINT_TOOL_SCRIPT.revert_paint_patch(layer, patch)

	assert_true(layer.has_cell_key(Vector2i(2, 2), &"flag"), "revert 应恢复擦除前字段。")


func test_commit_paint_patch_writes_undo_redo_compatible_actions() -> void:
	var layer: GFTileMetadataLayer = GFTileMetadataLayer.new()
	var undo_manager: FakeUndoManager = FakeUndoManager.new()
	var patch: Dictionary = GF_TILE_METADATA_PAINT_TOOL_SCRIPT.make_paint_patch(
		layer,
		[Vector2i(3, 4)],
		&"cost",
		5
	)

	var commit_error: Error = GF_TILE_METADATA_PAINT_TOOL_SCRIPT.commit_paint_patch(layer, patch, undo_manager, "Paint Cost")

	assert_eq(commit_error, OK, "有效 patch 应能写入 UndoRedo 兼容对象。")
	assert_eq(undo_manager.action_name, "Paint Cost", "action 名称应传给 UndoRedo。")
	assert_eq(GFVariantData.to_int(layer.get_cell_value(Vector2i(3, 4), &"cost")), 5, "提交时应立即执行 do 侧修改。")

	undo_manager.undo()

	assert_false(layer.has_cell(Vector2i(3, 4)), "undo 应恢复 patch 前状态。")

	undo_manager.redo()

	assert_eq(GFVariantData.to_int(layer.get_cell_value(Vector2i(3, 4), &"cost")), 5, "redo 应重新应用 patch。")


func test_schema_options_and_overlay_segments_are_field_driven() -> void:
	var layer: GFTileMetadataLayer = GFTileMetadataLayer.new()
	layer.set_schema_entry(&"blocked", {
		"color": Color(1.0, 0.0, 0.0, 0.8),
		"default": true,
	})
	layer.set_schema_entry(&"cost", {
		"paint_color": "#00ff00",
		"paint_value": 3,
	})
	layer.merge_cell_data(Vector2i(0, 1), {
		"blocked": true,
		"cost": 2,
		"tag": "road",
	})

	var field_options: Array[Dictionary] = GF_TILE_METADATA_PAINT_TOOL_SCRIPT.get_schema_field_options(layer)
	var segments: Array[Dictionary] = GF_TILE_METADATA_PAINT_TOOL_SCRIPT.get_cell_overlay_segments(layer, Vector2i(0, 1), {
		"field_order": [&"cost", &"blocked"],
		"alpha": 0.5,
	})
	var configured_segments: Array[Dictionary] = GF_TILE_METADATA_PAINT_TOOL_SCRIPT.get_cell_overlay_segments(layer, Vector2i(0, 1), {
		"include_unconfigured": false,
	})

	assert_eq(GFVariantData.get_option_string_name(field_options[0], "key"), &"blocked", "schema 字段应稳定排序。")
	assert_eq(GFVariantData.get_option_string_name(field_options[1], "key"), &"cost", "schema 字段应稳定排序。")
	assert_eq(GFVariantData.to_int(GFVariantData.get_option_value(field_options[1], "value")), 3, "paint_value 应作为字段默认绘制值。")
	assert_eq(GFVariantData.get_option_string_name(segments[0], "key"), &"cost", "field_order 应优先控制 overlay 顺序。")
	assert_eq(GFVariantData.get_option_string_name(segments[1], "key"), &"blocked", "field_order 应保留配置字段顺序。")
	assert_eq(GFVariantData.get_option_string_name(segments[2], "key"), &"tag", "未配置字段默认仍可显示。")
	assert_eq(GFVariantData.get_option_int(segments[0], "count"), 3, "overlay 分段应记录总段数。")
	assert_almost_eq(GFVariantData.get_option_float(segments[0], "start_ratio"), 0.0, 0.0001, "第一段起点应为 0。")
	assert_almost_eq(GFVariantData.get_option_float(segments[0], "end_ratio"), 1.0 / 3.0, 0.0001, "第一段终点应按段数计算。")
	assert_eq(configured_segments.size(), 2, "include_unconfigured=false 时应隐藏 schema 外字段。")


# --- 内部类 ---

class FakeUndoManager:
	extends RefCounted

	var action_name: String = ""
	var do_methods: Array[Dictionary] = []
	var undo_methods: Array[Dictionary] = []

	func create_action(p_action_name: String) -> void:
		action_name = p_action_name
		do_methods.clear()
		undo_methods.clear()

	func add_do_method(target: Object, method_name: String, arg0: Variant = null, arg1: Variant = null) -> void:
		do_methods.append(_make_call(target, method_name, arg0, arg1))

	func add_undo_method(target: Object, method_name: String, arg0: Variant = null, arg1: Variant = null) -> void:
		undo_methods.append(_make_call(target, method_name, arg0, arg1))

	func commit_action(execute_immediately: bool = true) -> void:
		if execute_immediately:
			_execute_calls(do_methods)

	func undo() -> void:
		_execute_calls(undo_methods)

	func redo() -> void:
		_execute_calls(do_methods)

	func _make_call(target: Object, method_name: String, arg0: Variant, arg1: Variant) -> Dictionary:
		var args: Array = []
		if arg0 != null:
			args.append(arg0)
		if arg1 != null:
			args.append(arg1)
		return {
			"target": target,
			"method_name": method_name,
			"args": args,
		}

	func _execute_calls(calls: Array[Dictionary]) -> void:
		for call_data: Dictionary in calls:
			var target: Object = _variant_to_object(GFVariantData.get_option_value(call_data, "target"))
			if target == null:
				continue
			var method_name: StringName = GFVariantData.get_option_string_name(call_data, "method_name")
			if method_name == &"":
				continue
			var args: Array = GFVariantData.get_option_array(call_data, "args")
			var _call_result: Variant = target.callv(method_name, args)

	func _variant_to_object(value: Variant) -> Object:
		if value is Object:
			var object_value: Object = value
			return object_value
		return null
