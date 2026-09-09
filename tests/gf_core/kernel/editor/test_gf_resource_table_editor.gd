@tool

## 测试通用资源表格编辑器的列提取与单元格提交。
extends GutTest


const GF_VARIANT_ACCESS = preload("res://addons/gf/kernel/core/gf_variant_access.gd")


# --- 公共方法 ---

func after_each() -> void:
	await get_tree().process_frame


# --- 测试 ---

func test_build_export_columns_reads_resource_exports() -> void:
	var resource: TableResource = TableResource.new()
	var columns: Array[Dictionary] = GFResourceTableEditor.build_export_columns(resource)
	var names: PackedStringArray = PackedStringArray()
	for column: Dictionary in columns:
		var _appended: bool = names.append(GF_VARIANT_ACCESS.get_option_string(column, "name"))

	assert_true(names.has("label"), "导出列应包含 String export。")
	assert_true(names.has("amount"), "导出列应包含 int export。")


func test_scan_resource_paths_respects_resource_limit() -> void:
	var directory: String = "user://gf_resource_table_scan"
	var first_path: String = directory.path_join("first.tres")
	var second_path: String = directory.path_join("second.tres")
	var make_error: Error = DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	assert_true(make_error == OK or make_error == ERR_ALREADY_EXISTS, "测试应能创建 user:// 临时目录。")
	_write_empty_user_file(first_path)
	_write_empty_user_file(second_path)

	var paths: PackedStringArray = GFResourceTableEditor.scan_resource_paths(
		directory,
		PackedStringArray(["tres"]),
		{
			"max_resource_paths": 1,
		}
	)

	assert_eq(DirAccess.remove_absolute(ProjectSettings.globalize_path(first_path)), OK, "测试应能删除第一个临时资源。")
	assert_eq(DirAccess.remove_absolute(ProjectSettings.globalize_path(second_path)), OK, "测试应能删除第二个临时资源。")
	assert_eq(DirAccess.remove_absolute(ProjectSettings.globalize_path(directory)), OK, "测试应能删除临时目录。")

	assert_eq(paths.size(), 1, "资源路径扫描应遵守 max_resource_paths 上限。")
	assert_push_warning("[GFResourceTableEditor] scan_resource_paths 已达到 max_resource_paths=1，后续资源已跳过。")


func test_commit_cell_value_updates_resource_and_emits_signal() -> void:
	var resource: TableResource = TableResource.new()
	resource.label = "old"
	var editor: GFResourceTableEditor = GFResourceTableEditor.new()
	add_child_autofree(editor)
	watch_signals(editor)

	editor.load_resources([resource], [{
		"name": &"label",
		"type": TYPE_STRING,
	}])
	var committed: bool = editor.commit_cell_value(0, &"label", "new")

	assert_true(committed, "有效单元格应提交成功。")
	assert_eq(resource.label, "new", "提交后 Resource 属性应更新。")
	assert_signal_emitted(editor, "cell_value_committed", "提交后应发出变更信号。")


func test_commit_cell_value_rejects_type_mismatch() -> void:
	var resource: TableResource = TableResource.new()
	resource.amount = 3
	var editor: GFResourceTableEditor = GFResourceTableEditor.new()
	add_child_autofree(editor)
	watch_signals(editor)

	editor.load_resources([resource], [{
		"name": &"amount",
		"type": TYPE_INT,
	}])
	var committed: bool = editor.commit_cell_value(0, &"amount", "bad")

	assert_false(committed, "类型不匹配的单元格写入应失败。")
	assert_eq(resource.amount, 3, "写入失败不应污染 Resource 属性。")
	assert_signal_not_emitted(editor, "cell_value_committed", "写入失败不应发出提交信号。")


func test_resource_table_search_filters_visible_rows_and_commits_visible_cell() -> void:
	var first: TableResource = TableResource.new()
	first.label = "Alpha"
	first.amount = 1
	var second: TableResource = TableResource.new()
	second.label = "Beta"
	second.amount = 2
	var editor: GFResourceTableEditor = GFResourceTableEditor.new()
	add_child_autofree(editor)

	editor.load_resources([first, second], [{
		"name": &"label",
		"type": TYPE_STRING,
	}, {
		"name": &"amount",
		"type": TYPE_INT,
	}])
	editor.set_search_text("bet")
	var visible_rows: PackedInt32Array = editor.get_visible_row_indices()

	assert_eq(visible_rows, PackedInt32Array([1]), "搜索应只显示匹配的原始资源行。")
	assert_true(editor.commit_visible_cell_value(0, &"amount", 5), "可见行提交应映射到原始资源。")
	assert_eq(second.amount, 5, "可见行提交应更新匹配资源。")


func test_resource_table_commit_cell_values_is_atomic_when_preflight_fails() -> void:
	var first: TableResource = TableResource.new()
	first.label = "Alpha"
	first.amount = 1
	var second: TableResource = TableResource.new()
	second.label = "Beta"
	second.amount = 2
	var editor: GFResourceTableEditor = GFResourceTableEditor.new()
	add_child_autofree(editor)
	watch_signals(editor)
	editor.load_resources([first, second], [{
		"name": &"label",
		"type": TYPE_STRING,
	}, {
		"name": &"amount",
		"type": TYPE_INT,
	}])

	var report: Dictionary = editor.commit_cell_values([
		{ "row_index": 0, "property": &"label", "new_value": "Gamma" },
		{ "row_index": 1, "property": &"amount", "new_value": 2 },
		{ "row_index": 9, "property": &"amount", "new_value": 3 },
		{ "row_index": 0, "property": &"missing", "new_value": 1 },
	])

	assert_false(GF_VARIANT_ACCESS.get_option_bool(report, "ok"), "任一预检失败时整批提交应失败。")
	assert_eq(GF_VARIANT_ACCESS.get_option_int(report, "requested_count"), 4, "报告应记录请求数量。")
	assert_eq(GF_VARIANT_ACCESS.get_option_int(report, "applied_count"), 0, "事务失败后不得留下已应用单元格。")
	assert_eq(GF_VARIANT_ACCESS.get_option_int(report, "failed_count"), 2, "无效行和未知属性应计为失败。")
	assert_eq(GF_VARIANT_ACCESS.get_option_int(report, "issue_count"), 2)
	assert_eq(first.label, "Alpha", "后置无效条目不得让前置有效条目部分提交。")
	assert_eq(second.amount, 2, "相同值应保持不变。")
	assert_signal_not_emitted(
		editor,
		"cell_value_committed",
		"事务失败或回滚后不得发出提交信号。"
	)


func test_resource_table_commit_cell_values_rolls_back_runtime_setter_failure() -> void:
	var first: TableResource = TableResource.new()
	first.label = "Alpha"
	var second: RejectingTableResource = RejectingTableResource.new()
	second.amount_value = 2
	second.rejected_values.append(9)
	var editor: GFResourceTableEditor = GFResourceTableEditor.new()
	add_child_autofree(editor)
	watch_signals(editor)
	editor.load_resources([first, second], [{
		"name": &"label",
		"type": TYPE_STRING,
	}, {
		"name": &"amount",
		"type": TYPE_INT,
	}])

	var report: Dictionary = editor.commit_cell_values([
		{ "row_index": 0, "property": &"label", "new_value": "Gamma" },
		{ "row_index": 1, "property": &"amount", "new_value": 9 },
	])

	assert_false(
		GF_VARIANT_ACCESS.get_option_bool(report, "ok"),
		"运行期 setter 拒绝必须让资源批量事务失败。"
	)
	assert_true(
		GF_VARIANT_ACCESS.get_option_bool(report, "rolled_back"),
		"已完整恢复资源属性时报告应明确 rolled_back。"
	)
	assert_eq(GF_VARIANT_ACCESS.get_option_int(report, "applied_count"), 0)
	assert_eq(first.label, "Alpha", "前置成功写入必须回滚。")
	assert_eq(second.amount_value, 2)
	assert_signal_not_emitted(editor, "cell_value_committed")


func test_resource_table_commit_visible_cell_values_resolves_indices_before_refresh() -> void:
	var first: TableResource = TableResource.new()
	first.label = "keep-a"
	first.amount = 1
	var second: TableResource = TableResource.new()
	second.label = "keep-b"
	second.amount = 2
	var editor: GFResourceTableEditor = GFResourceTableEditor.new()
	add_child_autofree(editor)
	editor.load_resources([first, second], [{
		"name": &"label",
		"type": TYPE_STRING,
	}, {
		"name": &"amount",
		"type": TYPE_INT,
	}])
	editor.set_search_text("keep")

	var report: Dictionary = editor.commit_visible_cell_values([
		{ "visible_row_index": 0, "property": &"label", "new_value": "drop-a" },
		{ "visible_row_index": 1, "property": &"amount", "new_value": 9 },
	])

	assert_true(GF_VARIANT_ACCESS.get_option_bool(report, "ok"), "有效可见行批量提交应成功。")
	assert_eq(GF_VARIANT_ACCESS.get_option_int(report, "applied_count"), 2, "两个可见行变更都应应用。")
	assert_eq(first.label, "drop-a", "第一个可见行应仍指向提交前的 first。")
	assert_eq(second.amount, 9, "第二个可见行应仍指向提交前的 second。")
	assert_eq(editor.get_visible_row_indices(), PackedInt32Array([1]), "刷新后过滤结果应反映最终资源值。")
	assert_false(
		report.has("transaction_command"),
		"成功报告不得暴露可绕过表格副作用链的已执行命令。"
	)


func test_resource_table_empty_batches_are_successful_no_ops() -> void:
	var editor: TrackingResourceTableEditor = TrackingResourceTableEditor.new()
	add_child_autofree(editor)
	watch_signals(editor)
	var refresh_count_before: int = editor.refresh_call_count

	var reports: Array[Dictionary] = [
		editor.commit_cell_values([]),
		editor.commit_visible_cell_values([]),
	]

	for report: Dictionary in reports:
		assert_true(GF_VARIANT_ACCESS.get_option_bool(report, "ok"), "空批次应是成功恒等操作。")
		assert_eq(
			GF_VARIANT_ACCESS.get_option_string_name(report, "status"),
			&"committed",
			"空批次应报告 committed。"
		)
		assert_eq(GF_VARIANT_ACCESS.get_option_int(report, "error"), OK)
		assert_eq(GF_VARIANT_ACCESS.get_option_int(report, "requested_count"), 0)
		assert_eq(GF_VARIANT_ACCESS.get_option_int(report, "applied_count"), 0)
		assert_eq(GF_VARIANT_ACCESS.get_option_int(report, "unchanged_count"), 0)
		assert_eq(GF_VARIANT_ACCESS.get_option_int(report, "failed_count"), 0)
		assert_eq(GF_VARIANT_ACCESS.get_option_int(report, "issue_count"), 0)
		assert_eq(GF_VARIANT_ACCESS.as_array(report.get("committed", [])), [])
		assert_eq(GF_VARIANT_ACCESS.as_array(report.get("errors", [])), [])
		assert_false(report.has("transaction_command"), "空批次不得暴露事务命令。")
	assert_eq(editor.refresh_call_count, refresh_count_before, "空批次不得刷新表格。")
	assert_signal_not_emitted(editor, "cell_value_committed", "空批次不得发出单元格提交信号。")


func test_resource_table_unchanged_commits_are_side_effect_free() -> void:
	var resource: RejectingTableResource = RejectingTableResource.new()
	resource.ratio_value = 3.0
	var editor: TrackingResourceTableEditor = TrackingResourceTableEditor.new()
	add_child_autofree(editor)
	editor.load_resources([resource], [{
		"name": &"ratio",
		"type": TYPE_FLOAT,
	}])
	watch_signals(editor)
	var refresh_count_before: int = editor.refresh_call_count

	var raw_committed: bool = editor.commit_cell_value(0, &"ratio", 3)
	var visible_committed: bool = editor.commit_visible_cell_value(0, &"ratio", 3)
	var raw_batch: Dictionary = editor.commit_cell_values([
		{ "row_index": 0, "property": &"ratio", "new_value": 3 },
	])
	var visible_batch: Dictionary = editor.commit_visible_cell_values([
		{ "visible_row_index": 0, "property": &"ratio", "new_value": 3 },
	])

	assert_true(raw_committed, "原始行规范化后同值的提交应成功。")
	assert_true(visible_committed, "可见行规范化后同值的提交应成功。")
	for report: Dictionary in [raw_batch, visible_batch]:
		assert_true(GF_VARIANT_ACCESS.get_option_bool(report, "ok"), "规范化后同值的批次应成功。")
		assert_eq(GF_VARIANT_ACCESS.get_option_int(report, "requested_count"), 1)
		assert_eq(GF_VARIANT_ACCESS.get_option_int(report, "applied_count"), 0)
		assert_eq(GF_VARIANT_ACCESS.get_option_int(report, "unchanged_count"), 1)
		assert_eq(GF_VARIANT_ACCESS.get_option_int(report, "failed_count"), 0)
	assert_eq(resource.ratio_value, 3.0)
	assert_eq(resource.ratio_setter_call_count, 0, "所有规范化后同值入口都不得调用 setter。")
	assert_eq(editor.refresh_call_count, refresh_count_before, "同值提交不得刷新表格。")
	assert_signal_not_emitted(editor, "cell_value_committed", "同值提交不得发出变更信号。")


func test_resource_table_uses_transaction_status_for_equivalent_variant_values() -> void:
	var resource: RejectingTableResource = RejectingTableResource.new()
	resource.variant_value = &"same"
	var editor: TrackingResourceTableEditor = TrackingResourceTableEditor.new()
	add_child_autofree(editor)
	editor.load_resources([resource], [{
		"name": &"variant_value",
		"type": TYPE_NIL,
	}])
	watch_signals(editor)
	var refresh_count_before: int = editor.refresh_call_count

	var report: Dictionary = editor.commit_cell_values([
		{ "row_index": 0, "property": &"variant_value", "new_value": "same" },
	])

	assert_true(GF_VARIANT_ACCESS.get_option_bool(report, "ok"))
	assert_eq(GF_VARIANT_ACCESS.get_option_int(report, "applied_count"), 0)
	assert_eq(GF_VARIANT_ACCESS.get_option_int(report, "unchanged_count"), 1)
	assert_eq(typeof(resource.variant_value), TYPE_STRING_NAME)
	assert_eq(str(resource.variant_value), "same")
	assert_eq(resource.variant_setter_call_count, 0, "事务判定等价的 Variant 不得调用 setter。")
	assert_eq(editor.refresh_call_count, refresh_count_before, "事务判定等价的 Variant 不得刷新表格。")
	assert_signal_not_emitted(
		editor,
		"cell_value_committed",
		"事务判定等价的 Variant 不得被适配层重新解释为实际变化。"
	)


func test_resource_table_no_op_commits_do_not_auto_save_resources() -> void:
	var path: String = "user://gf_resource_table_no_op_auto_save.tres"
	var resource: GFConfigTableColumn = GFConfigTableColumn.new()
	resource.field_name = &"same"
	resource.metadata = { "state": "persisted" }
	assert_eq(ResourceSaver.save(resource, path), OK, "测试资源应能先保存到 user://。")

	var loaded: GFConfigTableColumn = _as_config_table_column(
		ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
	)
	loaded.metadata = { "state": "dirty" }
	var editor: TrackingResourceTableEditor = TrackingResourceTableEditor.new()
	add_child_autofree(editor)
	editor.auto_save_committed_resources = true
	editor.load_resources([loaded], [{
		"name": &"field_name",
		"type": TYPE_STRING_NAME,
	}])
	watch_signals(editor)
	var refresh_count_before: int = editor.refresh_call_count

	var empty_reports: Array[Dictionary] = [
		editor.commit_cell_values([]),
		editor.commit_visible_cell_values([]),
	]
	var raw_committed: bool = editor.commit_cell_value(0, &"field_name", "same")
	var visible_committed: bool = editor.commit_visible_cell_value(0, &"field_name", "same")
	var unchanged_reports: Array[Dictionary] = [
		editor.commit_cell_values([
			{ "row_index": 0, "property": &"field_name", "new_value": "same" },
		]),
		editor.commit_visible_cell_values([
			{ "visible_row_index": 0, "property": &"field_name", "new_value": "same" },
		]),
	]
	var reloaded: GFConfigTableColumn = _as_config_table_column(
		ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
	)
	assert_eq(
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path)),
		OK,
		"测试应能删除同值自动保存临时资源。"
	)

	for report: Dictionary in empty_reports:
		assert_true(GF_VARIANT_ACCESS.get_option_bool(report, "ok"), "空批次应保持成功。")
	for report: Dictionary in unchanged_reports:
		assert_true(GF_VARIANT_ACCESS.get_option_bool(report, "ok"), "同值批次应保持成功。")
		assert_eq(GF_VARIANT_ACCESS.get_option_int(report, "unchanged_count"), 1)
	assert_true(raw_committed)
	assert_true(visible_committed)
	assert_eq(
		GF_VARIANT_ACCESS.get_option_string(reloaded.metadata, "state"),
		"persisted",
		"空批次和规范化后同值提交不得把内存脏状态自动保存到资源文件。"
	)
	assert_eq(editor.refresh_call_count, refresh_count_before, "no-op 提交不得刷新表格。")
	assert_signal_not_emitted(editor, "cell_value_committed", "no-op 提交不得发出变更信号。")


func test_resource_table_failure_counts_unique_changes_and_exposes_only_recovery_handle() -> void:
	var first: RejectingTableResource = RejectingTableResource.new()
	first.amount_value = 1
	first.rejected_values.append(1)
	var second: RejectingTableResource = RejectingTableResource.new()
	second.amount_value = 2
	second.rejected_values.append(9)
	var editor: GFResourceTableEditor = GFResourceTableEditor.new()
	add_child_autofree(editor)
	editor.load_resources([first, second], [{
		"name": &"amount",
		"type": TYPE_INT,
	}])

	var report: Dictionary = editor.commit_cell_values([
		{ "row_index": 0, "property": &"amount", "new_value": 5 },
		{ "row_index": 1, "property": &"amount", "new_value": 9 },
	])

	assert_false(GF_VARIANT_ACCESS.get_option_bool(report, "ok"))
	assert_true(
		GF_VARIANT_ACCESS.get_option_bool(report, "recovery_required"),
		"回滚 setter 拒绝必须留下显式恢复句柄。"
	)
	assert_eq(
		GF_VARIANT_ACCESS.get_option_int(report, "failed_count"),
		2,
		"同一变更的补偿与终态问题只能计为一个失败变更。"
	)
	assert_gt(
		GF_VARIANT_ACCESS.get_option_int(report, "issue_count"),
		GF_VARIANT_ACCESS.get_option_int(report, "failed_count"),
		"issue_count 应保留同一变更上的多个诊断问题。"
	)
	assert_true(
		report.has("transaction_command"),
		"仅不完整回滚应暴露可显式恢复的事务句柄。"
	)


func test_resource_table_supports_sort_duplicate_move_and_remove() -> void:
	var first: TableResource = TableResource.new()
	first.label = "First"
	first.amount = 2
	var second: TableResource = TableResource.new()
	second.label = "Second"
	second.amount = 1
	var editor: GFResourceTableEditor = GFResourceTableEditor.new()
	add_child_autofree(editor)
	watch_signals(editor)
	editor.load_resources([first, second], [{
		"name": &"amount",
		"type": TYPE_INT,
	}])

	editor.sort_by_property(&"amount")
	var sorted: Array[Resource] = editor.get_resources()
	var duplicated_resource: Resource = editor.duplicate_resource(0)
	assert_true(editor.move_resource(2, 1), "资源应可移动到指定位置。")
	var removed: Resource = editor.remove_resource(0)
	var duplicated_table_resource: TableResource = _as_table_resource(duplicated_resource)

	assert_same(sorted[0], second, "排序应按属性升序排列。")
	assert_not_null(duplicated_resource, "复制资源应返回新 Resource。")
	assert_eq(duplicated_table_resource.amount, second.amount, "复制资源应保留字段值。")
	assert_same(removed, second, "移除应返回被移除的资源。")
	assert_signal_emitted(editor, "resources_reordered", "排序或移动后应发出重排信号。")
	assert_signal_emitted(editor, "resource_inserted", "复制资源后应发出插入信号。")
	assert_signal_emitted(editor, "resource_removed", "移除资源后应发出移除信号。")


func test_editor_value_field_keeps_value_when_json_is_invalid() -> void:
	var field: GFEditorValueField = GFEditorValueField.new()
	add_child_autofree(field)
	watch_signals(field)

	field.configure({ "name": &"metadata", "type": TYPE_DICTIONARY }, { "safe": true })
	var line_edit: LineEdit = _as_line_edit(field._editor)
	line_edit.text = "{bad"
	field._on_text_changed("{bad")

	assert_eq(GF_VARIANT_ACCESS.as_dictionary(field.get_value()), { "safe": true }, "JSON 解析失败时应保留旧值。")
	assert_signal_emitted(field, "value_parse_failed", "JSON 解析失败应发出失败信号。")
	assert_signal_not_emitted(field, "value_changed", "JSON 解析失败不应提交新值。")


func test_editor_value_field_rejects_json_with_wrong_container_type() -> void:
	var field: GFEditorValueField = GFEditorValueField.new()
	add_child_autofree(field)
	watch_signals(field)

	field.configure({ "name": &"metadata", "type": TYPE_DICTIONARY }, { "safe": true })
	var line_edit: LineEdit = _as_line_edit(field._editor)
	line_edit.text = "[]"
	field._on_text_changed("[]")

	assert_eq(GF_VARIANT_ACCESS.as_dictionary(field.get_value()), { "safe": true }, "Dictionary 字段不应接受 Array JSON。")
	assert_signal_emitted(field, "value_parse_failed", "JSON 容器类型不匹配应发出失败信号。")
	assert_signal_not_emitted(field, "value_changed", "JSON 容器类型不匹配不应提交新值。")


func test_editor_value_field_supports_enum_values() -> void:
	var field: GFEditorValueField = GFEditorValueField.new()
	add_child_autofree(field)
	watch_signals(field)
	field.configure({
		"name": &"mode",
		"type": TYPE_INT,
		"hint": PROPERTY_HINT_ENUM,
		"hint_string": "Idle:1,Run:2",
	}, 1)
	var option_button: OptionButton = _as_option_button(field._editor)

	option_button.select(1)
	field._on_enum_item_selected(1)
	var selected_mode: int = GF_VARIANT_ACCESS.to_int(field.get_value())

	assert_eq(selected_mode, 2, "枚举字段应读取选中项 ID。")
	assert_signal_emitted(field, "value_changed", "枚举变化应发出 value_changed。")


func test_editor_value_field_supports_vector_values() -> void:
	var field: GFEditorValueField = GFEditorValueField.new()
	add_child_autofree(field)
	field.configure({ "name": &"offset", "type": TYPE_VECTOR2 }, Vector2(1.0, 2.0))
	var vector_editor: HBoxContainer = _as_hbox_container(field._editor)
	var x_spin: SpinBox = _as_spin_box(vector_editor.get_child(0))
	var y_spin: SpinBox = _as_spin_box(vector_editor.get_child(1))

	x_spin.value = 3.5
	y_spin.value = 4.5
	field._on_vector_component_changed(4.5)
	var offset_value: Vector2 = _variant_to_vector2(field.get_value())

	assert_eq(offset_value, Vector2(3.5, 4.5), "Vector2 字段应从分量控件读取值。")


func test_unbounded_numeric_fields_preserve_negative_and_large_values() -> void:
	for sample: Variant in [-125, 256, -125.5, 256.25]:
		var field: GFEditorValueField = GFEditorValueField.new()
		add_child_autofree(field)
		field.configure({"name": &"number", "type": typeof(sample)}, sample)
		var inputs: Array[SpinBox] = _find_input_spins(field)
		assert_eq(inputs.size(), 1)
		if inputs.size() != 1:
			continue
		assert_true(sample is int or sample is float)
		var numeric_sample: float = GF_VARIANT_ACCESS.to_float(sample)
		assert_eq(inputs[0].value, numeric_sample, "无范围提示时控件必须保留原始数值。")
		assert_eq(typeof(field.get_value()), typeof(sample))
		var original_matches: bool = field.get_value() == sample
		assert_true(original_matches, "读取不得隐式截断到 0..100。")
		inputs[0].value = -512.0 if numeric_sample > 0.0 else 512.0
		var edited_matches: bool = field.get_value() == inputs[0].value
		assert_true(edited_matches)
		assert_eq(absf(inputs[0].value), 512.0, "实际输入也应允许超出默认范围。")
		field.set_value(sample)
		var restored_matches: bool = field.get_value() == sample
		assert_true(restored_matches, "程序赋值应恢复完整数值。")


func test_all_vector_fields_preserve_unbounded_components_and_integer_types() -> void:
	var cases: Array[Dictionary] = [
		{"value": Vector2(-12.5, 256.25), "edited": Vector2(512.5, -256.25)},
		{"value": Vector2i(-12, 256), "edited": Vector2i(512, -256)},
		{"value": Vector3(-12.5, 256.25, -8.5), "edited": Vector3(512.5, -256.25, -8.5)},
		{"value": Vector3i(-12, 256, -8), "edited": Vector3i(512, -256, -8)},
		{"value": Vector4(-12.5, 256.25, -8.5, 1024.25), "edited": Vector4(512.5, -256.25, -8.5, 1024.25)},
		{"value": Vector4i(-12, 256, -8, 1024), "edited": Vector4i(512, -256, -8, 1024)},
	]
	for sample: Dictionary in cases:
		var original: Variant = sample["value"]
		var expected: Variant = sample["edited"]
		var integer_components: bool = typeof(original) in [TYPE_VECTOR2I, TYPE_VECTOR3I, TYPE_VECTOR4I]
		var field: GFEditorValueField = GFEditorValueField.new()
		add_child_autofree(field)
		field.configure({"name": &"position", "type": typeof(original)}, original)
		var inputs: Array[SpinBox] = _find_input_spins(field)
		var components: PackedFloat64Array = PackedFloat64Array(
			[-12.0, 256.0, -8.0, 1024.0] if integer_components else [-12.5, 256.25, -8.5, 1024.25]
		)
		var component_count: int = 2 if typeof(original) in [TYPE_VECTOR2, TYPE_VECTOR2I] else 3 if typeof(original) in [TYPE_VECTOR3, TYPE_VECTOR3I] else 4
		assert_eq(inputs.size(), component_count)
		if inputs.size() != component_count:
			continue
		for index: int in range(component_count):
			assert_eq(inputs[index].value, components[index], "每个实际分量控件都必须保留原值。")
		assert_eq(typeof(field.get_value()), typeof(original))
		var original_matches: bool = field.get_value() == original
		assert_true(original_matches)
		inputs[0].value = 512.0 if integer_components else 512.5
		inputs[1].value = -256.0 if integer_components else -256.25
		assert_eq(typeof(field.get_value()), typeof(original))
		var edited_matches: bool = field.get_value() == expected
		assert_true(edited_matches, "编辑 x/y 不得截断值或改变其余分量。")


func test_explicit_numeric_ranges_still_constrain_inputs() -> void:
	for sample: Variant in [0, 0.0, Vector2.ZERO]:
		var field: GFEditorValueField = GFEditorValueField.new()
		add_child_autofree(field)
		field.configure({
			"name": &"bounded", "type": typeof(sample),
			"hint": PROPERTY_HINT_RANGE, "hint_string": "-10,10,1",
		}, sample)
		var inputs: Array[SpinBox] = _find_input_spins(field)
		assert_false(inputs.is_empty())
		for input: SpinBox in inputs:
			input.value = -256.0
			assert_eq(input.value, -10.0, "显式最小值仍应约束输入。")
			input.value = 256.0
			assert_eq(input.value, 10.0, "显式最大值仍应约束输入。")
		var bounded_value_matches: bool = field.get_value() == Vector2(10, 10) if sample is Vector2 else field.get_value() == 10
		assert_true(bounded_value_matches)


func test_multi_vector_original_components_apply_without_clamping_and_revert() -> void:
	for property: StringName in [&"vector", &"integer_vector"]:
		var first: InputRangeResource = InputRangeResource.new()
		var second: InputRangeResource = InputRangeResource.new()
		second.vector = Vector4(-20.5, 512.25, -31.5, 2048.25)
		second.integer_vector = Vector4i(-20, 512, -31, 2048)
		var original_first: Variant = first.get(property)
		var original_second: Variant = second.get(property)
		var field: GFEditorMultiPropertyField = GFEditorMultiPropertyField.new()
		add_child_autofree(field)
		field.configure([first, second], property)
		var edit_x: CheckBox = _find_component_toggle(field, "x")
		var edit_y: CheckBox = _find_component_toggle(field, "y")
		if edit_x == null or edit_y == null:
			continue
		edit_x.button_pressed = true
		edit_y.button_pressed = true
		var prepared: Dictionary = field.prepare_changes()
		assert_true(GF_VARIANT_ACCESS.get_option_bool(prepared, "ok"))
		var first_matches: bool = first.get(property) == original_first
		var second_matches: bool = second.get(property) == original_second
		assert_true(first_matches, "勾选和准备不得写入对象。")
		assert_true(second_matches)
		var changes: Array[Dictionary] = _prepared_input_changes(prepared)
		assert_eq(changes.size(), 4, "两目标仅准备勾选的 x/y 分量。")
		var command: GFEditorPropertyBatchCommand = GFEditorPropertyBatchCommand.new().configure(changes)
		assert_eq(command.execute(), OK)
		first_matches = first.get(property) == original_first
		assert_true(first_matches, "勾选未经改动的原值不得截断第一目标。")
		if property == &"vector":
			assert_eq(second.vector, Vector4(-12.5, 256.25, -31.5, 2048.25))
		else:
			assert_eq(second.integer_vector, Vector4i(-12, 256, -31, 2048))
		assert_eq(command.revert(), OK)
		first_matches = first.get(property) == original_first
		second_matches = second.get(property) == original_second
		assert_true(first_matches)
		assert_true(second_matches, "撤销应恢复各自原始分量。")


func test_multiline_value_field_preserves_text_and_distinguishes_sync_from_user_input() -> void:
	var field: GFEditorValueField = GFEditorValueField.new()
	add_child_autofree(field)
	field.set_debounce_seconds(0.1)
	watch_signals(field)
	var original: String = "\nfirst\n\nlast\n"
	field.configure({
		"name": &"prose", "type": TYPE_STRING, "hint": PROPERTY_HINT_MULTILINE_TEXT,
	}, original)
	var input: TextEdit = _find_text_input(field)
	if input == null:
		return
	await get_tree().process_frame
	await get_tree().process_frame
	assert_eq(input.text, original)
	assert_eq(_input_string(field.get_value()), original)
	assert_signal_not_emitted(field, "value_changed", "configure 过帧后仍不得被解释为用户编辑。")
	assert_signal_not_emitted(field, "debounced_value_changed")
	var replacement: String = "\nreplacement\n\n尾行\n\n"
	field.set_value(replacement)
	await get_tree().process_frame
	await get_tree().process_frame
	assert_eq(input.text, replacement)
	assert_eq(_input_string(field.get_value()), replacement)
	assert_signal_not_emitted(field, "value_changed", "set_value 应静默保留首尾换行与空行。")
	assert_signal_not_emitted(field, "debounced_value_changed")
	field.set_editable(false)
	assert_false(input.editable)
	field.set_editable(true)
	assert_true(input.editable)
	input.set_caret_line(0)
	input.set_caret_column(0)
	input.insert_text_at_caret("编辑\n")
	input.insert_text_at_caret("追加\n")
	var expected: String = "编辑\n追加\n" + replacement
	await get_tree().process_frame
	assert_eq(_input_string(field.get_value()), expected)
	assert_signal_emitted_with_parameters(field, "value_changed", [expected])
	await get_tree().create_timer(0.15).timeout
	assert_signal_emitted_with_parameters(field, "debounced_value_changed", [expected])
	assert_signal_emit_count(field, "debounced_value_changed", 1, "连续原生编辑应合并防抖通知。")


func test_multiline_queued_input_is_discarded_when_reconfigured_to_a_number() -> void:
	var field: GFEditorValueField = GFEditorValueField.new()
	add_child_autofree(field)
	field.set_debounce_seconds(0.0)
	field.configure({
		"name": &"prose", "type": TYPE_STRING, "hint": PROPERTY_HINT_MULTILINE_TEXT,
	}, "original\n")
	var input: TextEdit = _find_text_input(field)
	if input == null:
		return
	await get_tree().process_frame
	await get_tree().process_frame
	watch_signals(field)
	input.insert_text_at_caret("late\n")
	field.configure({"name": &"amount", "type": TYPE_INT}, 250)
	await get_tree().process_frame
	await get_tree().process_frame
	assert_true(field.get_value() is int)
	assert_eq(GF_VARIANT_ACCESS.to_int(field.get_value()), 250)
	assert_signal_not_emitted(field, "value_changed", "旧 TextEdit 的迟到事件不得提交新数值字段。")
	assert_signal_not_emitted(field, "debounced_value_changed")
	var current_inputs: Array[SpinBox] = _find_input_spins(field)
	assert_eq(current_inputs.size(), 1)
	if current_inputs.size() != 1:
		return
	current_inputs[0].value = 300.0
	await get_tree().process_frame
	await get_tree().process_frame
	assert_true(field.get_value() is int)
	assert_eq(GF_VARIANT_ACCESS.to_int(field.get_value()), 300)
	assert_signal_emitted_with_parameters(field, "value_changed", [300])
	assert_signal_emitted_with_parameters(field, "debounced_value_changed", [300])
	assert_signal_emit_count(field, "value_changed", 1)
	assert_signal_emit_count(field, "debounced_value_changed", 1)


func test_multiline_programmatic_value_supersedes_queued_input_without_disabling_edits() -> void:
	var field: GFEditorValueField = GFEditorValueField.new()
	add_child_autofree(field)
	field.set_debounce_seconds(0.0)
	field.configure({
		"name": &"prose", "type": TYPE_STRING, "hint": PROPERTY_HINT_MULTILINE_TEXT,
	}, "original\n")
	var input: TextEdit = _find_text_input(field)
	if input == null:
		return
	await get_tree().process_frame
	await get_tree().process_frame
	watch_signals(field)
	input.insert_text_at_caret("late\n")
	var replacement: String = "\nreplacement\n\n"
	field.set_value(replacement)
	await get_tree().process_frame
	await get_tree().process_frame
	assert_eq(_input_string(field.get_value()), replacement)
	assert_signal_not_emitted(field, "value_changed", "程序赋值应取代尚未派发的用户输入。")
	assert_signal_not_emitted(field, "debounced_value_changed")
	var current_input: TextEdit = _find_text_input(field)
	if current_input == null:
		return
	assert_eq(current_input.text, replacement)
	current_input.set_caret_line(0)
	current_input.set_caret_column(0)
	current_input.insert_text_at_caret("current\n")
	var expected: String = "current\n" + replacement
	await get_tree().process_frame
	await get_tree().process_frame
	assert_eq(_input_string(field.get_value()), expected)
	assert_signal_emitted_with_parameters(field, "value_changed", [expected])
	assert_signal_emitted_with_parameters(field, "debounced_value_changed", [expected])
	assert_signal_emit_count(field, "value_changed", 1)
	assert_signal_emit_count(field, "debounced_value_changed", 1)


func test_multi_multiline_text_applies_reverts_and_cancels_without_late_drafts() -> void:
	var first: InputRangeResource = InputRangeResource.new()
	var second: InputRangeResource = InputRangeResource.new()
	var original_first: String = "\nfirst\n\n尾行\n"
	var original_second: String = "\n\nsecond\n另一行\n\n"
	first.prose = original_first
	second.prose = original_second
	var field: GFEditorMultiPropertyField = GFEditorMultiPropertyField.new()
	add_child_autofree(field)
	field.configure([first, second], &"prose")
	var input: TextEdit = _find_text_input(field)
	if input == null:
		return
	await get_tree().process_frame
	await get_tree().process_frame
	assert_eq(input.text, original_first)
	assert_eq(GF_VARIANT_ACCESS.get_option_string(field.get_snapshot(), "status"), "mixed")
	assert_false(GF_VARIANT_ACCESS.get_option_bool(field.get_snapshot(), "dirty"))
	input.set_caret_line(0)
	input.set_caret_column(0)
	input.insert_text_at_caret("共同\n")
	await get_tree().process_frame
	var expected: String = "共同\n" + original_first
	assert_eq(first.prose, original_first, "多行输入仅暂存。")
	assert_eq(second.prose, original_second)
	var prepared: Dictionary = field.prepare_changes()
	assert_true(GF_VARIANT_ACCESS.get_option_bool(prepared, "ok"))
	var changes: Array[Dictionary] = _prepared_input_changes(prepared)
	assert_eq(changes.size(), 2)
	var command: GFEditorPropertyBatchCommand = GFEditorPropertyBatchCommand.new().configure(changes)
	assert_eq(command.execute(), OK)
	assert_eq(first.prose, expected)
	assert_eq(second.prose, expected)
	assert_eq(command.revert(), OK)
	assert_eq(first.prose, original_first)
	assert_eq(second.prose, original_second, "撤销必须恢复两份不同的完整多行原文。")
	input.insert_text_at_caret("应取消\n")
	field.cancel_edit()
	await get_tree().process_frame
	await get_tree().process_frame
	var restored: TextEdit = _find_text_input(field)
	if restored == null:
		return
	assert_eq(restored.text, original_first)
	assert_false(GF_VARIANT_ACCESS.get_option_bool(field.get_snapshot(), "dirty"), "重建输入及旧控件迟到事件不得产生草稿。")
	assert_true(_prepared_input_changes(field.prepare_changes()).is_empty())
	assert_eq(first.prose, original_first)
	assert_eq(second.prose, original_second)


func test_editor_value_field_custom_factory_and_debounce_signal() -> void:
	var field: GFEditorValueField = GFEditorValueField.new()
	add_child_autofree(field)
	watch_signals(field)
	field.debounce_seconds = 0.0
	assert_true(field.register_editor_factory(TYPE_STRING, func(_property_info: Dictionary, value: Variant) -> Control:
		var control: CustomValueControl = CustomValueControl.new()
		control.set_value(value)
		return control
	), "有效工厂应注册成功。")

	field.configure({ "name": &"custom", "type": TYPE_STRING }, "old")
	var custom_control: CustomValueControl = _as_custom_value_control(field._editor)
	custom_control.push_value("new")
	field.set_editable(false)
	var custom_value: String = GF_VARIANT_ACCESS.to_text(field.get_value())

	assert_eq(custom_value, "new", "自定义控件应通过 get_value 参与读取。")
	assert_false(custom_control.editable_state, "自定义控件应收到 set_editable。")
	assert_signal_emitted(field, "value_changed", "自定义控件信号应转发 value_changed。")
	assert_signal_emitted(field, "debounced_value_changed", "禁用等待时防抖信号应同步发出。")


func test_resource_table_can_auto_save_committed_resource() -> void:
	var resource: GFConfigTableColumn = GFConfigTableColumn.new()
	resource.field_name = &"old"
	var path: String = "user://gf_resource_table_auto_save.tres"
	assert_eq(ResourceSaver.save(resource, path), OK, "测试资源应能先保存到 user://。")

	var loaded: GFConfigTableColumn = _as_config_table_column(ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE))
	var editor: GFResourceTableEditor = GFResourceTableEditor.new()
	add_child_autofree(editor)
	editor.auto_save_committed_resources = true
	editor.load_resources([loaded], [{
		"name": &"field_name",
		"type": TYPE_STRING_NAME,
	}])

	assert_true(editor.commit_cell_value(0, &"field_name", &"new"), "有效单元格应提交成功。")
	var reloaded: GFConfigTableColumn = _as_config_table_column(ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE))
	assert_eq(DirAccess.remove_absolute(ProjectSettings.globalize_path(path)), OK, "测试应能删除自动保存临时资源。")

	assert_eq(reloaded.field_name, &"new", "启用自动保存后提交值应写回资源文件。")


# --- 私有/辅助方法 ---

func _find_input_spins(root: Node) -> Array[SpinBox]:
	var result: Array[SpinBox] = []
	for child: Node in root.find_children("*", "SpinBox", true, false):
		if child is SpinBox:
			var spin: SpinBox = child
			result.append(spin)
	return result


func _find_component_toggle(root: Node, component: String) -> CheckBox:
	var control: Node = root.find_child("Edit_" + component, true, false)
	assert_true(control is CheckBox)
	if control is CheckBox:
		var checkbox: CheckBox = control
		return checkbox
	return null


func _find_text_input(root: Node) -> TextEdit:
	var inputs: Array[Node] = root.find_children("*", "TextEdit", true, false)
	assert_eq(inputs.size(), 1, "多行提示应使用唯一的原生 TextEdit。")
	if inputs.size() == 1 and inputs[0] is TextEdit:
		var input: TextEdit = inputs[0]
		return input
	return null


func _prepared_input_changes(prepared: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var raw_changes: Variant = prepared.get("changes")
	assert_true(raw_changes is Array)
	if raw_changes is Array:
		var changes: Array = raw_changes
		for raw_change: Variant in changes:
			assert_true(raw_change is Dictionary)
			if raw_change is Dictionary:
				var change: Dictionary = raw_change
				result.append(change)
	return result


func _input_string(value: Variant) -> String:
	assert_true(value is String)
	if value is String:
		var text: String = value
		return text
	return ""


func _write_empty_user_file(path: String) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	assert_not_null(file, "测试应能创建 user:// 临时文件。")
	if file == null:
		return
	var _store_string_result_179: Variant = file.store_string("")
	file.close()


func _as_table_resource(value: Variant) -> TableResource:
	assert_true(value is TableResource, "测试观察值应为 TableResource。")
	if value is TableResource:
		var resource: TableResource = value
		return resource
	return null


func _as_line_edit(value: Variant) -> LineEdit:
	assert_true(value is LineEdit, "测试观察值应为 LineEdit。")
	if value is LineEdit:
		var line_edit: LineEdit = value
		return line_edit
	return null


func _as_option_button(value: Variant) -> OptionButton:
	assert_true(value is OptionButton, "测试观察值应为 OptionButton。")
	if value is OptionButton:
		var option_button: OptionButton = value
		return option_button
	return null


func _variant_to_vector2(value: Variant) -> Vector2:
	if value is Vector2:
		var vector_value: Vector2 = value
		return vector_value
	return Vector2.ZERO


func _as_hbox_container(value: Variant) -> HBoxContainer:
	assert_true(value is HBoxContainer, "测试观察值应为 HBoxContainer。")
	if value is HBoxContainer:
		var container: HBoxContainer = value
		return container
	return null


func _as_spin_box(value: Variant) -> SpinBox:
	assert_true(value is SpinBox, "测试观察值应为 SpinBox。")
	if value is SpinBox:
		var spin: SpinBox = value
		return spin
	return null


func _as_custom_value_control(value: Variant) -> CustomValueControl:
	assert_true(value is CustomValueControl, "测试观察值应为 CustomValueControl。")
	if value is CustomValueControl:
		var control: CustomValueControl = value
		return control
	return null


func _as_config_table_column(value: Variant) -> GFConfigTableColumn:
	assert_true(value is GFConfigTableColumn, "测试观察值应为 GFConfigTableColumn。")
	if value is GFConfigTableColumn:
		var column: GFConfigTableColumn = value
		return column
	return null


# --- 辅助类型 ---

class InputRangeResource:
	extends Resource

	@export var vector: Vector4 = Vector4(-12.5, 256.25, -8.5, 1024.25)
	@export var integer_vector: Vector4i = Vector4i(-12, 256, -8, 1024)
	@export_multiline var prose: String = ""


class TableResource:
	extends Resource

	@export var label: String = ""
	@export var amount: int = 0


class RejectingTableResource:
	extends Resource

	var amount_value: int = 0
	var ratio_value: float = 0.0
	var variant_value: Variant = null
	var rejected_values: Array[int] = []
	var ratio_setter_call_count: int = 0
	var variant_setter_call_count: int = 0


	func _get_property_list() -> Array[Dictionary]:
		return [
			{
				"name": "amount",
				"type": TYPE_INT,
				"usage": PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_STORAGE,
			},
			{
				"name": "ratio",
				"type": TYPE_FLOAT,
				"usage": PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_STORAGE,
			},
			{
				"name": "variant_value",
				"type": TYPE_NIL,
				"usage": PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_STORAGE,
			},
		]


	func _get(property: StringName) -> Variant:
		if property == &"amount":
			return amount_value
		if property == &"ratio":
			return ratio_value
		if property == &"variant_value":
			return variant_value
		return null


	func _set(property: StringName, raw_value: Variant) -> bool:
		if property == &"amount":
			var requested_value: int = GF_VARIANT_ACCESS.to_int(raw_value)
			if rejected_values.has(requested_value):
				return false
			amount_value = requested_value
			return true
		if property == &"ratio":
			ratio_setter_call_count += 1
			ratio_value = GF_VARIANT_ACCESS.to_float(raw_value)
			return true
		if property == &"variant_value":
			variant_setter_call_count += 1
			variant_value = raw_value
			return true
		return false


class TrackingResourceTableEditor:
	extends "res://addons/gf/kernel/editor/gf_resource_table_editor.gd"

	var refresh_call_count: int = 0


	func refresh() -> void:
		refresh_call_count += 1
		super.refresh()


class CustomValueControl:
	extends Control

	signal value_changed(value: Variant)

	var stored_value: Variant = null
	var editable_state: bool = true

	func set_value(value: Variant) -> void:
		stored_value = value

	func get_value() -> Variant:
		return stored_value

	func set_editable(editable: bool) -> void:
		editable_state = editable

	func push_value(value: Variant) -> void:
		stored_value = value
		value_changed.emit(value)
