@tool
## 测试配置表合并工具与构建 Profile。
extends GutTest


# --- 测试 ---

func test_merge_tables_updates_inserts_and_deletes_array_records() -> void:
	var base_rows: Array = [
		{
			"id": 1,
			"stats": { "hp": 10, "mp": 5 },
		},
		{
			"id": 2,
			"stats": { "hp": 20 },
		},
	]
	var patch_rows: Array = [
		{
			"id": 1,
			"stats": { "hp": 15 },
		},
		{
			"id": 3,
			"stats": { "hp": 30 },
		},
		{ "id": 2, "_delete": true },
	]

	var result: Dictionary = GFConfigTableMergeTools.merge_tables(base_rows, patch_rows)
	var merged_rows: Array = GFVariantData.get_option_array(result, "data")
	var first_row: Dictionary = GFVariantData.as_dictionary(merged_rows[0])
	var first_stats: Dictionary = GFVariantData.get_option_dictionary(first_row, "stats")
	var second_row: Dictionary = GFVariantData.as_dictionary(merged_rows[1])

	assert_true(
		GFVariantData.get_option_bool(result, "ok"),
		"合法补丁合并应成功。"
	)
	assert_eq(
		GFVariantData.get_option_int(result, "updated_count"),
		1,
		"应统计更新记录。"
	)
	assert_eq(
		GFVariantData.get_option_int(result, "inserted_count"),
		1,
		"应统计新增记录。"
	)
	assert_eq(
		GFVariantData.get_option_int(result, "deleted_count"),
		1,
		"应统计删除记录。"
	)
	assert_eq(
		merged_rows.size(),
		2,
		"删除一条并新增一条后应保留两条记录。"
	)
	assert_eq(
		GFVariantData.get_option_int(first_stats, "hp"),
		15,
		"嵌套字段应被补丁更新。"
	)
	assert_eq(
		GFVariantData.get_option_int(first_stats, "mp"),
		5,
		"未覆盖的嵌套字段应保留。"
	)
	assert_eq(
		GFVariantData.get_option_int(second_row, "id"),
		3,
		"新增记录应追加到末尾。"
	)


func test_dictionary_merge_rejects_outer_key_collision_without_partial_data() -> void:
	var policy: GFConfigTableMergePolicy = GFConfigTableMergePolicy.new()
	policy.allow_update = false
	var result: Dictionary = GFConfigTableMergeTools.merge_tables(
		{
			"slot": { "id": 1 },
		},
		{
			"slot": { "id": 2 },
		},
		policy
	)
	assert_false(GFVariantData.get_option_bool(result, "ok"))
	assert_true(result["data"] == null)
	assert_eq(
		GFVariantData.get_option_int(result, "inserted_count"),
		0
	)
	assert_true(
		_has_issue_kind(
			GFVariantData.get_option_array(result, "issues"),
			"outer_key_collision"
		)
	)


func test_merge_tables_can_use_dictionary_outer_keys() -> void:
	var policy: GFConfigTableMergePolicy = GFConfigTableMergePolicy.new()
	policy.key_fields = PackedStringArray()
	var result: Dictionary = GFConfigTableMergeTools.merge_tables(
		{
			"a": { "name": "A" },
		},
		{
			"a": { "name": "AA" },
			"b": { "name": "B" },
		},
		policy
	)
	var merged: Dictionary = GFVariantData.get_option_dictionary(result, "data")
	var row_a: Dictionary = GFVariantData.get_option_dictionary(merged, "a")
	var row_b: Dictionary = GFVariantData.get_option_dictionary(merged, "b")

	assert_true(
		GFVariantData.get_option_bool(result, "ok"),
		"Dictionary 表应可使用外层 key 合并。"
	)
	assert_eq(
		GFVariantData.get_option_string(row_a, "name"),
		"AA",
		"外层 key 相同的记录应更新。"
	)
	assert_eq(
		GFVariantData.get_option_string(row_b, "name"),
		"B",
		"新外层 key 应插入。"
	)


func test_merge_tables_reports_duplicate_base_keys() -> void:
	var result: Dictionary = GFConfigTableMergeTools.merge_tables(
		[
			{ "id": 1, "name": "A" },
			{ "id": 1, "name": "B" },
		],
		[]
	)

	assert_false(
		GFVariantData.get_option_bool(result, "ok"),
		"基础表合并键重复时应失败。"
	)
	assert_true(
		_has_issue_kind(
			GFVariantData.get_option_array(result, "issues"),
			"duplicate_base_key"
		),
		"应报告重复基础键。"
	)


func test_config_work_budget_rejects_invalid_limits_and_latches_failure() -> void:
	for limits: Dictionary in [
		{ "max_work_units": 0 },
		{ "max_input_bytes": -1 },
		{ "max_output_bytes": 1.5 },
		{ "max_value_bytes": true },
		{ "max_depth": 257 },
		{ "unknown": 1 },
	]:
		var budget: GFConfigWorkBudget = GFConfigWorkBudget.from_options({ "work_limits": limits })
		assert_false(budget.is_ok())
		var error_kind: Variant = budget.get_report()["error_kind"]
		var invalid_limits_reported: bool = error_kind is String and error_kind == "config_work_invalid_limits"
		assert_true(invalid_limits_reported)
		assert_false(
			budget.consume_work(0),
			"失败句柄不能恢复。"
		)
	var shared: GFConfigWorkBudget = GFConfigWorkBudget.new()
	var conflict: GFConfigWorkBudget = GFConfigWorkBudget.from_options({ "work_budget": shared, "work_limits": {}, })
	assert_same(conflict, shared)
	assert_false(
		shared.is_ok(),
		"重复声明不能通过生成新句柄绕过原批次失败。"
	)
	var malformed: GFConfigWorkBudget = GFConfigWorkBudget.from_options({ "work_budget": null })
	assert_false(malformed.is_ok())


func test_config_work_budget_tracks_bytes_without_overflow_or_report_aliases() -> void:
	var budget: GFConfigWorkBudget = GFConfigWorkBudget.new({ "max_input_bytes": 5 })
	assert_true(budget.check_input_bytes(5))
	var checked_input_bytes: Variant = budget.get_report()["usage"]["input_bytes"]
	var checked_input_uncharged: bool = checked_input_bytes is int and checked_input_bytes == 0
	assert_true(checked_input_uncharged)
	assert_true(budget.consume_input_bytes(3))
	var report: Dictionary = budget.get_report()
	report["limits"]["max_input_bytes"] = 100
	report["usage"]["input_bytes"] = 0
	assert_false(budget.consume_input_bytes(3))
	var rejected_report: Dictionary = budget.get_report()
	var error_kind: Variant = rejected_report["error_kind"]
	var consumed_input_bytes: Variant = rejected_report["usage"]["input_bytes"]
	var input_limit_reported: bool = error_kind is String and error_kind == "config_work_input_bytes_exceeded"
	assert_true(input_limit_reported)
	var accepted_input_preserved: bool = consumed_input_bytes is int and consumed_input_bytes == 3
	assert_true(accepted_input_preserved)
	var overflow: GFConfigWorkBudget = GFConfigWorkBudget.new({ "max_work_units": 9223372036854775807 })
	assert_true(overflow.consume_work(9223372036854775806))
	assert_false(
		overflow.consume_work(2),
		"先比较剩余额度，不允许 int 溢出变成负计数。"
	)


func test_config_work_budget_rejects_cycles_depth_width_and_payload_before_copy() -> void:
	var cyclic: Dictionary = { "id": 1 }
	cyclic["self"] = cyclic
	var cycle_result: Dictionary = GFConfigTableMergeTools.merge_tables(
		[cyclic],
		[]
	)
	var cycle_ok: Variant = cycle_result["ok"]
	var cycle_issues: Array = cycle_result["issues"]
	var cycle_rejected: bool = cycle_ok is bool and cycle_ok == false
	assert_true(cycle_rejected)
	assert_true(cycle_result["data"] == null)
	assert_true(_has_issue_kind(cycle_issues, "config_work_cycle"))
	cyclic.clear()
	var depth_result: Dictionary = GFConfigTableMergeTools.merge_tables(
		[
			{
				"id": 1,
				"nested": { "child": {} },
			},
		],
		[],
		null,
		{
			"work_limits": { "max_depth": 2 },
		}
	)
	var depth_ok: Variant = depth_result["ok"]
	var depth_issues: Array = depth_result["issues"]
	var depth_rejected: bool = depth_ok is bool and depth_ok == false
	assert_true(depth_rejected)
	assert_true(depth_result["data"] == null)
	assert_true(_has_issue_kind(depth_issues, "config_work_depth_exceeded"))
	var width_result: Dictionary = GFConfigTableMergeTools.merge_tables(
		[
			{ "id": 1 },
			{ "id": 2 },
			{ "id": 3 },
		],
		[],
		null,
		{
			"work_limits": { "max_work_units": 4 },
		}
	)
	var width_ok: Variant = width_result["ok"]
	var width_issues: Array = width_result["issues"]
	var width_rejected: bool = width_ok is bool and width_ok == false
	assert_true(width_rejected)
	assert_true(width_result["data"] == null)
	assert_true(_has_issue_kind(width_issues, "config_work_limit_exceeded"))
	var payload_budget: GFConfigWorkBudget = GFConfigWorkBudget.new({ "max_value_bytes": 3 })
	assert_false(payload_budget.admit_value("猫猫"))
	var payload_error_kind: Variant = payload_budget.get_report()["error_kind"]
	var payload_limit_reported: bool = payload_error_kind is String and payload_error_kind == "config_work_value_bytes_exceeded"
	assert_true(payload_limit_reported)


func test_config_work_budget_preserves_shared_subtrees_and_resource_leaves() -> void:
	var payload: Resource = Resource.new()
	var child: Dictionary = { "position": Vector2(2, 3), "payload": payload }
	var budget: GFConfigWorkBudget = GFConfigWorkBudget.new()
	assert_true(
		budget.admit_value([child, child]),
		"共享子容器不等于祖先链循环。"
	)
	assert_true(budget.admit_value(PackedVector3Array([Vector3.ONE])))
	var result: Dictionary = GFConfigTableMergeTools.merge_tables(
		[
			{ "id": 1, "child": child },
		],
		[]
	)
	var result_ok: Variant = result["ok"]
	var merge_succeeded: bool = result_ok is bool and result_ok == true
	assert_true(merge_succeeded)
	var copied_child: Dictionary = result["data"][0]["child"]
	var copied_payload: Variant = copied_child["payload"]
	assert_false(is_same(copied_child, child))
	assert_true(
		is_same(copied_payload, payload),
		"Resource 维持叶引用，不复制属性图。"
	)


func test_config_work_budget_counts_binary_blocks_and_exact_payload_bytes() -> void:
	var payload: PackedByteArray = PackedByteArray()
	var _resized: int = payload.resize(1_048_576)
	var budget: GFConfigWorkBudget = GFConfigWorkBudget.new({ "max_value_bytes": 1_048_576 })
	assert_true(budget.admit_value(payload))
	var usage: Dictionary = budget.get_report()["usage"]
	var work_units: Variant = usage["work_units"]
	var value_bytes: Variant = usage["value_bytes"]
	var work_blocks_match: bool = work_units is int and work_units == 1025
	assert_true(work_blocks_match, "一个根节点与 1024 个二进制工作块。")
	var value_bytes_match: bool = value_bytes is int and value_bytes == 1_048_576
	assert_true(value_bytes_match)
	var rejected: GFConfigWorkBudget = GFConfigWorkBudget.new({ "max_value_bytes": 1_048_575 })
	assert_false(rejected.admit_value(payload))
	var rejected_report: Dictionary = rejected.get_report()
	var rejected_error_kind: Variant = rejected_report["error_kind"]
	var rejected_value_bytes: Variant = rejected_report["usage"]["value_bytes"]
	var payload_limit_reported: bool = rejected_error_kind is String and rejected_error_kind == "config_work_value_bytes_exceeded"
	assert_true(payload_limit_reported)
	var rejected_payload_uncharged: bool = rejected_value_bytes is int and rejected_value_bytes == 0
	assert_true(rejected_payload_uncharged, "工作分块不能削弱实际载荷上限。")


func test_config_work_budget_counts_node_path_utf8_payload_at_exact_boundary() -> void:
	for fixture: Dictionary in [
		{ "path": NodePath(""), "bytes": 0 },
		{ "path": NodePath("/"), "bytes": 1 },
		{ "path": NodePath("猫"), "bytes": 3 },
		{ "path": NodePath(":位置"), "bytes": 7 },
		{ "path": NodePath("../猫:位置"), "bytes": 13 },
		{ "path": NodePath("猫/🐈:位置"), "bytes": 15 },
		{ "path": NodePath("/猫/房:位置:x"), "bytes": 17 },
	]:
		var path_value: NodePath = fixture["path"]
		var expected_bytes: int = fixture["bytes"]
		var budget: GFConfigWorkBudget = GFConfigWorkBudget.new({ "max_value_bytes": maxi(expected_bytes, 1) })
		assert_true(budget.admit_value(path_value, "node_path.boundary"))
		var value_bytes: Variant = budget.get_report()["usage"]["value_bytes"]
		var exact_payload: bool = value_bytes is int and value_bytes == expected_bytes
		assert_true(exact_payload, "NodePath 的路径分隔符、属性分隔符和多字节文字均计 UTF-8 载荷。")
		if expected_bytes > 1:
			var rejected: GFConfigWorkBudget = GFConfigWorkBudget.new({ "max_value_bytes": expected_bytes - 1 })
			assert_false(rejected.admit_value(path_value, "node_path.boundary"))
			var error_kind: Variant = rejected.get_report()["error_kind"]
			var payload_limit_reported: bool = error_kind is String and error_kind == "config_work_value_bytes_exceeded"
			assert_true(payload_limit_reported)


func test_merge_tables_preserves_node_path_values_and_bounds_their_payload() -> void:
	var path_value: NodePath = NodePath("猫".repeat(256) + ":位置")
	var source: Array = [
		{ "id": 1, "target": path_value },
	]
	var accepted: Dictionary = GFConfigTableMergeTools.merge_tables(source, [])
	var accepted_ok: bool = accepted["ok"] is bool and accepted["ok"] == true
	assert_true(accepted_ok)
	var merged_rows: Array = accepted["data"]
	var merged_path: Variant = merged_rows[0]["target"]
	var native_path_preserved: bool = merged_path is NodePath and merged_path == path_value
	assert_true(native_path_preserved, "载荷计量不能将原生 NodePath 转换为字符串。")
	var rejected: Dictionary = GFConfigTableMergeTools.merge_tables(
		source,
		[],
		null,
		{
			"work_limits": { "max_value_bytes": 64 },
		}
	)
	var rejected_ok: bool = rejected["ok"] is bool and rejected["ok"] == false
	var no_partial_data: bool = rejected["data"] == null
	var budget_report: Dictionary = rejected["budget_report"]
	var error_kind: Variant = budget_report["error_kind"]
	var error_context: Variant = budget_report["context"]
	var payload_limit_reported: bool = error_kind is String and error_kind == "config_work_value_bytes_exceeded"
	var rejected_before_copy: bool = error_context is String and error_context == "merge.base"
	assert_true(rejected_ok)
	assert_true(no_partial_data)
	assert_true(payload_limit_reported)
	assert_true(rejected_before_copy)


func test_merge_tables_isolates_custom_policy_hooks_before_late_failure() -> void:
	for hook_name: StringName in [
		&"make_record_key",
		&"is_delete_record",
		&"merge_record",
	]:
		for dictionary_table: bool in [false, true]:
			var base_rows: Array = [
				{
					"id": 1,
					"nested": {
						"values": [10],
					},
				},
			]
			var patch_rows: Array = [
				{
					"id": 1,
					"nested": {
						"values": [20],
					},
				},
				{
					"id": 2,
					"nested": {
						"values": [30],
					},
				},
			]
			var base_table: Variant = base_rows
			var patch_table: Variant = patch_rows
			if dictionary_table:
				base_table = { "one": base_rows[0] }
				patch_table = { "one": patch_rows[0], "two": patch_rows[1] }
			var original_base: Variant = GFVariantData.duplicate_variant(base_table)
			var original_patch: Variant = GFVariantData.duplicate_variant(patch_table)
			var policy: MutatingRecordPolicy = MutatingRecordPolicy.new()
			policy.mutation_hook = hook_name
			policy.allow_insert = false
			var result: Dictionary = GFConfigTableMergeTools.merge_tables(
				base_table,
				patch_table,
				policy
			)
			var merge_failed: bool = result["ok"] is bool and result["ok"] == false
			var no_partial_data: bool = result["data"] == null
			var prior_update_succeeded: bool = result["updated_count"] is int and result["updated_count"] == 1
			var base_unchanged: bool = base_table == original_base
			var patch_unchanged: bool = patch_table == original_patch
			var issues: Array = result["issues"]
			assert_gt(
				policy.mutation_count,
				0,
				"被测钩子必须实际修改收到的记录。"
			)
			assert_true(merge_failed)
			assert_true(no_partial_data)
			assert_true(prior_update_succeeded)
			assert_true(_has_issue_kind(issues, "insert_not_allowed"))
			assert_true(
				base_unchanged,
				"钩子不得改写调用方基础表及嵌套容器：%s。" % hook_name
			)
			assert_true(
				patch_unchanged,
				"钩子不得改写调用方补丁表及嵌套容器：%s。" % hook_name
			)


func test_merge_tables_isolates_container_outer_keys_before_late_failure() -> void:
	for dictionary_key: bool in [false, true]:
		var base_key: Variant = [
			"base",
			{
				"values": [10],
			},
		]
		var update_key: Variant = [
			"update",
			{
				"values": [20],
			},
		]
		var insert_key: Variant = [
			"insert",
			{
				"values": [30],
			},
		]
		if dictionary_key:
			base_key = {
				"slot": "base",
				"values": [10],
			}
			update_key = {
				"slot": "update",
				"values": [20],
			}
			insert_key = {
				"slot": "insert",
				"values": [30],
			}
		var original_base_key: Variant = GFVariantData.duplicate_variant(base_key)
		var original_update_key: Variant = GFVariantData.duplicate_variant(update_key)
		var original_insert_key: Variant = GFVariantData.duplicate_variant(insert_key)
		var base_table: Dictionary = {
			base_key: { "id": 1, "value": "before", },
		}
		var patch_table: Dictionary = {
			update_key: { "id": 1, "value": "updated", },
			insert_key: { "id": 2, "value": "inserted", },
		}
		var original_base: Dictionary = {
			original_base_key: { "id": 1, "value": "before", },
		}
		var original_patch: Dictionary = {
			original_update_key: { "id": 1, "value": "updated", },
			original_insert_key: { "id": 2, "value": "inserted", },
		}
		var policy: MutatingOuterKeyPolicy = MutatingOuterKeyPolicy.new()
		policy.allow_insert = false
		var result: Dictionary = GFConfigTableMergeTools.merge_tables(
			base_table,
			patch_table,
			policy
		)
		var merge_failed: bool = result["ok"] is bool and result["ok"] == false
		var no_partial_data: bool = result["data"] == null
		var prior_update_succeeded: bool = result["updated_count"] is int and result["updated_count"] == 1
		var base_key_unchanged: bool = base_key == original_base_key
		var update_key_unchanged: bool = update_key == original_update_key
		var insert_key_unchanged: bool = insert_key == original_insert_key
		var base_unchanged: bool = base_table == original_base
		var patch_unchanged: bool = patch_table == original_patch
		var issues: Array = result["issues"]
		assert_eq(
			policy.mutation_count,
			3,
			"钩子必须实际修改基础表和两条补丁的外层键。"
		)
		assert_true(merge_failed)
		assert_true(no_partial_data)
		assert_true(prior_update_succeeded)
		assert_true(_has_issue_kind(issues, "insert_not_allowed"))
		assert_true(base_key_unchanged, "基础表外层键及其嵌套容器必须隔离。")
		assert_true(update_key_unchanged, "更新补丁外层键及其嵌套容器必须隔离。")
		assert_true(insert_key_unchanged, "插入补丁外层键及其嵌套容器必须隔离。")
		assert_true(base_unchanged)
		assert_true(patch_unchanged)


func test_merge_tables_shares_work_across_operations_and_returns_no_partial_data() -> void:
	var measured: GFConfigWorkBudget = GFConfigWorkBudget.new()
	var first: Dictionary = GFConfigTableMergeTools.merge_tables(
		[
			{ "id": 1 },
		],
		[],
		null,
		{ "work_budget": measured }
	)
	var first_ok: Variant = first["ok"]
	var first_succeeded: bool = first_ok is bool and first_ok == true
	assert_true(first_succeeded)
	var first_work: int = measured.get_report()["usage"]["work_units"]
	var shared: GFConfigWorkBudget = GFConfigWorkBudget.new({ "max_work_units": first_work + 1 })
	var accepted: Dictionary = GFConfigTableMergeTools.merge_tables(
		[
			{ "id": 1 },
		],
		[],
		null,
		{ "work_budget": shared }
	)
	var accepted_ok: Variant = accepted["ok"]
	var accepted_succeeded: bool = accepted_ok is bool and accepted_ok == true
	assert_true(accepted_succeeded)
	var rejected: Dictionary = GFConfigTableMergeTools.merge_tables(
		[
			{ "id": 2 },
		],
		[],
		null,
		{ "work_budget": shared }
	)
	var rejected_ok: Variant = rejected["ok"]
	var rejected_issues: Array = rejected["issues"]
	var rejected_failed: bool = rejected_ok is bool and rejected_ok == false
	assert_true(rejected_failed)
	assert_true(rejected["data"] == null)
	assert_true(_has_issue_kind(rejected_issues, "config_work_limit_exceeded"))
	var late_failure: Dictionary = GFConfigTableMergeTools.merge_tables(
		[
			{ "id": 1, "value": "original" },
		],
		[
			{ "id": 1, "value": "changed" },
			{ "missing_key": true },
		]
	)
	var late_ok: Variant = late_failure["ok"]
	var late_failed: bool = late_ok is bool and late_ok == false
	assert_true(late_failed)
	assert_true(
		late_failure["data"] == null,
		"较早补丁成功也不能泄露部分合并结果。"
	)


func test_custom_policy_failure_or_invalid_success_discards_prior_updates() -> void:
	var base_rows: Array = [
		{
			"id": 1,
			"stats": { "hp": 10 },
		},
		{
			"id": 2,
			"stats": { "hp": 30 },
		},
	]
	var patch_rows: Array = [
		{
			"id": 1,
			"stats": { "hp": 20 },
		},
		{
			"id": 2,
			"stats": { "hp": 40 },
		},
	]
	var original_base: Array = base_rows.duplicate(true)
	var original_patch: Array = patch_rows.duplicate(true)
	for custom_result: Dictionary in [
		{
			"ok": false,
			"data": null,
			"error_kind": "policy_update_rejected",
			"error": "策略拒绝第二条更新。",
			"context": "custom.policy",
		},
		{ "ok": false },
		{ "ok": true, "data": null },
		{ "ok": true, "data": [] },
		{ "ok": true },
	]:
		var policy: RecordResultPolicy = RecordResultPolicy.new()
		policy.custom_result = custom_result
		var result: Dictionary = GFConfigTableMergeTools.merge_tables(
			base_rows,
			patch_rows,
			policy
		)
		var result_ok: Variant = result["ok"]
		var updated_count: Variant = result["updated_count"]
		var budget_ok: Variant = result["budget_report"]["ok"]
		var update_failed: bool = result_ok is bool and result_ok == false
		assert_true(update_failed)
		assert_true(
			result["data"] == null,
			"较早更新成功也不能泄露部分结果。"
		)
		var prior_update_count_matches: bool = updated_count is int and updated_count == 1
		assert_true(prior_update_count_matches)
		var budget_remains_ok: bool = budget_ok is bool and budget_ok == true
		assert_true(budget_remains_ok, "策略失败不能伪装成预算失败。")
		assert_eq(base_rows, original_base)
		assert_eq(patch_rows, original_patch)
		var issues: Array = result["issues"]
		assert_eq(
			issues.size(),
			1,
			"每条策略失败只登记一次。"
		)
		var issue: Dictionary = issues[0]
		var issue_row_key: Variant = issue["row_key"]
		var issue_kind: Variant = issue["kind"]
		var issue_message: Variant = issue["message"]
		var issue_row_matches: bool = issue_row_key is int and issue_row_key == 1
		assert_true(issue_row_matches)
		if GFVariantData.get_option_bool(custom_result, "ok"):
			var invalid_result_reported: bool = issue_kind is String and issue_kind == "invalid_merge_record_result"
			assert_true(invalid_result_reported)
		elif custom_result.has("error_kind"):
			var expected_kind: String = custom_result["error_kind"]
			var expected_message: String = custom_result["error"]
			var expected_source: String = custom_result["context"]
			var issue_source: Variant = issue["source"]
			var issue_kind_preserved: bool = issue_kind is String and issue_kind == expected_kind
			assert_true(issue_kind_preserved)
			var issue_message_preserved: bool = issue_message is String and issue_message == expected_message
			assert_true(issue_message_preserved)
			var issue_source_preserved: bool = issue_source is String and issue_source == expected_source
			assert_true(issue_source_preserved)
		else:
			var fallback_kind_matches: bool = issue_kind is String and issue_kind == "merge_record_failed"
			assert_true(fallback_kind_matches)
			var fallback_message_matches: bool = issue_message is String and issue_message == "合并策略拒绝更新记录。"
			assert_true(fallback_message_matches)


func test_policy_merge_record_reports_empty_success_and_budget_failure_distinctly() -> void:
	var policy: GFConfigTableMergePolicy = GFConfigTableMergePolicy.new()
	var empty_result: Dictionary = policy.merge_record({}, {})
	var empty_ok: Variant = empty_result["ok"]
	var empty_data: Variant = empty_result["data"]
	var empty_succeeded: bool = empty_ok is bool and empty_ok == true
	assert_true(empty_succeeded)
	assert_true(empty_data is Dictionary)
	if empty_data is Dictionary:
		var empty_record: Dictionary = empty_data
		assert_eq(empty_record, {})
	var failed: Dictionary = policy.merge_record(
		{
			"nested": { "value": 1 },
		},
		{},
		{
			"work_limits": { "max_depth": 1 },
		}
	)
	var failed_ok: Variant = failed["ok"]
	var error_kind: Variant = failed["error_kind"]
	var merge_failed: bool = failed_ok is bool and failed_ok == false
	assert_true(merge_failed)
	assert_true(failed["data"] == null)
	var depth_limit_reported: bool = error_kind is String and error_kind == "config_work_depth_exceeded"
	assert_true(depth_limit_reported)
	var base_record: Dictionary = {
		"nested": { "hp": 10, "mp": 5 },
	}
	var merged: Dictionary = policy.merge_record(
		base_record,
		{
			"nested": { "hp": 20 },
		}
	)
	var merged_ok: Variant = merged["ok"]
	var merged_nested: Variant = merged["data"]["nested"]
	var merge_succeeded: bool = merged_ok is bool and merged_ok == true
	assert_true(merge_succeeded)
	assert_true(merged_nested is Dictionary)
	if merged_nested is Dictionary:
		var nested_record: Dictionary = merged_nested
		assert_eq(
			nested_record,
			{ "hp": 20, "mp": 5 }
		)
	merged["data"]["nested"]["mp"] = 0
	var original_mp: Variant = base_record["nested"]["mp"]
	var original_mp_preserved: bool = original_mp is int and original_mp == 5
	assert_true(original_mp_preserved)


func test_merge_budget_failure_during_final_output_is_atomic() -> void:
	var measured: GFConfigWorkBudget = GFConfigWorkBudget.new()
	var source: Array = [
		{ "id": 1, "value": "original" },
	]
	var patch: Array = [
		{ "id": 1, "value": "changed" },
	]
	var baseline: Dictionary = GFConfigTableMergeTools.merge_tables(
		source,
		patch,
		null,
		{ "work_budget": measured }
	)
	var baseline_ok: Variant = baseline["ok"]
	var baseline_succeeded: bool = baseline_ok is bool and baseline_ok == true
	assert_true(baseline_succeeded)
	var required_work: int = measured.get_report()["usage"]["work_units"]
	var result: Dictionary = GFConfigTableMergeTools.merge_tables(
		source,
		patch,
		null,
		{
			"work_limits": { "max_work_units": required_work - 1 },
		}
	)
	var result_ok: Variant = result["ok"]
	var failure_context: Variant = result["budget_report"]["context"]
	var source_value: Variant = source[0]["value"]
	var patch_value: Variant = patch[0]["value"]
	var merge_failed: bool = result_ok is bool and result_ok == false
	assert_true(merge_failed)
	assert_true(result["data"] == null)
	var final_output_failed: bool = failure_context is String and failure_context == "merge.output"
	assert_true(final_output_failed)
	var original_source_preserved: bool = source_value is String and source_value == "original"
	assert_true(original_source_preserved)
	var original_patch_preserved: bool = patch_value is String and patch_value == "changed"
	assert_true(original_patch_preserved)


func test_merge_keys_require_stable_scalar_components_and_preserve_composite_boundaries() -> void:
	var policy: GFConfigTableMergePolicy = GFConfigTableMergePolicy.new()
	policy.key_fields = PackedStringArray(["first", "second"])
	var first_key: String = policy.make_record_key({ "first": "a|b", "second": "c" })
	var second_key: String = policy.make_record_key({ "first": "a", "second": "b|c" })
	assert_ne(first_key, second_key)
	policy.key_fields = PackedStringArray(["id"])
	for invalid_key: Variant in [
		[],
		{},
		Resource.new(),
		NAN,
		INF,
	]:
		var result: Dictionary = GFConfigTableMergeTools.merge_tables(
			[
				{ "id": invalid_key },
			],
			[],
			policy
		)
		var result_ok: Variant = result["ok"]
		var result_issues: Array = result["issues"]
		var invalid_key_rejected: bool = result_ok is bool and result_ok == false
		assert_true(invalid_key_rejected)
		assert_true(result["data"] == null)
		assert_true(_has_issue_kind(result_issues, "missing_base_key"))
	var reordered: Dictionary = GFConfigTableMergeTools.merge_tables(
		[
			{ "id": 1 },
			{ "id": 2 },
		],
		[
			{ "id": 1, "_delete": true },
			{ "id": 1 },
		]
	)
	var reordered_ok: Variant = reordered["ok"]
	var reordered_data: Variant = reordered["data"]
	var reinsert_succeeded: bool = reordered_ok is bool and reordered_ok == true
	assert_true(reinsert_succeeded)
	assert_true(reordered_data is Array)
	if reordered_data is Array:
		var reordered_rows: Array = reordered_data
		assert_eq(
			reordered_rows,
			[
				{ "id": 1 },
				{ "id": 2 },
			]
		)


func test_build_profile_filters_schema_and_records_by_metadata() -> void:
	var schema: GFConfigTableSchema = GFConfigTableSchema.new()
	schema.table_name = &"items"
	var id_column: GFConfigTableColumn = _make_column(&"id")
	var runtime_column: GFConfigTableColumn = _make_column(&"runtime_name")
	runtime_column.metadata = {
		"groups": ["runtime"],
	}
	var server_column: GFConfigTableColumn = _make_column(&"server_note")
	server_column.metadata = {
		"tags": ["server_only"],
	}
	schema.columns = [
		id_column,
		runtime_column,
		server_column,
	]
	var runtime_rule: GFConfigValidationRule = GFConfigValidationRule.new()
	runtime_rule.rule_id = &"runtime_rule"
	runtime_rule.metadata = {
		"groups": ["runtime"],
	}
	var server_rule: GFConfigValidationRule = GFConfigValidationRule.new()
	server_rule.rule_id = &"server_rule"
	server_rule.metadata = {
		"tags": ["server_only"],
	}
	schema.record_validation_rules = [runtime_rule, server_rule]
	schema.table_validation_rules = [server_rule]
	var runtime_field_rule: GFConfigValidationRule = GFConfigValidationRule.new()
	runtime_field_rule.rule_id = &"runtime_field_rule"
	runtime_field_rule.metadata = {
		"groups": ["runtime"],
	}
	var server_field_rule: GFConfigValidationRule = GFConfigValidationRule.new()
	server_field_rule.rule_id = &"server_field_rule"
	server_field_rule.metadata = {
		"tags": ["server_only"],
	}
	runtime_column.validation_rules = [runtime_field_rule, server_field_rule]
	var index: GFConfigTableIndexDefinition = GFConfigTableIndexDefinition.new()
	index.field_names = PackedStringArray(["runtime_name"])
	index.unique = true
	schema.indexes.append(index)

	var profile: GFConfigBuildProfile = GFConfigBuildProfile.new()
	profile.default_include = false
	profile.include_groups = PackedStringArray(["runtime"])
	profile.exclude_tags = PackedStringArray(["server_only"])

	var filtered_schema: GFConfigTableSchema = profile.filter_schema(schema)
	var filtered_records: Array = profile.filter_records(
		[
			{
				"id": 1,
				"runtime_name": "A",
				"_metadata": {
					"groups": ["runtime"],
				},
			},
			{
				"id": 2,
				"runtime_name": "B",
				"_metadata": {
					"tags": ["server_only"],
				},
			},
		]
	)
	var filtered_record: Dictionary = GFVariantData.as_dictionary(filtered_records[0])
	var filtered_runtime_column: GFConfigTableColumn = filtered_schema.get_column(&"runtime_name")

	assert_eq(
		filtered_schema.get_column_names(),
		PackedStringArray(["runtime_name"]),
		"Profile 应按列 metadata 裁剪 schema。"
	)
	assert_eq(
		filtered_schema.indexes.size(),
		1,
		"字段仍存在时索引应保留。"
	)
	assert_eq(
		filtered_schema.record_validation_rules.size(),
		1,
		"Profile 应按 rule metadata 裁剪记录规则。"
	)
	assert_eq(
		filtered_schema.record_validation_rules[0].get_rule_id(),
		&"runtime_rule",
		"Profile 应保留命中 runtime 分组的规则。"
	)
	assert_eq(
		filtered_schema.table_validation_rules.size(),
		0,
		"Profile 应移除被排除 metadata 命中的表规则。"
	)
	assert_eq(
		filtered_runtime_column.validation_rules.size(),
		1,
		"字段规则应使用与记录/表规则相同的 metadata profile。"
	)
	assert_eq(
		filtered_runtime_column.validation_rules[0].get_rule_id(),
		&"runtime_field_rule",
		"字段挂载位置不得绕过 rule metadata 裁剪。"
	)
	assert_eq(
		filtered_records.size(),
		1,
		"Profile 应按记录 metadata 裁剪数据。"
	)
	assert_eq(
		GFVariantData.get_option_int(filtered_record, "id"),
		1,
		"只应保留命中 runtime 分组的记录。"
	)


# --- 私有/辅助方法 ---

func _make_column(field_name: StringName) -> GFConfigTableColumn:
	var column: GFConfigTableColumn = GFConfigTableColumn.new()
	column.field_name = field_name
	column.value_type = GFConfigTableColumn.ValueType.STRING
	return column


func _has_issue_kind(issues: Array, kind: String) -> bool:
	for issue: Dictionary in issues:
		if GFVariantData.get_option_string(issue, "kind") == kind:
			return true
	return false


# --- 内部类 ---

class RecordResultPolicy extends GFConfigTableMergePolicy:
	var custom_result: Dictionary = {}


	func merge_record(
		base_record: Dictionary,
		patch_record: Dictionary,
		options: Dictionary = {}
	) -> Dictionary:
		if GFVariantData.get_option_int(patch_record, "id") == 2:
			return custom_result
		return super.merge_record(
			base_record,
			patch_record,
			options
		)


class MutatingRecordPolicy extends GFConfigTableMergePolicy:
	var mutation_hook: StringName = &""
	var mutation_count: int = 0


	func make_record_key(
		record: Dictionary,
		outer_key: Variant = null,
		options: Dictionary = {}
	) -> String:
		if mutation_hook == &"make_record_key":
			_mutate_record(record)
		return super.make_record_key(
			record,
			outer_key,
			options
		)


	func is_delete_record(record: Dictionary, options: Dictionary = {}) -> bool:
		if mutation_hook == &"is_delete_record":
			_mutate_record(record)
		return super.is_delete_record(record, options)


	func merge_record(
		base_record: Dictionary,
		patch_record: Dictionary,
		options: Dictionary = {}
	) -> Dictionary:
		if mutation_hook == &"merge_record":
			_mutate_record(base_record)
			_mutate_record(patch_record)
		return super.merge_record(
			base_record,
			patch_record,
			options
		)


	func _mutate_record(record: Dictionary) -> void:
		mutation_count += 1
		record["hook_marker"] = mutation_hook
		var nested: Dictionary = record["nested"]
		nested["hook_marker"] = mutation_hook
		var values: Array = nested["values"]
		values.append(mutation_hook)


class MutatingOuterKeyPolicy extends GFConfigTableMergePolicy:
	var mutation_count: int = 0


	func make_record_key(
		record: Dictionary,
		outer_key: Variant = null,
		options: Dictionary = {}
	) -> String:
		if outer_key is Array:
			var array_key: Array = outer_key
			array_key.append("hook_marker")
			var nested: Dictionary = array_key[1]
			var values: Array = nested["values"]
			values.append(99)
			mutation_count += 1
		elif outer_key is Dictionary:
			var dictionary_key: Dictionary = outer_key
			dictionary_key["hook_marker"] = true
			var values: Array = dictionary_key["values"]
			values.append(99)
			mutation_count += 1
		return super.make_record_key(
			record,
			outer_key,
			options
		)
