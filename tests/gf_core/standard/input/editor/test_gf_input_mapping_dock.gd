extends GutTest


# --- 测试方法 ---

func test_input_mapping_dock_uses_compact_empty_state() -> void:
	var dock: GFInputMappingDock = GFInputMappingDock.new()

	dock.refresh()

	assert_true(dock._empty_label.visible, "未加载上下文时应显示空状态。")
	assert_false(dock._content_split.visible, "未加载上下文时不应留下空表格和详情面板。")
	assert_ne(dock._summary_label.text, dock._empty_label.text, "空状态顶部摘要和正文提示不应重复。")

	dock.free()


func test_input_mapping_dock_reports_context_bindings() -> void:
	var dock: GFInputMappingDock = GFInputMappingDock.new()
	var context: GFInputContext = _make_context(false)

	dock.set_input_context(context)
	var report: Dictionary = dock.get_last_report()

	assert_eq(GFVariantData.get_option_int(report, "mapping_count"), 1, "Input 页面应统计上下文映射数量。")
	assert_eq(GFVariantData.get_option_int(report, "binding_count"), 1, "Input 页面应统计绑定数量。")
	assert_eq(GFVariantData.get_option_int(report, "conflict_count"), 0, "单个绑定不应产生冲突。")
	assert_true(GFVariantData.get_option_bool(report, "ok"), "结构健康的输入上下文应报告 ok。")
	assert_true(GFVariantData.get_option_bool(report, "healthy"), "没有 warning 或 error 时应报告 healthy。")

	dock.free()


func test_input_mapping_dock_reports_binding_conflicts() -> void:
	var dock: GFInputMappingDock = GFInputMappingDock.new()
	var context: GFInputContext = _make_context(true)

	dock.set_input_context(context)
	var report: Dictionary = dock.get_last_report()
	var issues: Array = GFVariantData.as_array(GFVariantData.get_option_value(report, "issues"))
	var issue: Dictionary = GFVariantData.as_dictionary(issues[0])

	assert_eq(GFVariantData.get_option_int(report, "conflict_count"), 1, "相同输入绑定到两个动作时应报告冲突。")
	assert_eq(GFVariantData.get_option_int(report, "warning_count"), 1, "绑定冲突应作为 warning 进入统一问题列表。")
	assert_eq(GFVariantData.get_option_int(report, "issue_count"), 1, "Input 页面报告应统计问题总数。")
	assert_true(GFVariantData.get_option_bool(report, "ok"), "只有 warning 时标准校验报告仍应 ok。")
	assert_false(GFVariantData.get_option_bool(report, "healthy", true), "存在冲突 warning 时不应报告 healthy。")
	assert_eq(GFVariantData.get_option_string(issue, "kind"), "binding_conflict")

	dock.free()


func test_input_mapping_dock_clears_path_when_context_is_cleared() -> void:
	var dock: GFInputMappingDock = GFInputMappingDock.new()
	var context: GFInputContext = _make_context(false)

	dock._path_edit.text = "res://tests/fixtures/input_context.tres"
	dock.set_input_context(context)
	dock._path_edit.text = "res://tests/fixtures/input_context.tres"
	dock.set_input_context(null)

	assert_eq(dock._path_edit.text, "", "清空上下文时路径输入框不应保留旧路径。")
	assert_true(dock.get_last_report().is_empty(), "清空上下文后最近报告应同步清空。")
	assert_true(dock._empty_label.visible, "清空上下文后应回到空状态。")

	dock.free()


func test_input_mapping_dock_reports_null_mapping_once() -> void:
	var dock: GFInputMappingDock = GFInputMappingDock.new()
	var context: GFInputContext = _make_context(false)
	context.mappings.append(null)

	dock.set_input_context(context)
	var report: Dictionary = dock.get_last_report()
	var issues: Array = GFVariantData.get_option_array(report, "issues")
	var parsed_value: Variant = JSON.parse_string(dock._details.text)

	assert_true(parsed_value is Dictionary, "详情面板应输出可解析 JSON。")
	assert_eq(_count_issue_kind(issues, "null_mapping"), 1, "空映射应只由诊断报告记录一次。")
	assert_false(
		GFVariantData.as_dictionary(parsed_value).has("issues"),
		"未选择树节点时详情面板只应显示有界摘要，完整问题应按选择惰性展示。"
	)

	dock.free()


func test_input_mapping_dock_details_json_is_safe_for_nonfinite_and_circular_values() -> void:
	var dock: GFInputMappingDock = GFInputMappingDock.new()
	var circular: Dictionary = {
		"nan": NAN,
		"positive_inf": INF,
		"negative_inf": -INF,
		"tags": PackedStringArray(["alpha", "beta"]),
	}
	circular["self"] = circular

	var text: String = dock._safe_json(circular)
	var parsed_value: Variant = JSON.parse_string(text)

	assert_true(parsed_value is Dictionary, "详情 JSON 应能在包含非有限数和循环引用时继续解析。")
	assert_false(text.contains(":null"), "详情 JSON 不应让 NaN 或 Infinity 被 JSON.stringify 替换为 null。")
	var parsed: Dictionary = GFVariantData.as_dictionary(parsed_value)
	assert_eq(_typed_marker_type(GFVariantData.get_option_value(parsed, "nan")), "Float")
	assert_eq(_typed_marker_string_value(GFVariantData.get_option_value(parsed, "nan")), "NaN")
	assert_eq(_typed_marker_string_value(GFVariantData.get_option_value(parsed, "positive_inf")), "INF")
	assert_eq(_typed_marker_string_value(GFVariantData.get_option_value(parsed, "negative_inf")), "-INF")
	var tags_marker: Dictionary = _report_marker(
		GFVariantData.get_option_value(parsed, "tags")
	)
	assert_eq(GFVariantData.get_option_int(tags_marker, "version"), 1)
	assert_eq(GFVariantData.get_option_string(tags_marker, "type"), "PackedArray")
	assert_true(GFVariantData.get_option_bool(tags_marker, "redacted"))
	assert_eq(
		GFVariantData.get_option_string(tags_marker, "collection_type"),
		"PackedStringArray"
	)
	assert_eq(GFVariantData.get_option_int(tags_marker, "count"), 2)
	assert_eq(
		GFVariantData.get_option_array(tags_marker, "items"),
		["alpha", "beta"]
	)
	var circular_marker: Dictionary = _report_marker(
		GFVariantData.get_option_value(parsed, "self")
	)
	assert_eq(GFVariantData.get_option_int(circular_marker, "version"), 1)
	assert_eq(GFVariantData.get_option_string(circular_marker, "type"), "CircularReference")
	assert_true(GFVariantData.get_option_bool(circular_marker, "redacted"))
	assert_eq(circular_marker.size(), 3, "循环 marker 只能暴露固定 schema 字段。")

	dock.free()


func test_input_mapping_dock_file_dialog_only_offers_preflightable_text_resources() -> void:
	var dock: GFInputMappingDock = GFInputMappingDock.new()
	var filters_text: String = "\n".join(Array(dock._file_dialog.filters))

	assert_true(filters_text.contains("*.tres"), "资源选择器应只引导选择文本资源。")
	assert_false(filters_text.contains("*.res"), "无法在实例化前确认主类型的二进制资源不应进入选择器。")

	dock.free()


func test_load_context_path_rejects_unsupported_extension_without_losing_context() -> void:
	var path: String = "user://gf_input_mapping_dock_invalid.txt"
	_write_text(path, "not a resource")
	var dock: GFInputMappingDock = GFInputMappingDock.new()
	var context: GFInputContext = _make_context(false)
	dock.set_input_context(context)

	var load_error: Error = dock.load_context_path(path)
	await get_tree().process_frame

	assert_eq(load_error, ERR_INVALID_PARAMETER, "不受支持的扩展名应在 ResourceLoader 之前被拒绝。")
	assert_same(dock._context, context, "失败的加载事务不应丢弃当前有效上下文。")
	assert_true(dock._details.text.contains("仅支持"), "显式加载错误不应被初始化阶段的延迟刷新覆盖。")

	dock.free()
	_remove_file(path)


func test_failed_file_selection_restores_committed_context_path() -> void:
	var committed_path: String = "user://gf_input_mapping_dock_committed.tres"
	var invalid_path: String = "user://gf_input_mapping_dock_attempted.txt"
	_remove_file(committed_path)
	_remove_file(invalid_path)
	assert_eq(ResourceSaver.save(_make_context(false), committed_path), OK, "已提交上下文夹具应保存成功。")
	_write_text(invalid_path, "not a context resource")
	var dock: GFInputMappingDock = GFInputMappingDock.new()
	assert_eq(dock.load_context_path(committed_path), OK, "前置上下文应成功提交。")
	var committed_context: GFInputContext = dock._context

	dock._on_file_selected(invalid_path)

	assert_same(dock._context, committed_context, "失败选择不得替换已提交 context。")
	assert_eq(dock._context.resource_path, committed_path, "当前 context 应继续对应已提交资源路径。")
	assert_eq(dock._path_edit.text, committed_path, "失败选择后输入框必须恢复已提交路径。")
	assert_true(dock._details.text.contains("仅支持"), "恢复路径时仍应保留本次失败原因。")

	dock.free()
	_remove_file(committed_path)
	_remove_file(invalid_path)


func test_load_context_path_rejects_resource_over_file_budget_before_loading() -> void:
	var path: String = "user://gf_input_mapping_dock_oversized.tres"
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	assert_not_null(file, "测试资源文件应可创建。")
	if file != null:
		var bytes: PackedByteArray = PackedByteArray()
		var _resize_result: Variant = bytes.resize(4 * 1024 * 1024 + 1)
		var _store_buffer_result: Variant = file.store_buffer(bytes)
		file.close()
	var dock: GFInputMappingDock = GFInputMappingDock.new()

	var load_error: Error = dock.load_context_path(path)

	assert_eq(load_error, ERR_OUT_OF_MEMORY, "超预算资源应在反序列化前失败。")
	assert_true(dock._details.text.contains("大小预算"), "资源预算失败应提供可观察原因。")

	dock.free()
	_remove_file(path)


func test_load_context_path_replaces_stale_resource_cache() -> void:
	var path: String = "user://gf_input_mapping_dock_cache_replace.tres"
	_remove_file(path)
	var first: GFInputContext = _make_context(false)
	first.context_id = &"first"
	assert_eq(ResourceSaver.save(first, path), OK, "首个测试上下文应保存成功。")
	var dock: GFInputMappingDock = GFInputMappingDock.new()
	assert_eq(dock.load_context_path(path), OK, "首个测试上下文应加载成功。")

	var second: GFInputContext = _make_context(false)
	second.context_id = &"second"
	assert_eq(ResourceSaver.save(second, path), OK, "替换测试上下文应保存成功。")
	assert_eq(dock.load_context_path(path), OK, "替换后的测试上下文应重新加载成功。")

	assert_eq(dock._context.get_context_id(), &"second", "重复加载同一路径时必须替换陈旧 Resource 缓存。")

	dock.free()
	_remove_file(path)


func test_load_context_path_rejects_non_context_resource() -> void:
	var path: String = "user://gf_input_mapping_dock_wrong_type.tres"
	_remove_file(path)
	assert_eq(ResourceSaver.save(Resource.new(), path), OK, "非输入资源测试夹具应保存成功。")
	var dock: GFInputMappingDock = GFInputMappingDock.new()

	var load_error: Error = dock.load_context_path(path)

	assert_eq(load_error, ERR_INVALID_DATA, "类型声明不匹配的资源应在实例化前被拒绝。")
	assert_true(dock._details.text.contains("声明类型"), "类型预检失败应给出明确原因。")

	dock.free()
	_remove_file(path)


func test_input_mapping_dock_refreshes_when_context_emits_changed() -> void:
	var dock: GFInputMappingDock = GFInputMappingDock.new()
	var context: GFInputContext = _make_context(false)
	dock.set_input_context(context)
	context.mappings.append(_make_mapping(&"confirm"))

	context.emit_changed()

	assert_eq(
		GFVariantData.get_option_int(dock.get_last_report(), "mapping_count"),
		2,
		"编辑中的上下文发出 changed 后，Dock 应自动重建诊断。"
	)

	dock.free()


func test_input_mapping_dock_disconnects_replaced_context() -> void:
	var dock: GFInputMappingDock = GFInputMappingDock.new()
	var first: GFInputContext = _make_context(false)
	var second: GFInputContext = _make_context(false)
	second.context_id = &"second"
	dock.set_input_context(first)
	dock.set_input_context(second)
	first.mappings.append(_make_mapping(&"stale"))

	first.emit_changed()

	assert_same(dock._context, second, "旧上下文的 changed 信号不应影响已替换的上下文。")
	assert_eq(GFVariantData.get_option_int(dock.get_last_report(), "mapping_count"), 1)

	dock.free()


func test_input_mapping_dock_does_not_coerce_unknown_enum_values() -> void:
	var dock: GFInputMappingDock = GFInputMappingDock.new()

	assert_eq(dock._get_value_type_name(999), "unknown(999)", "未知动作值类型不能伪装成 bool。")
	assert_eq(dock._get_value_target_name(999), "unknown(999)", "未知绑定目标不能伪装成 auto。")

	dock.free()


func test_input_mapping_dock_preserves_dictionary_key_identity_in_details() -> void:
	var dock: GFInputMappingDock = GFInputMappingDock.new()
	var value: Dictionary = {
		1: "integer key",
		"1": "string key",
	}

	var parsed: Dictionary = GFVariantData.as_dictionary(JSON.parse_string(dock._safe_json(value)))
	var marker: Dictionary = _report_marker(parsed)
	var entries: Array = GFVariantData.get_option_array(marker, "entries")
	var integer_entry: Dictionary = {}
	var string_entry: Dictionary = {}
	for entry_value: Variant in entries:
		var entry: Dictionary = GFVariantData.as_dictionary(entry_value)
		var entry_key: Variant = GFVariantData.get_option_value(entry, "key")
		if entry_key is int or entry_key is float:
			integer_entry = entry
		elif entry_key is String:
			string_entry = entry

	assert_eq(GFVariantData.get_option_string(marker, "type"), "Dictionary", "显示编码不得通过字符串化键制造碰撞。")
	assert_eq(GFVariantData.get_option_int(marker, "version"), 1)
	assert_true(GFVariantData.get_option_bool(marker, "redacted"))
	assert_eq(entries.size(), 2, "碰撞键必须作为两个独立条目保留。")
	var decoded_number_key: Variant = GFVariantData.get_option_value(integer_entry, "key")
	assert_true(
		decoded_number_key is int or decoded_number_key is float,
		"数值键在 JSON 往返后仍必须与 String 键可区分。"
	)
	if decoded_number_key is int:
		var decoded_int_key: int = decoded_number_key
		assert_eq(decoded_int_key, 1)
	elif decoded_number_key is float:
		var decoded_float_key: float = decoded_number_key
		assert_eq(decoded_float_key, 1.0)
	assert_eq(GFVariantData.get_option_string(integer_entry, "value"), "integer key")
	assert_eq(GFVariantData.get_option_string(string_entry, "key"), "1")
	assert_eq(GFVariantData.get_option_string(string_entry, "value"), "string key")

	dock.free()


func test_input_mapping_dock_bounds_detail_collections() -> void:
	var dock: GFInputMappingDock = GFInputMappingDock.new()
	var values: Array[int] = []
	for index: int in range(2048):
		values.append(index)

	var parsed_value: Variant = JSON.parse_string(dock._safe_json(values))

	assert_true(parsed_value is Array, "有界详情仍应输出可解析数组。")
	assert_lte(GFVariantData.as_array(parsed_value).size(), 513, "详情集合必须包含固定上限和截断标记。")

	dock.free()


func test_input_mapping_dock_rejects_context_over_mapping_budget() -> void:
	var dock: GFInputMappingDock = GFInputMappingDock.new()
	var context: GFInputContext = GFInputContext.new()
	context.context_id = &"oversized"
	for index: int in range(513):
		context.mappings.append(GFInputMapping.new())

	dock.set_input_context(context)
	var report: Dictionary = dock.get_last_report()

	assert_false(GFVariantData.get_option_bool(report, "ok", true), "超预算上下文不应进入无界诊断。")
	assert_eq(
		_count_issue_kind(GFVariantData.get_option_array(report, "issues"), "mapping_budget_exceeded"),
		1,
		"超预算应通过稳定 issue kind 明确报告。"
	)
	assert_false(
		GFVariantData.as_dictionary(JSON.parse_string(dock._details.text)).has("issues"),
		"初始详情不应复制潜在的大型问题列表。"
	)

	dock.free()


func test_input_mapping_dock_bounds_issues_and_tree_rows() -> void:
	var dock: GFInputMappingDock = GFInputMappingDock.new()
	var context: GFInputContext = GFInputContext.new()
	context.context_id = &"bounded_issues"
	for index: int in range(512):
		context.mappings.append(GFInputMapping.new())

	dock.set_input_context(context)
	var report: Dictionary = dock.get_last_report()
	var displayed_issues: Array = GFVariantData.get_option_array(report, "issues")

	assert_true(GFVariantData.get_option_bool(report, "issues_truncated"), "大型问题列表应明确标记截断。")
	assert_eq(displayed_issues.size(), 512, "报告只应保留固定数量的可展示问题。")
	assert_gt(GFVariantData.get_option_int(report, "issue_count"), displayed_issues.size(), "问题总数应保留真实统计。")
	assert_lte(_count_tree_items(dock._tree.get_root()), 1024, "树渲染必须遵守独立行预算。")

	dock.free()


# --- 私有/辅助方法 ---

func _make_context(with_conflict: bool) -> GFInputContext:
	var context: GFInputContext = GFInputContext.new()
	context.context_id = &"gameplay"
	context.display_name = "Gameplay"
	var mappings: Array[GFInputMapping] = [_make_mapping(&"jump")]
	if with_conflict:
		mappings.append(_make_mapping(&"confirm"))
	context.mappings = mappings
	return context


func _make_mapping(action_id: StringName) -> GFInputMapping:
	var action: GFInputAction = GFInputAction.new()
	action.action_id = action_id
	action.display_name = String(action_id).capitalize()

	var event: InputEventKey = InputEventKey.new()
	event.keycode = KEY_SPACE
	event.physical_keycode = KEY_SPACE

	var binding: GFInputBinding = GFInputBinding.new()
	binding.input_event = event

	var mapping: GFInputMapping = GFInputMapping.new()
	mapping.action = action
	var bindings: Array[GFInputBinding] = [binding]
	mapping.bindings = bindings
	return mapping


func _count_issue_kind(issues: Array, kind: String) -> int:
	var count: int = 0
	for issue_value: Variant in issues:
		if not (issue_value is Dictionary):
			continue
		var issue: Dictionary = GFVariantData.as_dictionary(issue_value)
		if GFVariantData.get_option_string(issue, "kind") == kind:
			count += 1
	return count


func _typed_marker_type(value: Variant) -> String:
	var container: Dictionary = GFVariantData.as_dictionary(value)
	var marker: Dictionary = GFVariantData.as_dictionary(container.get("__gf_variant__", {}))
	return GFVariantData.get_option_string(marker, "type")


func _typed_marker_string_value(value: Variant) -> String:
	var container: Dictionary = GFVariantData.as_dictionary(value)
	var marker: Dictionary = GFVariantData.as_dictionary(container.get("__gf_variant__", {}))
	return GFVariantData.get_option_string(marker, "value")


func _report_marker(value: Variant) -> Dictionary:
	var container: Dictionary = GFVariantData.as_dictionary(value)
	return GFVariantData.as_dictionary(container.get("__gf_report_value__", {}))


func _write_text(path: String, content: String) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	assert_not_null(file, "测试文件应可创建：%s" % path)
	if file == null:
		return
	var _store_string_result: Variant = file.store_string(content)
	file.close()


func _remove_file(path: String) -> void:
	var absolute_path: String = ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(path):
		var _remove_error: Error = DirAccess.remove_absolute(absolute_path)


func _count_tree_items(parent: TreeItem) -> int:
	if parent == null:
		return 0
	var count: int = 0
	var child: TreeItem = parent.get_first_child()
	while child != null:
		count += 1 + _count_tree_items(child)
		child = child.get_next()
	return count
