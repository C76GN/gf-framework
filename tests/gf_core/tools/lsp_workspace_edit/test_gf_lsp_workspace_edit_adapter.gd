extends GutTest

const _GF_LSP_WORKSPACE_EDIT_ADAPTER_SCRIPT = preload(
	"res://addons/gf/tools/lsp_workspace_edit/gf_lsp_workspace_edit_adapter.gd"
)

var _temporary_paths: Array[String] = []


func after_each() -> void:
	_GF_LSP_WORKSPACE_EDIT_ADAPTER_SCRIPT._reset_test_state()
	for path: String in _temporary_paths:
		if FileAccess.file_exists(path):
			var remove_error: Error = DirAccess.remove_absolute(
				ProjectSettings.globalize_path(path)
			)
			assert_eq(remove_error, OK, "测试临时脚本应被清理。")
	_temporary_paths.clear()


func test_build_and_commit_closed_workspace_edit() -> void:
	var target_path: String = _make_temporary_script_path("commit")
	var source_text: String = "var value = 1\n"
	_write_text(target_path, source_text)
	var target_uri: String = _resource_path_to_file_uri(target_path)
	var workspace_uri: String = _absolute_path_to_file_uri(
		ProjectSettings.globalize_path("res://")
	)
	var snapshot: Dictionary = _make_snapshot(
		workspace_uri,
		target_uri,
		7,
		source_text.sha256_text()
	)
	var workspace_edit: Dictionary = {
		"documentChanges": [{
			"textDocument": {
				"uri": target_uri,
				"version": 7,
			},
			"edits": [{
				"range": {
					"start": { "line": 0, "character": 12 },
					"end": { "line": 0, "character": 13 },
				},
				"newText": "2",
			}],
		}],
	}

	var plan: GFLspWorkspaceEditPlan = (
		_GF_LSP_WORKSPACE_EDIT_ADAPTER_SCRIPT.build_plan(
			workspace_edit,
			snapshot,
			{ "position_encoding": "utf-8" }
		)
	)
	assert_true(plan.is_valid(), "闭合、已保存且版本匹配的项目内 .gd edit 应通过计划。")
	assert_false(plan.get_plan_sha256().is_empty(), "有效计划必须绑定稳定 plan SHA-256。")

	var commit_report: Dictionary = (
		_GF_LSP_WORKSPACE_EDIT_ADAPTER_SCRIPT.commit_plan(plan, snapshot)
	)
	assert_true(
		GFVariantData.get_option_bool(commit_report, "ok"),
		"来源未漂移时事务提交应成功。"
	)
	assert_eq(FileAccess.get_file_as_string(target_path), "var value = 2\n")
	assert_true(plan.is_consumed(), "进入事务提交后计划必须一次性失效。")
	var second_commit: Dictionary = (
		_GF_LSP_WORKSPACE_EDIT_ADAPTER_SCRIPT.commit_plan(plan, snapshot)
	)
	assert_false(GFVariantData.get_option_bool(second_commit, "ok"))
	assert_eq(
		GFVariantData.get_option_string(second_commit, "status"),
		"plan_consumed",
		"同一计划不得重复进入文件写事务。"
	)


func test_utf16_positions_count_non_bmp_codepoint_as_surrogate_pair() -> void:
	var target_path: String = _make_temporary_script_path("utf16")
	var source_text: String = "var icon = \"😀x\"\n"
	_write_text(target_path, source_text)
	var target_uri: String = _resource_path_to_file_uri(target_path)
	var workspace_uri: String = _absolute_path_to_file_uri(
		ProjectSettings.globalize_path("res://")
	)
	var snapshot: Dictionary = _make_snapshot(
		workspace_uri,
		target_uri,
		4,
		source_text.sha256_text()
	)
	var plan: GFLspWorkspaceEditPlan = (
		_GF_LSP_WORKSPACE_EDIT_ADAPTER_SCRIPT.build_plan({
			"documentChanges": [{
				"textDocument": { "uri": target_uri, "version": 4 },
				"edits": [{
					"range": {
						"start": { "line": 0, "character": 14 },
						"end": { "line": 0, "character": 15 },
					},
					"newText": "y",
				}],
			}],
		}, snapshot, { "position_encoding": "utf-16" })
	)

	assert_true(plan.is_valid(), "UTF-16 非 BMP code point 后的合法边界应准确换算。")
	var commit_report: Dictionary = (
		_GF_LSP_WORKSPACE_EDIT_ADAPTER_SCRIPT.commit_plan(plan, snapshot)
	)
	assert_true(GFVariantData.get_option_bool(commit_report, "ok"))
	assert_eq(FileAccess.get_file_as_string(target_path), "var icon = \"😀y\"\n")


func test_long_crlf_line_reuses_utf8_boundaries_for_multiple_edits() -> void:
	var target_path: String = _make_temporary_script_path("long_crlf_boundaries")
	var prefix: String = "var data = \""
	var body: String = "a".repeat(16_384)
	var second_line: String = "var second = 1"
	var source_text: String = prefix + body + "😀tail\"\r\n" + second_line + "\r\n"
	_write_text(target_path, source_text)
	var target_uri: String = _resource_path_to_file_uri(target_path)
	var workspace_uri: String = _absolute_path_to_file_uri(
		ProjectSettings.globalize_path("res://")
	)
	var snapshot: Dictionary = _make_snapshot(
		workspace_uri,
		target_uri,
		10,
		source_text.sha256_text()
	)
	var body_start: int = prefix.length()
	var body_end: int = body_start + body.length()
	var tail_start_utf8: int = body_end + 4
	var second_value: int = second_line.find("1")
	_GF_LSP_WORKSPACE_EDIT_ADAPTER_SCRIPT._configure_test_position_line_scan_tracking(true)
	var plan: GFLspWorkspaceEditPlan = (
		_GF_LSP_WORKSPACE_EDIT_ADAPTER_SCRIPT.build_plan({
			"documentChanges": [{
				"textDocument": { "uri": target_uri, "version": 10 },
				"edits": [{
					"range": {
						"start": { "line": 0, "character": body_start },
						"end": { "line": 0, "character": body_start + 1 },
					},
					"newText": "b",
				}, {
					"range": {
						"start": { "line": 0, "character": body_end - 1 },
						"end": { "line": 0, "character": body_end },
					},
					"newText": "c",
				}, {
					"range": {
						"start": { "line": 0, "character": tail_start_utf8 },
						"end": { "line": 0, "character": tail_start_utf8 + 4 },
					},
					"newText": "done",
				}, {
					"range": {
						"start": { "line": 1, "character": second_value },
						"end": { "line": 1, "character": second_value + 1 },
					},
					"newText": "2",
				}],
			}],
		}, snapshot, { "position_encoding": "utf-8" })
	)

	assert_true(plan.is_valid(), "长行、CRLF 和非 BMP 后边界应在同一计划中准确换算。")
	assert_eq(
		_GF_LSP_WORKSPACE_EDIT_ADAPTER_SCRIPT._get_test_position_line_scan_count(0),
		1,
		"同一引用行只能为 position boundary 扫描一次。"
	)
	assert_eq(
		_GF_LSP_WORKSPACE_EDIT_ADAPTER_SCRIPT._get_test_position_line_scan_count(1),
		1,
		"不同引用行各自最多扫描一次。"
	)
	var commit_report: Dictionary = (
		_GF_LSP_WORKSPACE_EDIT_ADAPTER_SCRIPT.commit_plan(plan, snapshot)
	)
	assert_true(GFVariantData.get_option_bool(commit_report, "ok"))
	var expected_body: String = "b" + "a".repeat(body.length() - 2) + "c"
	assert_eq(
		FileAccess.get_file_as_string(target_path),
		prefix + expected_body + "😀done\"\r\nvar second = 2\r\n",
		"位置换算不得改变 CRLF 或非目标文本。"
	)


func test_commit_rejects_disk_source_drift_before_consuming_plan() -> void:
	var target_path: String = _make_temporary_script_path("drift")
	var source_text: String = "var value = 1\n"
	_write_text(target_path, source_text)
	var target_uri: String = _resource_path_to_file_uri(target_path)
	var workspace_uri: String = _absolute_path_to_file_uri(
		ProjectSettings.globalize_path("res://")
	)
	var snapshot: Dictionary = _make_snapshot(
		workspace_uri,
		target_uri,
		8,
		source_text.sha256_text()
	)
	var plan: GFLspWorkspaceEditPlan = (
		_GF_LSP_WORKSPACE_EDIT_ADAPTER_SCRIPT.build_plan({
			"documentChanges": [{
				"textDocument": { "uri": target_uri, "version": 8 },
				"edits": [{
					"range": {
						"start": { "line": 0, "character": 12 },
						"end": { "line": 0, "character": 13 },
					},
					"newText": "2",
				}],
			}],
		}, snapshot, { "position_encoding": "utf-8" })
	)
	assert_true(plan.is_valid())
	_write_text(target_path, "var value = 9\n")

	var commit_report: Dictionary = (
		_GF_LSP_WORKSPACE_EDIT_ADAPTER_SCRIPT.commit_plan(plan, snapshot)
	)
	assert_false(GFVariantData.get_option_bool(commit_report, "ok"))
	assert_eq(GFVariantData.get_option_string(commit_report, "status"), "stale_plan")
	assert_false(plan.is_consumed(), "事务尚未开始时的漂移拒绝不应消费计划。")
	assert_eq(FileAccess.get_file_as_string(target_path), "var value = 9\n")


func test_commit_compare_exchange_rejects_drift_after_freshness_check() -> void:
	var fixture: Dictionary = _make_valid_fixture("compare_exchange", 8, "var value = 1\n")
	var target_path: String = GFVariantData.get_option_string(fixture, "target_path")
	var target_uri: String = GFVariantData.get_option_string(fixture, "target_uri")
	var snapshot: Dictionary = GFVariantData.get_option_dictionary(fixture, "snapshot")
	var plan: GFLspWorkspaceEditPlan = (
		_GF_LSP_WORKSPACE_EDIT_ADAPTER_SCRIPT.build_plan({
			"documentChanges": [{
				"textDocument": { "uri": target_uri, "version": 8 },
				"edits": [{
					"range": {
						"start": { "line": 0, "character": 12 },
						"end": { "line": 0, "character": 13 },
					},
					"newText": "2",
				}],
			}],
		}, snapshot, { "position_encoding": "utf-8" })
	)
	assert_true(plan.is_valid())
	var concurrent_text: String = "var value = 9\n"
	_GF_LSP_WORKSPACE_EDIT_ADAPTER_SCRIPT._configure_test_before_artifact_commit(
		Callable(self, "_rewrite_target_for_compare_exchange").bind(
			target_path,
			concurrent_text
		)
	)

	var commit_report: Dictionary = (
		_GF_LSP_WORKSPACE_EDIT_ADAPTER_SCRIPT.commit_plan(plan, snapshot)
	)

	assert_false(
		GFVariantData.get_option_bool(commit_report, "ok"),
		"freshness 与 artifact commit 之间的并发写入必须由 old-hash CAS 拒绝。"
	)
	assert_eq(GFVariantData.get_option_string(commit_report, "status"), "transaction_failed")
	assert_true(plan.is_consumed(), "进入写事务边界后的计划必须保持一次性语义。")
	assert_eq(
		FileAccess.get_file_as_string(target_path),
		concurrent_text,
		"CAS 失败不得覆盖并发写入。"
	)


func test_position_encoding_rejects_offsets_inside_non_bmp_codepoint() -> void:
	var fixture: Dictionary = _make_valid_fixture("split", 3, "var icon = \"😀x\"\n")
	for encoding: String in ["utf-8", "utf-16"]:
		var plan: GFLspWorkspaceEditPlan = (
			_GF_LSP_WORKSPACE_EDIT_ADAPTER_SCRIPT.build_plan({
				"documentChanges": [{
					"textDocument": {
						"uri": GFVariantData.get_option_string(fixture, "target_uri"),
						"version": 3,
					},
					"edits": [{
						"range": {
							"start": { "line": 0, "character": 13 },
							"end": { "line": 0, "character": 14 },
						},
						"newText": "z",
					}],
				}],
			}, GFVariantData.get_option_dictionary(fixture, "snapshot"), {
				"position_encoding": encoding,
			})
		)
		assert_false(plan.is_valid(), "%s 不得接受 code point 内部坐标。" % encoding)
		assert_true(_plan_has_issue(plan, "position_splits_codepoint"))


func test_build_rejects_unsaved_target() -> void:
	var fixture: Dictionary = _make_valid_fixture("unsaved", 2, "var value = 1\n")
	var snapshot: Dictionary = GFVariantData.get_option_dictionary(
		fixture,
		"snapshot"
	).duplicate(true)
	var documents: Array = GFVariantData.get_option_array(snapshot, "documents")
	var document: Dictionary = GFVariantData.as_dictionary(documents[0])
	document["saved"] = false
	documents[0] = document
	snapshot["documents"] = documents
	var target_uri: String = GFVariantData.get_option_string(fixture, "target_uri")
	var plan: GFLspWorkspaceEditPlan = (
		_GF_LSP_WORKSPACE_EDIT_ADAPTER_SCRIPT.build_plan({
			"documentChanges": [{
				"textDocument": { "uri": target_uri, "version": 2 },
				"edits": [{
					"range": {
						"start": { "line": 0, "character": 12 },
						"end": { "line": 0, "character": 13 },
					},
					"newText": "2",
				}],
			}],
		}, snapshot, { "position_encoding": "utf-8" })
	)

	assert_false(plan.is_valid(), "适配器不得推测未保存缓冲区的真实来源。")
	assert_true(_plan_has_issue(plan, "unsaved_document"))


func test_build_rejects_overlapping_text_edits() -> void:
	var fixture: Dictionary = _make_valid_fixture("overlap", 5, "var value = 123\n")
	var target_uri: String = GFVariantData.get_option_string(fixture, "target_uri")
	var plan: GFLspWorkspaceEditPlan = (
		_GF_LSP_WORKSPACE_EDIT_ADAPTER_SCRIPT.build_plan({
			"documentChanges": [{
				"textDocument": { "uri": target_uri, "version": 5 },
				"edits": [{
					"range": {
						"start": { "line": 0, "character": 12 },
						"end": { "line": 0, "character": 15 },
					},
					"newText": "1",
				}, {
					"range": {
						"start": { "line": 0, "character": 13 },
						"end": { "line": 0, "character": 14 },
					},
					"newText": "2",
				}],
			}],
		}, GFVariantData.get_option_dictionary(fixture, "snapshot"), {
			"position_encoding": "utf-8",
		})
	)

	assert_false(plan.is_valid(), "互相覆盖的 LSP edits 不得依赖调用方顺序。")
	assert_true(_plan_has_issue(plan, "overlapping_edits"))


func test_build_rejects_file_resource_operations() -> void:
	var fixture: Dictionary = _make_valid_fixture("resource_op", 1, "var value = 1\n")
	var target_uri: String = GFVariantData.get_option_string(fixture, "target_uri")
	var plan: GFLspWorkspaceEditPlan = (
		_GF_LSP_WORKSPACE_EDIT_ADAPTER_SCRIPT.build_plan({
			"documentChanges": [{
				"kind": "rename",
				"oldUri": target_uri,
				"newUri": target_uri + ".moved",
			}],
		}, GFVariantData.get_option_dictionary(fixture, "snapshot"), {
			"position_encoding": "utf-8",
		})
	)

	assert_false(plan.is_valid(), "文本适配器不得接受 create/rename/delete 文件操作。")
	assert_true(_plan_has_issue(plan, "file_resource_operation_not_supported"))


func test_build_rejects_target_outside_current_project() -> void:
	var outside_uri: String = _absolute_path_to_file_uri(
		ProjectSettings.globalize_path("user://outside_workspace_edit.gd")
	)
	var workspace_uri: String = _absolute_path_to_file_uri(
		ProjectSettings.globalize_path("res://")
	)
	var snapshot: Dictionary = _make_snapshot(
		workspace_uri,
		outside_uri,
		1,
		"0".repeat(64)
	)
	var plan: GFLspWorkspaceEditPlan = (
		_GF_LSP_WORKSPACE_EDIT_ADAPTER_SCRIPT.build_plan({
			"documentChanges": [{
				"textDocument": { "uri": outside_uri, "version": 1 },
				"edits": [{
					"range": {
						"start": { "line": 0, "character": 0 },
						"end": { "line": 0, "character": 0 },
					},
					"newText": "extends RefCounted\n",
				}],
			}],
		}, snapshot, { "position_encoding": "utf-8" })
	)

	assert_false(plan.is_valid(), "file:// 目标必须严格位于当前 res:// 内。")
	assert_true(_plan_has_issue(plan, "target_outside_workspace"))


func test_build_rejects_workspace_root_with_wrong_case() -> void:
	var fixture: Dictionary = _make_valid_fixture("wrong_case_root", 1, "var value = 1\n")
	var snapshot: Dictionary = GFVariantData.get_option_dictionary(
		fixture,
		"snapshot"
	).duplicate(true)
	var actual_root: String = ProjectSettings.globalize_path("res://")
	var wrong_case_root: String = _change_first_ascii_letter_case(actual_root)
	assert_ne(wrong_case_root, actual_root, "测试工作区路径必须具有可改变大小写的字符。")
	snapshot["workspace_uri"] = _absolute_path_to_file_uri(wrong_case_root)
	var target_uri: String = GFVariantData.get_option_string(fixture, "target_uri")
	var plan: GFLspWorkspaceEditPlan = (
		_GF_LSP_WORKSPACE_EDIT_ADAPTER_SCRIPT.build_plan({
			"documentChanges": [{
				"textDocument": { "uri": target_uri, "version": 1 },
				"edits": [{
					"range": {
						"start": { "line": 0, "character": 12 },
						"end": { "line": 0, "character": 13 },
					},
					"newText": "2",
				}],
			}],
		}, snapshot, { "position_encoding": "utf-8" })
	)

	assert_false(plan.is_valid(), "宿主真实工作区路径大小写不精确时必须失败关闭。")
	assert_true(_plan_has_issue(plan, "workspace_identity_mismatch"))


func test_build_rejects_target_with_wrong_case() -> void:
	var fixture: Dictionary = _make_valid_fixture("wrong_case_target", 1, "var value = 1\n")
	var target_path: String = GFVariantData.get_option_string(fixture, "target_path")
	var target_absolute_path: String = ProjectSettings.globalize_path(target_path)
	var wrong_case_target: String = _change_first_ascii_letter_case(target_absolute_path)
	assert_ne(wrong_case_target, target_absolute_path, "测试目标路径必须具有可改变大小写的字符。")
	var wrong_target_uri: String = _absolute_path_to_file_uri(wrong_case_target)
	var snapshot: Dictionary = GFVariantData.get_option_dictionary(
		fixture,
		"snapshot"
	).duplicate(true)
	var documents: Array = GFVariantData.get_option_array(snapshot, "documents")
	var document: Dictionary = GFVariantData.as_dictionary(documents[0]).duplicate(true)
	document["uri"] = wrong_target_uri
	documents[0] = document
	snapshot["documents"] = documents
	var plan: GFLspWorkspaceEditPlan = (
		_GF_LSP_WORKSPACE_EDIT_ADAPTER_SCRIPT.build_plan({
			"documentChanges": [{
				"textDocument": { "uri": wrong_target_uri, "version": 1 },
				"edits": [{
					"range": {
						"start": { "line": 0, "character": 12 },
						"end": { "line": 0, "character": 13 },
					},
					"newText": "2",
				}],
			}],
		}, snapshot, { "position_encoding": "utf-8" })
	)

	assert_false(plan.is_valid(), "目标宿主路径大小写不精确时必须失败关闭。")
	assert_true(_plan_has_issue(plan, "target_outside_workspace"))


func test_build_rejects_portable_path_collision() -> void:
	var fixture: Dictionary = _make_valid_fixture("collision", 1, "var value = 1\n")
	var snapshot: Dictionary = GFVariantData.get_option_dictionary(
		fixture,
		"snapshot"
	).duplicate(true)
	var documents: Array = GFVariantData.get_option_array(snapshot, "documents")
	documents.append(GFVariantData.as_dictionary(documents[0]).duplicate(true))
	snapshot["documents"] = documents
	var target_uri: String = GFVariantData.get_option_string(fixture, "target_uri")
	var plan: GFLspWorkspaceEditPlan = (
		_GF_LSP_WORKSPACE_EDIT_ADAPTER_SCRIPT.build_plan({
			"documentChanges": [{
				"textDocument": { "uri": target_uri, "version": 1 },
				"edits": [{
					"range": {
						"start": { "line": 0, "character": 12 },
						"end": { "line": 0, "character": 13 },
					},
					"newText": "2",
				}],
			}],
		}, snapshot, { "position_encoding": "utf-8" })
	)

	assert_false(plan.is_valid(), "portable identity 下重复或大小写碰撞的目标必须拒绝。")
	assert_true(_plan_has_issue(plan, "portable_path_collision"))


func test_build_enforces_file_byte_budget() -> void:
	var fixture: Dictionary = _make_valid_fixture("budget", 1, "var value = 1\n")
	var target_uri: String = GFVariantData.get_option_string(fixture, "target_uri")
	var plan: GFLspWorkspaceEditPlan = (
		_GF_LSP_WORKSPACE_EDIT_ADAPTER_SCRIPT.build_plan({
			"documentChanges": [{
				"textDocument": { "uri": target_uri, "version": 1 },
				"edits": [{
					"range": {
						"start": { "line": 0, "character": 12 },
						"end": { "line": 0, "character": 13 },
					},
					"newText": "2",
				}],
			}],
		}, GFVariantData.get_option_dictionary(fixture, "snapshot"), {
			"position_encoding": "utf-8",
			"max_file_bytes": 4,
		})
	)

	assert_false(plan.is_valid(), "调用方预算必须在读取完整目标前生效。")
	assert_true(_plan_has_issue(plan, "source_file_budget_exceeded"))


func test_snapshot_document_count_budget_fails_before_parsing_entries() -> void:
	var workspace_uri: String = _absolute_path_to_file_uri(
		ProjectSettings.globalize_path("res://")
	)
	var plan: GFLspWorkspaceEditPlan = (
		_GF_LSP_WORKSPACE_EDIT_ADAPTER_SCRIPT.build_plan({
			"documentChanges": [],
		}, {
			"workspace_uri": workspace_uri,
			"workspace_version": 1,
			"documents": [null, null],
		}, {
			"position_encoding": "utf-8",
			"max_file_count": 1,
		})
	)
	var issues: Array = GFVariantData.get_option_array(plan.get_report(), "issues")

	assert_false(plan.is_valid(), "超出 document count 预算的快照必须失败关闭。")
	assert_eq(issues.size(), 1, "计数超限后不得继续解析未受预算约束的 document 项。")
	assert_true(_plan_has_issue(plan, "document_count_budget_exceeded"))


func test_commit_rejects_workspace_version_drift() -> void:
	var fixture: Dictionary = _make_valid_fixture("workspace_version", 6, "var value = 1\n")
	var target_uri: String = GFVariantData.get_option_string(fixture, "target_uri")
	var snapshot: Dictionary = GFVariantData.get_option_dictionary(fixture, "snapshot")
	var plan: GFLspWorkspaceEditPlan = (
		_GF_LSP_WORKSPACE_EDIT_ADAPTER_SCRIPT.build_plan({
			"documentChanges": [{
				"textDocument": { "uri": target_uri, "version": 6 },
				"edits": [{
					"range": {
						"start": { "line": 0, "character": 12 },
						"end": { "line": 0, "character": 13 },
					},
					"newText": "2",
				}],
			}],
		}, snapshot, { "position_encoding": "utf-8" })
	)
	assert_true(plan.is_valid())
	var fresh_snapshot: Dictionary = snapshot.duplicate(true)
	fresh_snapshot["workspace_version"] = 2

	var commit_report: Dictionary = (
		_GF_LSP_WORKSPACE_EDIT_ADAPTER_SCRIPT.commit_plan(plan, fresh_snapshot)
	)
	assert_false(GFVariantData.get_option_bool(commit_report, "ok"))
	assert_eq(GFVariantData.get_option_string(commit_report, "status"), "stale_plan")
	assert_false(plan.is_consumed())


func _make_temporary_script_path(label: String) -> String:
	return (
		"res://tests/gf_core/tools/lsp_workspace_edit/"
		+ ".gf_lsp_workspace_edit_%s_%d.gd" % [label, Time.get_ticks_usec()]
	)


func _make_valid_fixture(label: String, version: int, source_text: String) -> Dictionary:
	var target_path: String = _make_temporary_script_path(label)
	_write_text(target_path, source_text)
	var target_uri: String = _resource_path_to_file_uri(target_path)
	var workspace_uri: String = _absolute_path_to_file_uri(
		ProjectSettings.globalize_path("res://")
	)
	return {
		"target_path": target_path,
		"target_uri": target_uri,
		"workspace_uri": workspace_uri,
		"snapshot": _make_snapshot(
			workspace_uri,
			target_uri,
			version,
			source_text.sha256_text()
		),
	}


func _plan_has_issue(plan: GFLspWorkspaceEditPlan, expected_kind: String) -> bool:
	for value: Variant in GFVariantData.get_option_array(plan.get_report(), "issues"):
		if value is Dictionary:
			var issue: Dictionary = value
			if GFVariantData.get_option_string(issue, "kind") == expected_kind:
				return true
	return false


func _write_text(path: String, text: String) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	assert_not_null(file, "测试应能创建临时 GDScript。")
	if file == null:
		return
	var stored: bool = file.store_string(text)
	assert_true(stored, "测试临时 GDScript 必须完整写入。")
	file.close()
	_temporary_paths.append(path)


func _make_snapshot(
	workspace_uri: String,
	target_uri: String,
	document_version: int,
	source_sha256: String
) -> Dictionary:
	return {
		"workspace_uri": workspace_uri,
		"workspace_version": 1,
		"documents": [{
			"uri": target_uri,
			"version": document_version,
			"saved": true,
			"source_sha256": source_sha256,
		}],
	}


func _resource_path_to_file_uri(resource_path: String) -> String:
	return _absolute_path_to_file_uri(ProjectSettings.globalize_path(resource_path))


func _absolute_path_to_file_uri(absolute_path: String) -> String:
	var normalized: String = absolute_path.replace("\\", "/").simplify_path()
	var encoded: String = normalized.replace("%", "%25")
	encoded = encoded.replace(" ", "%20").replace("#", "%23").replace("?", "%3F")
	if encoded.length() >= 3 and encoded.substr(1, 2) == ":/":
		return "file:///" + encoded
	return "file://" + encoded


func _change_first_ascii_letter_case(value: String) -> String:
	for index: int in range(value.length()):
		var character: String = value.substr(index, 1)
		if character >= "A" and character <= "Z":
			return value.substr(0, index) + character.to_lower() + value.substr(index + 1)
		if character >= "a" and character <= "z":
			return value.substr(0, index) + character.to_upper() + value.substr(index + 1)
	return value


func _rewrite_target_for_compare_exchange(path: String, text: String) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	assert_not_null(file, "并发写入夹具必须能打开目标。")
	if file == null:
		return
	var stored: bool = file.store_string(text)
	assert_true(stored, "并发写入夹具必须完整改写目标。")
	file.close()
