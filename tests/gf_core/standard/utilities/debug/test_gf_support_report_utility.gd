## 测试 GFSupportReportUtility 的报告构建、分区和提交回调。
extends GutTest


# --- 测试方法 ---

## 验证支持报告可聚合用户描述、元数据和自定义分区。
func test_support_report_collects_custom_sections() -> void:
	var utility: GFSupportReportUtility = GFSupportReportUtility.new()
	assert_true(utility.register_section(&"save", func(options: Dictionary) -> Dictionary:
		return { "slot": GFVariantData.get_option_string(options, "slot", "A") }
	), "有效分区应注册成功。")

	var report: Dictionary = utility.build_report("Need help", {
		"include_diagnostics": false,
		"include_scene": false,
		"include_sections": true,
		"section_options": { "slot": "B" },
		"metadata": { "screen": "settings" },
		"tags": ["qa", "runtime"],
	})
	var sections: Dictionary = GFVariantData.get_option_dictionary(report, "sections")
	var save_section: Dictionary = GFVariantData.get_option_dictionary(sections, &"save")
	var metadata: Dictionary = GFVariantData.get_option_dictionary(report, "metadata")
	var save_value: Dictionary = GFVariantData.get_option_dictionary(save_section, "value")

	assert_eq(GFVariantData.get_option_string(report, "description"), "Need help", "报告应保留用户描述。")
	assert_eq(GFVariantData.get_option_string(metadata, "screen"), "settings", "报告应保留元数据。")
	assert_eq(GFVariantData.get_option_string(save_value, "slot"), "B", "分区 provider 应收到调用选项。")


## 验证默认报告只采集最小运行时信息，敏感扩展分区均需显式启用。
func test_support_report_defaults_to_minimal_collection() -> void:
	var utility: GFSupportReportUtility = GFSupportReportUtility.new()
	assert_true(utility.register_section(&"private_state", func(_options: Dictionary) -> Dictionary:
		return { "account": "hidden" }
	), "测试分区应注册成功。")

	var report: Dictionary = utility.build_report("Minimal")
	var runtime: Dictionary = GFVariantData.get_option_dictionary(report, "runtime")

	assert_eq(GFVariantData.get_option_string_name(runtime, "detail"), &"minimal", "默认运行时档位应为 minimal。")
	assert_true(runtime.has("platform"), "minimal 档位应保留排查平台差异所需的平台名。")
	assert_false(runtime.has("locale"), "minimal 档位不应采集完整 locale。")
	assert_false(runtime.has("processor_count"), "minimal 档位不应采集精确处理器数量。")
	assert_false(runtime.has("static_memory_bytes"), "minimal 档位不应采集精确内存值。")
	assert_true(GFVariantData.get_option_dictionary(report, "scene").is_empty(), "场景快照默认应为空。")
	assert_true(GFVariantData.get_option_dictionary(report, "diagnostics").is_empty(), "诊断快照默认应为空。")
	assert_true(GFVariantData.get_option_dictionary(report, "sections").is_empty(), "自定义分区默认应为空。")


## 验证 coarse 档位只公开分桶值，不泄露精确运行时计数。
func test_support_report_coarse_runtime_uses_buckets() -> void:
	var utility: GFSupportReportUtility = GFSupportReportUtility.new()

	var runtime: Dictionary = utility.collect_runtime_snapshot(GFSupportReportUtility.RuntimeDetail.COARSE)

	assert_eq(GFVariantData.get_option_string_name(runtime, "detail"), &"coarse", "运行时档位应写入快照。")
	assert_false(GFVariantData.get_option_string(runtime, "processor_count_range").is_empty(), "处理器数量应输出范围。")
	assert_false(GFVariantData.get_option_string(runtime, "static_memory_mib_range").is_empty(), "内存应输出 MiB 范围。")
	assert_false(GFVariantData.get_option_string(runtime, "object_count_range").is_empty(), "对象数量应输出范围。")
	assert_false(runtime.has("processor_count"), "coarse 档位不得混入精确处理器数量。")
	assert_false(runtime.has("static_memory_bytes"), "coarse 档位不得混入精确内存。")
	assert_false(runtime.has("object_count"), "coarse 档位不得混入精确对象数量。")


## 验证 full 档位和完全关闭运行时采集都需要调用方明确选择。
func test_support_report_runtime_collection_is_explicit() -> void:
	var utility: GFSupportReportUtility = GFSupportReportUtility.new()

	var full_report: Dictionary = utility.build_report("Full", {
		"runtime_detail": GFSupportReportUtility.RuntimeDetail.FULL,
	})
	var full_runtime: Dictionary = GFVariantData.get_option_dictionary(full_report, "runtime")
	var omitted_report: Dictionary = utility.build_report("None", {
		"include_runtime": false,
	})

	assert_eq(GFVariantData.get_option_string_name(full_runtime, "detail"), &"full", "显式 full 应采集完整运行时信息。")
	assert_true(full_runtime.has("locale"), "full 档位应包含完整 locale。")
	assert_true(full_runtime.has("processor_count"), "full 档位应包含精确处理器数量。")
	assert_true(full_runtime.has("static_memory_bytes"), "full 档位应包含精确内存字节数。")
	assert_true(full_runtime.has("object_count"), "full 档位应包含精确对象数量。")
	assert_true(GFVariantData.get_option_dictionary(omitted_report, "runtime").is_empty(), "include_runtime=false 应完全省略运行时采集。")


## 验证支持报告文本选项可安全接收非字符串值。
func test_support_report_string_options_are_safe_for_variants() -> void:
	var utility: GFSupportReportUtility = GFSupportReportUtility.new()
	var provider: Callable = func(_options: Dictionary) -> String:
		return "ok"
	assert_true(utility.register_section(&"runtime", provider, { "label": 123 }), "数字 label 应被安全转换。")

	var report: Dictionary = utility.build_report("Variants", {
		"include_diagnostics": false,
		"include_scene": false,
		"report_id": 456,
		"tags": [1, &"two"],
	})
	var catalog: Dictionary = utility.get_section_catalog()
	var runtime_section: Dictionary = GFVariantData.get_option_dictionary(catalog, &"runtime")

	assert_eq(GFVariantData.get_option_string(report, "report_id"), "456", "数字 report_id 应转换为文本。")
	assert_true(GFVariantData.get_option_packed_string_array(report, "tags").has("1"), "数字 tag 应转换为文本。")
	assert_eq(GFVariantData.get_option_string(runtime_section, "label"), "123", "数字分区 label 应转换为文本。")


## 验证支持报告可导出 JSON 并通过回调提交。
func test_support_report_exports_and_submits_with_transport_callback() -> void:
	var utility: GFSupportReportUtility = GFSupportReportUtility.new()
	var report: Dictionary = utility.build_report("Export", {
		"include_diagnostics": false,
		"include_scene": false,
	})
	var submitted_ids: Array[String] = []
	var result: Dictionary = utility.submit_report(report, func(next_report: Dictionary, _options: Dictionary) -> String:
		submitted_ids.append(GFVariantData.get_option_string(next_report, "report_id"))
		return "accepted"
	)

	assert_true(utility.export_report_json(report).contains("report_id"), "JSON 导出应包含报告 ID。")
	assert_true(GFVariantData.get_option_bool(result, "ok"), "有效 transport 应提交成功。")
	assert_eq(GFVariantData.get_option_string(result, "value"), "accepted", "提交结果应保留回调返回值。")
	assert_eq(submitted_ids.size(), 1, "transport 应收到报告副本。")


func test_support_report_json_export_is_report_safe() -> void:
	var utility: GFSupportReportUtility = GFSupportReportUtility.new()
	var json_text: String = utility.export_report_json({
		"report_id": "unsafe",
		"metadata": {
			"value": NAN,
			"object": RefCounted.new(),
		},
	})

	assert_true(json_text.contains(GFVariantJsonCodec.JSON_MARKER_KEY), "支持报告 JSON 应编码 NaN。")
	assert_true(json_text.contains("__gf_report_value__"), "支持报告 JSON 应脱敏 Object。")
	assert_false(json_text.contains("\"value\":null"), "支持报告 JSON 不应把 NaN 退化为 null。")


## 验证支持报告可导出适合人工审阅的 Markdown。
func test_support_report_exports_markdown_summary_sections_and_attachments() -> void:
	var utility: GFSupportReportUtility = GFSupportReportUtility.new()
	assert_true(utility.register_section(&"runtime_state", func(_options: Dictionary) -> Dictionary:
		return {
			"screen": "settings",
			"accent": Color.RED,
		}
	), "有效分区应注册成功。")

	var report: Dictionary = utility.build_report("Markdown export", {
		"include_diagnostics": false,
		"include_scene": false,
		"include_sections": true,
		"metadata": {
			"channel": "qa",
		},
		"attachments": {
			"log": {
				"text": "hello",
				"filename": "recent.log",
			},
		},
	})
	var markdown: String = utility.export_report_markdown(report, {
		"title": "QA Support Report",
	})

	assert_true(markdown.contains("# QA Support Report"), "Markdown 应包含自定义标题。")
	assert_true(markdown.contains("Markdown export"), "Markdown 应包含用户描述。")
	assert_true(markdown.contains("## Metadata"), "Markdown 应包含元数据分区。")
	assert_true(markdown.contains("## Sections"), "Markdown 应包含自定义分区。")
	assert_true(markdown.contains("```json"), "自定义分区值应使用 JSON 代码块。")
	assert_true(markdown.contains("## Attachments"), "Markdown 应包含附件摘要。")
	assert_false(markdown.contains("hello"), "Markdown 附件摘要不应内联完整附件内容。")


## 验证支持报告可规范化文本附件。
func test_support_report_collects_text_attachments() -> void:
	var utility: GFSupportReportUtility = GFSupportReportUtility.new()

	var report: Dictionary = utility.build_report("Attachment", {
		"include_diagnostics": false,
		"include_scene": false,
		"attachments": {
			"log": {
				"text": "hello",
				"filename": "log.txt",
				"mime_type": "text/plain",
			},
		},
	})
	var attachments: Dictionary = GFVariantData.get_option_dictionary(report, "attachments")
	var log_attachment: Dictionary = GFVariantData.get_option_dictionary(attachments, &"log")

	assert_true(GFVariantData.get_option_bool(log_attachment, "ok"), "文本附件应规范化成功。")
	assert_eq(GFVariantData.get_option_string(log_attachment, "encoding"), "text", "文本附件应保留 text 编码。")
	assert_eq(GFVariantData.get_option_string(log_attachment, "data"), "hello", "文本附件应保留内容。")


## 验证路径型附件默认被拒绝，避免支持报告读取任意本地文件。
func test_support_report_rejects_path_attachments_by_default() -> void:
	var utility: GFSupportReportUtility = GFSupportReportUtility.new()
	var attachment_path: String = "user://gf_support_report_path_attachment.txt"
	var file: FileAccess = FileAccess.open(attachment_path, FileAccess.WRITE)
	assert_not_null(file, "测试应能创建 user:// 附件文件。")
	if file != null:
		var _store_result: Variant = file.store_string("secret")
		file.close()

	var attachments: Dictionary = utility.collect_attachments({
		"local_file": {
			"path": attachment_path,
		},
		"missing_file": {
			"path": "user://gf_support_report_missing_attachment.txt",
		},
	})
	var file_attachment: Dictionary = GFVariantData.get_option_dictionary(attachments, &"local_file")
	var missing_attachment: Dictionary = GFVariantData.get_option_dictionary(attachments, &"missing_file")

	assert_false(GFVariantData.get_option_bool(file_attachment, "ok"), "未显式开启时路径型附件应被拒绝。")
	assert_eq(GFVariantData.get_option_string(file_attachment, "reason"), "attachment_path_not_allowed", "拒绝原因应稳定。")
	assert_eq(GFVariantData.get_option_string(missing_attachment, "reason"), "attachment_path_not_allowed", "默认拒绝不应泄露路径是否存在。")
	var _remove_result: Error = DirAccess.remove_absolute(attachment_path)


func test_support_report_replaces_existing_file_through_atomic_sidecars() -> void:
	var utility: GFSupportReportUtility = GFSupportReportUtility.new()
	var report_path: String = "user://gf_support_report_atomic.json"
	var existing_file: FileAccess = FileAccess.open(report_path, FileAccess.WRITE)
	assert_not_null(existing_file, "测试应能创建已有报告文件。")
	if existing_file != null:
		var _store_result: Variant = existing_file.store_string("old-content")
		existing_file.close()

	var save_error: Error = utility.save_report({ "report_id": "new-report" }, report_path)
	var saved_file: FileAccess = FileAccess.open(report_path, FileAccess.READ)
	var saved_text: String = saved_file.get_as_text() if saved_file != null else ""
	if saved_file != null:
		saved_file.close()

	assert_eq(save_error, OK, "原子替换已有报告应成功。")
	assert_true(saved_text.contains("new-report"), "提交后目标文件应包含完整新报告。")
	assert_false(saved_text.contains("old-content"), "提交后不应残留旧报告内容。")
	var _remove_result: Error = DirAccess.remove_absolute(report_path)


func test_support_report_path_boundary_canonicalizes_parent_segments() -> void:
	var utility: GFSupportReportUtility = GFSupportReportUtility.new()

	assert_true(
		utility._is_path_under_allowed_roots("user://allowed/log.txt", PackedStringArray(["user://allowed"])),
		"允许根目录下的路径应通过。"
	)
	assert_false(
		utility._is_path_under_allowed_roots("user://allowed/../secret.txt", PackedStringArray(["user://allowed"])),
		"包含 .. 逃逸允许根的路径不应通过。"
	)


## 验证场景节点数量统计会遵守节点上限。
func test_support_report_scene_node_count_respects_limit() -> void:
	var utility: GFSupportReportUtility = GFSupportReportUtility.new()
	var root: Node = Node.new()
	var child: Node = Node.new()
	root.add_child(child)
	var counters: Dictionary = utility._make_node_count_counters()

	var count: int = utility._count_nodes(root, 0, 64, 1, counters)

	assert_eq(count, 1, "节点数量统计应遵守 max_nodes 上限。")
	assert_true(GFVariantData.get_option_bool(counters, "truncated"), "节点数量统计被截断时应记录 truncated。")

	root.free()


## 验证支持报告会按大小限制拒绝附件。
func test_support_report_rejects_oversized_attachments() -> void:
	var utility: GFSupportReportUtility = GFSupportReportUtility.new()

	var attachments: Dictionary = utility.collect_attachments({
		"large": "abcdef",
	}, {
		"max_attachment_bytes": 3,
	})
	var large_attachment: Dictionary = GFVariantData.get_option_dictionary(attachments, &"large")

	assert_false(GFVariantData.get_option_bool(large_attachment, "ok"), "超出大小限制的附件应被拒绝。")
	assert_eq(GFVariantData.get_option_string(large_attachment, "reason"), "attachment_too_large", "拒绝原因应稳定。")


## 验证支持报告提交会归一化 transport 结果。
func test_support_report_normalizes_transport_result() -> void:
	var utility: GFSupportReportUtility = GFSupportReportUtility.new()
	var report: Dictionary = utility.build_report("Submit", {
		"include_diagnostics": false,
		"include_scene": false,
	})

	var result: Dictionary = utility.submit_report(report, func(_next_report: Dictionary, _options: Dictionary) -> Dictionary:
		return {
			"ok": false,
			"error": "rejected",
			"metadata": { "status": 400 },
		}
	)
	var metadata: Dictionary = GFVariantData.get_option_dictionary(result, "metadata")

	assert_false(GFVariantData.get_option_bool(result, "ok"), "transport 返回失败时应保留失败状态。")
	assert_eq(GFVariantData.get_option_string(result, "error"), "rejected", "transport 错误说明应保留。")
	assert_eq(GFVariantData.get_option_int(metadata, "status"), 400, "transport 元数据应保留。")
