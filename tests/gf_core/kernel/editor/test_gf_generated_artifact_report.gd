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
