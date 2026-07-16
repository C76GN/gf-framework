extends GutTest


# --- 常量 ---

const GF_VARIANT_ACCESS = preload("res://addons/gf/kernel/core/gf_variant_access.gd")


# --- 测试用例 ---

func test_save_text_reports_generated_ownership_and_content_hashes() -> void:
	var path: String = "user://gf_generated_artifact_report_%d.txt" % Time.get_ticks_usec()
	var first_report: Dictionary = GFGeneratedArtifactReport.save_text(path, "first", {
		"generator_id": "test.generator",
		"source_id": "fixture:item",
		"scan_filesystem": false,
	})
	var second_report: Dictionary = GFGeneratedArtifactReport.save_text(path, "first", {
		"dry_run": true,
		"scan_filesystem": false,
	})
	var third_report: Dictionary = GFGeneratedArtifactReport.save_text(path, "second", {
		"artifact_owner": GFGeneratedArtifactReport.OWNER_EXTERNAL,
		"dry_run": true,
		"scan_filesystem": false,
	})
	var remove_error: Error = DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

	assert_eq(remove_error, OK, "测试应清理临时产物。")
	assert_eq(GF_VARIANT_ACCESS.get_option_string_name(first_report, "status"), GFGeneratedArtifactReport.STATUS_NEW, "首次写入应报告 new。")
	assert_eq(GF_VARIANT_ACCESS.get_option_string_name(first_report, "artifact_owner"), GFGeneratedArtifactReport.OWNER_GENERATED, "默认产物所有权应标记为 generated。")
	assert_eq(GF_VARIANT_ACCESS.get_option_string(first_report, "generator_id"), "test.generator", "报告应保留生成器 ID。")
	assert_eq(GF_VARIANT_ACCESS.get_option_string(first_report, "source_id"), "fixture:item", "报告应保留来源 ID。")
	assert_false(GF_VARIANT_ACCESS.get_option_string(first_report, "content_sha256").is_empty(), "报告应包含内容 sha256。")
	assert_true(GF_VARIANT_ACCESS.get_option_string(first_report, "previous_sha256").is_empty(), "新文件没有 previous sha256。")
	assert_eq(GF_VARIANT_ACCESS.get_option_string_name(second_report, "status"), GFGeneratedArtifactReport.STATUS_UNCHANGED, "相同内容 dry-run 应报告 unchanged。")
	assert_eq(
		GF_VARIANT_ACCESS.get_option_string(second_report, "content_sha256"),
		GF_VARIANT_ACCESS.get_option_string(second_report, "previous_sha256"),
		"相同内容应让当前和 previous sha256 一致。"
	)
	assert_eq(GF_VARIANT_ACCESS.get_option_string_name(third_report, "artifact_owner"), GFGeneratedArtifactReport.OWNER_EXTERNAL, "调用方可声明外部产物所有权。")
	assert_ne(
		GF_VARIANT_ACCESS.get_option_string(third_report, "content_sha256"),
		GF_VARIANT_ACCESS.get_option_string(third_report, "previous_sha256"),
		"变更内容 dry-run 应暴露不同 sha。"
	)


func test_save_text_reports_skipped_as_non_failed_without_writing() -> void:
	var path: String = "user://gf_generated_artifact_report_skip_%d.txt" % Time.get_ticks_usec()
	var first_report: Dictionary = GFGeneratedArtifactReport.save_text(path, "first", {
		"scan_filesystem": false,
	})
	var skipped_report: Dictionary = GFGeneratedArtifactReport.save_text(path, "second", {
		"overwrite_existing": false,
		"scan_filesystem": false,
	})
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	assert_not_null(file, "测试应能读取临时产物。")
	if file == null:
		var _cleanup_error: Error = DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
		return
	var content: String = file.get_as_text()
	file.close()
	var remove_error: Error = DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

	assert_eq(remove_error, OK, "测试应清理临时产物。")
	assert_true(GF_VARIANT_ACCESS.get_option_bool(first_report, "success"), "首次写入应成功。")
	assert_true(GF_VARIANT_ACCESS.get_option_bool(skipped_report, "success"), "skipped 是非失败结果。")
	assert_eq(GF_VARIANT_ACCESS.get_option_string_name(skipped_report, "status"), GFGeneratedArtifactReport.STATUS_SKIPPED, "禁止覆盖时应报告 skipped。")
	assert_eq(GFGeneratedArtifactReport.get_error_code(skipped_report), ERR_ALREADY_EXISTS, "调用方仍可用 error_code 判断是否阻断流程。")
	assert_false(GF_VARIANT_ACCESS.get_option_bool(skipped_report, "written"), "skipped 不应写入目标。")
	assert_eq(content, "first", "skipped 不应改写已有内容。")
	assert_push_warning("[GFGeneratedArtifactReport] 目标文件已存在，已跳过：%s" % path)


func test_make_report_returns_json_safe_metadata_boundary() -> void:
	var report: Dictionary = GFGeneratedArtifactReport.make_report("res://generated/output.gd", GFGeneratedArtifactReport.STATUS_NEW, OK, "", {
		"metadata": {
			"owner": self,
			"not_a_number": NAN,
			"template_path": "res://secret/template.gd.tpl",
		},
	})
	var metadata: Dictionary = GF_VARIANT_ACCESS.get_option_dictionary(report, "metadata")
	var owner_payload: Dictionary = GF_VARIANT_ACCESS.get_option_dictionary(metadata, "owner")
	var owner_marker: Dictionary = GF_VARIANT_ACCESS.get_option_dictionary(owner_payload, "__gf_report_value__")
	var float_payload: Dictionary = GF_VARIANT_ACCESS.get_option_dictionary(metadata, "not_a_number")
	var float_marker: Dictionary = GF_VARIANT_ACCESS.get_option_dictionary(float_payload, "__gf_variant__")
	var json_text: String = JSON.stringify(report)

	assert_eq(GF_VARIANT_ACCESS.get_option_string(report, "status"), "new", "报告状态应保持 JSON 原生字符串。")
	assert_eq(GF_VARIANT_ACCESS.get_option_string(report, "artifact_owner"), "generated", "产物所有权应保持 JSON 原生字符串。")
	assert_eq(GF_VARIANT_ACCESS.get_option_string(owner_marker, "type"), "Object", "metadata 中的运行时对象应被结构化脱敏。")
	assert_eq(GF_VARIANT_ACCESS.get_option_string(float_marker, "type"), "Float", "metadata 中的 NaN 应使用 typed marker。")
	assert_eq(GF_VARIANT_ACCESS.get_option_string(metadata, "template_path"), "template.gd.tpl", "metadata 路径应按报告策略收束为文件名。")
	assert_false(json_text.contains(":null"), "报告应可直接 JSON.stringify() 且不把 NaN 降级为 null。")


func test_save_text_replaces_existing_file_without_temp_artifacts() -> void:
	var path: String = "user://gf_generated_artifact_report_atomic_%d.txt" % Time.get_ticks_usec()
	var file_name: String = path.get_file()
	var first_report: Dictionary = GFGeneratedArtifactReport.save_text(path, "first", {
		"scan_filesystem": false,
	})
	var second_report: Dictionary = GFGeneratedArtifactReport.save_text(path, "second", {
		"scan_filesystem": false,
	})
	var content: String = _read_user_text(path)
	var temp_count: int = _count_user_files_with_prefix("%s.tmp." % file_name)
	var backup_count: int = _count_user_files_with_prefix("%s.backup.tmp." % file_name)
	var remove_error: Error = DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

	assert_eq(remove_error, OK, "测试应清理临时产物。")
	assert_eq(GF_VARIANT_ACCESS.get_option_string_name(first_report, "status"), GFGeneratedArtifactReport.STATUS_NEW, "首次写入应报告 new。")
	assert_eq(GF_VARIANT_ACCESS.get_option_string_name(second_report, "status"), GFGeneratedArtifactReport.STATUS_CHANGED, "覆盖写入应报告 changed。")
	assert_eq(content, "second", "覆盖写入后目标文件内容应完整替换。")
	assert_eq(temp_count, 0, "成功替换后不应残留临时写入文件。")
	assert_eq(backup_count, 0, "成功替换后不应残留备份文件。")


func test_save_text_rejects_absolute_path_and_outside_allowed_roots() -> void:
	var absolute_path: String = ProjectSettings.globalize_path("user://gf_generated_artifact_absolute.txt").replace("\\", "/")
	var allowed_root: String = "user://gf_generated_artifact_report_roots/generated"
	var generated_path: String = allowed_root.path_join("item.txt")
	var outside_path: String = "user://gf_generated_artifact_report_roots/manual/item.txt"

	var absolute_report: Dictionary = GFGeneratedArtifactReport.save_text(absolute_path, "absolute", {
		"scan_filesystem": false,
	})
	var generated_report: Dictionary = GFGeneratedArtifactReport.save_text(generated_path, "inside", {
		"allowed_roots": [allowed_root],
		"scan_filesystem": false,
	})
	var outside_report: Dictionary = GFGeneratedArtifactReport.save_text(outside_path, "outside", {
		"allowed_roots": [allowed_root],
		"scan_filesystem": false,
	})

	var _remove_file_result: Error = DirAccess.remove_absolute(ProjectSettings.globalize_path(generated_path))
	var _remove_generated_dir_result: Error = DirAccess.remove_absolute(ProjectSettings.globalize_path(allowed_root))
	var _remove_root_result: Error = DirAccess.remove_absolute(ProjectSettings.globalize_path("user://gf_generated_artifact_report_roots"))

	assert_eq(GF_VARIANT_ACCESS.get_option_string_name(absolute_report, "status"), GFGeneratedArtifactReport.STATUS_FAILED, "绝对文件系统路径应被拒绝。")
	assert_eq(GFGeneratedArtifactReport.get_error_code(absolute_report), ERR_INVALID_PARAMETER, "绝对路径失败应报告参数错误。")
	assert_true(GF_VARIANT_ACCESS.get_option_bool(generated_report, "success"), "allowed_roots 内路径应允许写入。")
	assert_eq(GF_VARIANT_ACCESS.get_option_string_name(outside_report, "status"), GFGeneratedArtifactReport.STATUS_FAILED, "allowed_roots 外路径应被拒绝。")
	assert_false(FileAccess.file_exists(outside_path), "allowed_roots 外路径不应写入文件。")
	assert_push_error_count(2, "绝对路径和越界路径应各报告一次错误。")


func test_summarize_reports_counts_statuses_and_owner_groups() -> void:
	var reports: Array[Dictionary] = [
		GFGeneratedArtifactReport.make_report("res://a.gd", GFGeneratedArtifactReport.STATUS_NEW, OK, "", {
			"written": true,
			"changed": true,
			"artifact_owner": GFGeneratedArtifactReport.OWNER_GENERATED,
		}),
		GFGeneratedArtifactReport.make_report("res://b.gd", GFGeneratedArtifactReport.STATUS_UNCHANGED, OK, "", {
			"artifact_owner": GFGeneratedArtifactReport.OWNER_GENERATED,
		}),
		GFGeneratedArtifactReport.make_report("res://c.gd", GFGeneratedArtifactReport.STATUS_SKIPPED, ERR_ALREADY_EXISTS, "skip", {
			"artifact_owner": GFGeneratedArtifactReport.OWNER_USER,
			"dry_run": true,
		}),
	]

	var summary: Dictionary = GFGeneratedArtifactReport.summarize_reports(reports, "Accessors", {
		"include_reports": true,
	})
	var status_counts: Dictionary = GF_VARIANT_ACCESS.get_option_dictionary(summary, "status_counts")
	var owner_counts: Dictionary = GF_VARIANT_ACCESS.get_option_dictionary(summary, "owner_counts")

	assert_true(GF_VARIANT_ACCESS.get_option_bool(reports[2], "success"), "单个 skipped 报告不应被标记为 failed。")
	assert_true(GF_VARIANT_ACCESS.get_option_bool(summary, "success"), "skipped 不是 failed，批量摘要仍应成功。")
	assert_eq(GF_VARIANT_ACCESS.get_option_int(summary, "artifact_count"), 3, "摘要应统计产物数量。")
	assert_eq(GF_VARIANT_ACCESS.get_option_int(summary, "written_count"), 1, "摘要应统计写入数量。")
	assert_eq(GF_VARIANT_ACCESS.get_option_int(summary, "changed_count"), 1, "摘要应统计 changed 数量。")
	assert_eq(GF_VARIANT_ACCESS.get_option_int(summary, "dry_run_count"), 1, "摘要应统计 dry-run 数量。")
	assert_eq(GF_VARIANT_ACCESS.get_option_int(summary, "skipped_count"), 1, "摘要应统计 skipped 数量。")
	assert_eq(GF_VARIANT_ACCESS.get_option_int(status_counts, "new"), 1, "状态计数应包含 new。")
	assert_eq(GF_VARIANT_ACCESS.get_option_int(status_counts, "unchanged"), 1, "状态计数应包含 unchanged。")
	assert_eq(GF_VARIANT_ACCESS.get_option_int(status_counts, "skipped"), 1, "状态计数应包含 skipped。")
	assert_eq(GF_VARIANT_ACCESS.get_option_int(owner_counts, "generated"), 2, "所有权计数应包含 generated。")
	assert_eq(GF_VARIANT_ACCESS.get_option_int(owner_counts, "user"), 1, "所有权计数应包含 user。")
	assert_eq(GF_VARIANT_ACCESS.get_option_array(summary, "errors").size(), 1, "非 OK error_code 应进入 errors 便于审查。")
	assert_eq(GF_VARIANT_ACCESS.get_option_array(summary, "reports").size(), 3, "include_reports 应保留报告副本。")


func test_summarize_reports_returns_json_safe_metadata_and_reports() -> void:
	var raw_report: Dictionary = {
		"success": true,
		"path": "res://generated/raw.gd",
		"status": GFGeneratedArtifactReport.STATUS_NEW,
		"error_code": OK,
		"error": "",
		"written": true,
		"changed": true,
		"dry_run": false,
		"size_bytes": 5,
		"artifact_owner": GFGeneratedArtifactReport.OWNER_GENERATED,
		"generator_id": "test.generator",
		"source_id": "raw",
		"content_sha256": "abc",
		"previous_sha256": "",
		"encoding": "utf-8",
		"metadata": {
			"owner": self,
		},
	}
	var summary: Dictionary = GFGeneratedArtifactReport.summarize_reports([raw_report], "Safe", {
		"include_reports": true,
		"metadata": {
			"owner": self,
		},
	})
	var summary_metadata: Dictionary = GF_VARIANT_ACCESS.get_option_dictionary(summary, "metadata")
	var summary_owner_payload: Dictionary = GF_VARIANT_ACCESS.get_option_dictionary(summary_metadata, "owner")
	var summary_owner_marker: Dictionary = GF_VARIANT_ACCESS.get_option_dictionary(summary_owner_payload, "__gf_report_value__")
	var included_reports: Array = GF_VARIANT_ACCESS.get_option_array(summary, "reports")
	var included_report: Dictionary = {}
	if not included_reports.is_empty() and included_reports[0] is Dictionary:
		included_report = included_reports[0]
	var included_metadata: Dictionary = GF_VARIANT_ACCESS.get_option_dictionary(included_report, "metadata")
	var included_owner_payload: Dictionary = GF_VARIANT_ACCESS.get_option_dictionary(included_metadata, "owner")
	var included_owner_marker: Dictionary = GF_VARIANT_ACCESS.get_option_dictionary(included_owner_payload, "__gf_report_value__")

	assert_eq(GF_VARIANT_ACCESS.get_option_string(summary_owner_marker, "type"), "Object", "摘要 metadata 应通过报告边界编码。")
	assert_eq(GF_VARIANT_ACCESS.get_option_string(included_owner_marker, "type"), "Object", "include_reports 中的单项 metadata 应通过报告边界编码。")
	assert_false(JSON.stringify(summary).contains(":null"), "批量摘要应可直接 JSON.stringify()。")


func _read_user_text(path: String) -> String:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	var text: String = file.get_as_text()
	file.close()
	return text


func _count_user_files_with_prefix(prefix: String) -> int:
	var dir: DirAccess = DirAccess.open("user://")
	if dir == null:
		return 0
	var count: int = 0
	var _list_begin_error: Error = dir.list_dir_begin()
	while true:
		var file_name: String = dir.get_next()
		if file_name.is_empty():
			break
		if not dir.current_is_dir() and file_name.begins_with(prefix):
			count += 1
	dir.list_dir_end()
	return count
