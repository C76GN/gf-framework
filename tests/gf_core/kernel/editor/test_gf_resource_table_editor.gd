## 测试通用资源表格编辑器的列提取与单元格提交。
extends GutTest


const GF_VARIANT_ACCESS = preload("res://addons/gf/kernel/core/gf_variant_access.gd")


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


func test_resource_table_commit_cell_values_reports_partial_failures() -> void:
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

	assert_false(GF_VARIANT_ACCESS.get_option_bool(report, "ok"), "部分失败时批量报告应标记为失败。")
	assert_eq(GF_VARIANT_ACCESS.get_option_int(report, "requested_count"), 4, "报告应记录请求数量。")
	assert_eq(GF_VARIANT_ACCESS.get_option_int(report, "applied_count"), 1, "只应计入实际改值的单元格。")
	assert_eq(GF_VARIANT_ACCESS.get_option_int(report, "unchanged_count"), 1, "相同值应计为未变化。")
	assert_eq(GF_VARIANT_ACCESS.get_option_int(report, "failed_count"), 2, "无效行和未知属性应计为失败。")
	assert_eq(first.label, "Gamma", "有效变更应写回资源。")
	assert_eq(second.amount, 2, "相同值应保持不变。")
	assert_signal_emit_count(editor, "cell_value_committed", 1)


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


func _as_config_table_column(value: Variant) -> GFConfigTableColumn:
	assert_true(value is GFConfigTableColumn, "测试观察值应为 GFConfigTableColumn。")
	if value is GFConfigTableColumn:
		var column: GFConfigTableColumn = value
		return column
	return null


# --- 辅助类型 ---

class TableResource:
	extends Resource

	@export var label: String = ""
	@export var amount: int = 0
