@tool

extends GutTest


class RefreshCountingInputMappingDock extends GFInputMappingDock:
	var refresh_call_count: int = 0


	func refresh() -> void:
		refresh_call_count += 1
		super()


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


func test_input_mapping_dock_uses_effective_remap_for_report_and_tree() -> void:
	var dock: GFInputMappingDock = GFInputMappingDock.new()
	var context: GFInputContext = GFInputContext.new()
	context.context_id = &"gameplay"
	context.display_name = "Gameplay"
	context.mappings = [
		_make_mapping_with_key(&"jump", KEY_SPACE),
		_make_mapping_with_key(&"confirm", KEY_ENTER),
	]
	var remap_config: GFInputRemapConfig = GFInputRemapConfig.new()
	dock.set_input_context(context)
	dock.set_remap_config(remap_config)

	assert_same(dock.get_remap_config(), remap_config, "getter 必须返回当前诊断使用的 remap 配置。")
	assert_eq(
		GFVariantData.get_option_int(dock.get_last_report(), "conflict_count"),
		0,
		"注入空 remap 配置不应改变默认绑定诊断。"
	)
	assert_true(
		remap_config.changed.is_connected(dock._on_remap_config_changed),
		"Dock 必须观察当前 remap 配置。"
	)

	var remapped_event: InputEventKey = _make_key_event(KEY_SPACE)
	remap_config.set_binding(&"gameplay", &"confirm", 0, remapped_event)
	await get_tree().process_frame

	var report: Dictionary = dock.get_last_report()
	var conflicts: Array = GFVariantData.get_option_array(report, "conflicts")
	var expected_text: String = GFInputFormatter.input_event_as_text(remapped_event)
	var action_item: TreeItem = _find_tree_item(dock._tree.get_root(), "动作", "confirm")
	var binding_item: TreeItem = action_item.get_first_child() if action_item != null else null
	assert_eq(GFVariantData.get_option_int(report, "conflict_count"), 1, "remap 后的有效绑定冲突必须进入报告。")
	assert_true(GFVariantData.get_option_bool(report, "remap_configured"), "报告必须标明使用了 remap 配置。")
	assert_eq(
		GFVariantData.get_option_string(GFVariantData.as_dictionary(conflicts[0]), "event_text"),
		expected_text,
		"冲突报告必须显示有效重绑定事件。"
	)
	assert_not_null(action_item, "Tree 中应存在 confirm 动作行。")
	if action_item != null:
		assert_eq(action_item.get_text(2), expected_text, "动作行必须显示有效重绑定。")
	assert_not_null(binding_item, "confirm 动作下应存在绑定行。")
	if binding_item != null:
		var binding_details: Dictionary = GFVariantData.as_dictionary(binding_item.get_metadata(0))
		assert_eq(binding_item.get_text(2), expected_text, "绑定行必须显示有效重绑定。")
		assert_true(GFVariantData.get_option_bool(binding_details, "remapped"), "详情必须标记 remap 来源。")
		assert_eq(
			GFVariantData.get_option_string(binding_details, "input_event"),
			expected_text,
			"详情必须和报告、Tree 使用同一有效事件。"
		)

	dock.set_remap_config(null)
	assert_false(
		remap_config.changed.is_connected(dock._on_remap_config_changed),
		"清除 remap 配置后必须断开旧资源。"
	)
	assert_eq(
		GFVariantData.get_option_int(dock.get_last_report(), "conflict_count"),
		0,
		"清除 remap 配置后应回到默认绑定诊断。"
	)

	dock.free()


func test_remap_config_public_mutations_emit_changed_only_after_commit() -> void:
	var remap_config: GFInputRemapConfig = GFInputRemapConfig.new()
	watch_signals(remap_config)

	remap_config.set_binding(&"", &"jump", 0, _make_key_event(KEY_SPACE))
	assert_signal_emit_count(remap_config, "changed", 0, "无效绑定不得伪造已提交变更。")

	remap_config.set_binding(&"gameplay", &"jump", 0, _make_key_event(KEY_SPACE))
	assert_signal_emit_count(remap_config, "changed", 1, "成功设置绑定应发出一次 changed。")

	remap_config.clear_binding(&"gameplay", &"jump", 0)
	assert_signal_emit_count(remap_config, "changed", 2, "成功清除绑定应发出一次 changed。")
	remap_config.clear_binding(&"gameplay", &"jump", 0)
	assert_signal_emit_count(remap_config, "changed", 2, "清除不存在的绑定不应发出 changed。")

	remap_config.set_custom_data(&"profile", "keyboard")
	assert_signal_emit_count(remap_config, "changed", 3, "成功设置自定义数据应发出一次 changed。")

	var invalid_report: Dictionary = remap_config.apply_dict({"remapped_events": 1})
	assert_false(GFVariantData.get_option_bool(invalid_report, "committed"), "无效字典不得提交。")
	assert_signal_emit_count(remap_config, "changed", 3, "失败的 apply_dict 不应发出 changed。")

	var replacement: GFInputRemapConfig = GFInputRemapConfig.new()
	replacement.set_binding(&"gameplay", &"confirm", 0, _make_key_event(KEY_ENTER))
	var committed_report: Dictionary = remap_config.apply_dict(replacement.to_dict())
	assert_true(GFVariantData.get_option_bool(committed_report, "committed"), "有效字典应原子提交。")
	assert_signal_emit_count(remap_config, "changed", 4, "成功的 apply_dict 应只发出一次 changed。")


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
	assert_true(dock._content_split.visible, "失败尝试后仍应显示被保留的已提交诊断。")
	var copy_payload: Dictionary = dock._make_copy_payload()
	var current_attempt: Dictionary = GFVariantData.as_dictionary(
		GFVariantData.get_option_value(copy_payload, "current_attempt")
	)
	var committed_report: Dictionary = GFVariantData.as_dictionary(
		GFVariantData.get_option_value(copy_payload, "last_successful_report")
	)
	assert_eq(
		GFVariantData.get_option_string(copy_payload, "kind"),
		"input_mapping_load_failure",
		"复制内容必须显式说明当前加载尝试失败。"
	)
	assert_true(GFVariantData.get_option_bool(copy_payload, "stale"), "旧成功报告必须标明相对本次尝试已过时。")
	assert_true(
		GFVariantData.get_option_string(current_attempt, "hint").contains("仅支持"),
		"复制内容必须包含当前可见失败原因。"
	)
	assert_eq(
		GFVariantData.get_option_string_name(committed_report, "context_id"),
		&"gameplay",
		"复制内容必须明确携带被保留的已提交报告。"
	)
	dock._on_copy_pressed()
	assert_true(dock._summary_label.text.contains("输入上下文路径无效"), "复制后仍必须保留当前失败状态。")
	assert_true(dock._summary_label.text.contains("已复制加载失败"), "复制后应明确说明导出的是失败 envelope。")

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


func test_load_context_path_canonicalizes_alias_before_cache_replacement() -> void:
	var canonical_path: String = "user://gf_input_mapping_dock_canonical.tres"
	var alias_path: String = "user://./gf_input_mapping_dock_canonical.tres"
	_remove_file(canonical_path)
	var first: GFInputContext = _make_context(false)
	first.context_id = &"first"
	assert_eq(ResourceSaver.save(first, canonical_path), OK, "首个测试上下文应保存成功。")
	var dock: RefreshCountingInputMappingDock = RefreshCountingInputMappingDock.new()
	assert_eq(dock.load_context_path(canonical_path), OK, "canonical 路径应成功加载。")

	var second: GFInputContext = _make_context(false)
	second.context_id = &"second"
	assert_eq(ResourceSaver.save(second, canonical_path), OK, "替换测试上下文应保存成功。")
	dock.refresh_call_count = 0

	assert_eq(dock.load_context_path(alias_path), OK, "等价路径别名应成功加载。")
	assert_eq(dock._committed_context_path, canonical_path, "提交身份必须规范化，不能保留调用方词法别名。")
	assert_eq(dock._context.resource_path, canonical_path, "加载后的 Resource 身份必须和提交路径一致。")
	assert_eq(dock.refresh_call_count, 1, "缓存替换期间不得通过旧 changed 连接重入刷新。")
	assert_true(
		dock._context.changed.is_connected(dock._on_context_changed),
		"缓存替换完成后当前资源必须恰好保持有效订阅。"
	)

	dock.free()
	_remove_file(canonical_path)


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
	await get_tree().process_frame

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

	assert_false(
		first.changed.is_connected(dock._on_context_changed),
		"替换 context 后旧资源的 changed connection 必须真实消失。"
	)
	first.emit_changed()

	assert_same(dock._context, second, "旧上下文的 changed 信号不应影响已替换的上下文。")
	assert_eq(GFVariantData.get_option_int(dock.get_last_report(), "mapping_count"), 1)

	dock.free()


func test_input_mapping_dock_coalesces_context_changed_burst() -> void:
	var dock: RefreshCountingInputMappingDock = RefreshCountingInputMappingDock.new()
	var context: GFInputContext = _make_context(false)
	dock.set_input_context(context)
	dock.refresh_call_count = 0
	for index: int in range(20):
		context.mappings.append(_make_mapping(&"burst_%d" % index))
		context.emit_changed()

	assert_eq(dock.refresh_call_count, 0, "Resource.changed 不应在信号调用栈中同步重建完整页面。")
	await get_tree().process_frame

	assert_eq(dock.refresh_call_count, 1, "同帧 changed 风暴必须合并为一次最终刷新。")
	assert_eq(
		GFVariantData.get_option_int(dock.get_last_report(), "mapping_count"),
		21,
		"合并刷新必须观察 burst 的最终状态。"
	)

	dock.free()


func test_input_mapping_dock_disconnects_sources_when_detached() -> void:
	var dock: RefreshCountingInputMappingDock = RefreshCountingInputMappingDock.new()
	var context: GFInputContext = _make_context(false)
	var remap_config: GFInputRemapConfig = GFInputRemapConfig.new()
	add_child(dock)
	dock.set_input_context(context)
	dock.set_remap_config(remap_config)
	dock.refresh_call_count = 0

	remove_child(dock)

	assert_false(
		context.changed.is_connected(dock._on_context_changed),
		"页面脱树后不得继续观察 context。"
	)
	assert_false(
		remap_config.changed.is_connected(dock._on_remap_config_changed),
		"页面脱树后不得继续观察 remap 配置。"
	)
	context.emit_changed()
	remap_config.emit_changed()
	await get_tree().process_frame
	assert_eq(dock.refresh_call_count, 0, "已脱离工作区的页面不得继续执行诊断刷新。")

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
	return _make_mapping_with_key(action_id, KEY_SPACE)


func _make_mapping_with_key(action_id: StringName, keycode: Key) -> GFInputMapping:
	var action: GFInputAction = GFInputAction.new()
	action.action_id = action_id
	action.display_name = String(action_id).capitalize()

	var event: InputEventKey = _make_key_event(keycode)

	var binding: GFInputBinding = GFInputBinding.new()
	binding.input_event = event

	var mapping: GFInputMapping = GFInputMapping.new()
	mapping.action = action
	var bindings: Array[GFInputBinding] = [binding]
	mapping.bindings = bindings
	return mapping


func _make_key_event(keycode: Key) -> InputEventKey:
	var event: InputEventKey = InputEventKey.new()
	event.keycode = keycode
	event.physical_keycode = keycode
	return event


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


func _find_tree_item(parent: TreeItem, type_text: String, identity_text: String) -> TreeItem:
	if parent == null:
		return null
	var child: TreeItem = parent.get_first_child()
	while child != null:
		if child.get_text(0) == type_text and child.get_text(1) == identity_text:
			return child
		var nested: TreeItem = _find_tree_item(child, type_text, identity_text)
		if nested != null:
			return nested
		child = child.get_next()
	return null
