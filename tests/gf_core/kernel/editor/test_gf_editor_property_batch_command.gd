## 测试通用多目标属性事务命令。
@tool

extends GutTest


const GF_VARIANT_ACCESS = preload("res://addons/gf/kernel/core/gf_variant_access.gd")


# --- 测试 ---

func test_preflight_failure_keeps_every_target_unchanged() -> void:
	var first: ControlledTarget = ControlledTarget.new(1)
	var second: ValueTarget = ValueTarget.new()
	second.value = 2
	var command: GFEditorPropertyBatchCommand = GFEditorPropertyBatchCommand.new()
	var _configured: GFEditorPropertyBatchCommand = command.configure([
		{
			"target": first,
			"property_name": &"value",
			"new_value": 10,
		},
		{
			"target": second,
			"property_name": &"missing",
			"new_value": 20,
		},
	])

	var validation: Dictionary = command.validate()
	var execute_error: Error = command.execute()
	var report: Dictionary = command.get_transaction_report()

	assert_false(
		GF_VARIANT_ACCESS.get_option_bool(validation, "ok"),
		"任一条目无效时必须让整批预检失败。"
	)
	assert_eq(
		GF_VARIANT_ACCESS.get_option_string_name(validation, "status"),
		&"preflight_failed"
	)
	assert_eq(execute_error, ERR_UNAVAILABLE, "预检失败的命令不应进入写阶段。")
	assert_eq(first.stored_value, 1, "前置有效条目也不得提前写入。")
	assert_eq(first.set_attempts, 0, "零写入预检不得触发 setter。")
	assert_eq(second.value, 2)
	assert_eq(
		GF_VARIANT_ACCESS.get_option_string_name(report, "status"),
		&"preflight_failed",
		"失败报告应保留预检阶段。"
	)


func test_multi_target_execute_undo_and_redo_keep_first_snapshot() -> void:
	var first: ControlledTarget = ControlledTarget.new(1)
	var second: ControlledTarget = ControlledTarget.new(2)
	var command: GFEditorPropertyBatchCommand = GFEditorPropertyBatchCommand.new()
	var _configured: GFEditorPropertyBatchCommand = command.configure([
		{
			"target": first,
			"property_name": &"value",
			"new_value": 10,
		},
		{
			"target": second,
			"property_name": &"value",
			"new_value": 20,
		},
	], {
		"command_name": "Edit Multiple Values",
	})

	assert_eq(command.execute(), OK, "多目标事务应能一次提交。")
	assert_eq(first.stored_value, 10)
	assert_eq(second.stored_value, 20)
	assert_true(command.is_executed())
	assert_true(command.is_sealed(), "进入首次写阶段后配置必须冻结。")

	assert_eq(command.revert(), OK, "undo 应反序恢复首次执行前快照。")
	assert_eq(first.stored_value, 1)
	assert_eq(second.stored_value, 2)

	first.stored_value = 77
	assert_eq(command.execute(), OK, "redo 应复用原命令配置。")
	assert_eq(first.stored_value, 10)
	assert_eq(second.stored_value, 20)
	assert_eq(command.revert(), OK)
	assert_eq(first.stored_value, 1, "redo 后的 undo 不得把中间态刷新成新基线。")
	assert_eq(second.stored_value, 2)


func test_failed_redo_recovery_restores_redo_attempt_guard() -> void:
	var first: ControlledTarget = ControlledTarget.new(1)
	var second: ControlledTarget = ControlledTarget.new(2)
	var command: GFEditorPropertyBatchCommand = GFEditorPropertyBatchCommand.new()
	var _configured: GFEditorPropertyBatchCommand = command.configure([
		{
			"target": first,
			"property_name": &"value",
			"new_value": 10,
		},
		{
			"target": second,
			"property_name": &"value",
			"new_value": 20,
		},
	])
	assert_eq(command.execute(), OK)
	assert_eq(command.revert(), OK)

	first.stored_value = 77
	second.rejected_values.append(20)
	second.before_set = func(requested_value: int) -> void:
		if requested_value == 20 and not first.rejected_values.has(77):
			first.rejected_values.append(77)

	assert_ne(command.execute(), OK, "redo 写入及补偿失败时应留下 recovery guard。")
	assert_true(
		GF_VARIANT_ACCESS.get_option_bool(
			command.get_transaction_report(),
			"recovery_required"
		)
	)
	assert_eq(first.stored_value, 10)

	first.rejected_values.clear()
	second.rejected_values.clear()
	second.before_set = Callable()
	assert_eq(
		command.revert(),
		OK,
		"未 executed 的 redo 残余应允许通过 revert 恢复本次 attempt guard。"
	)
	assert_eq(first.stored_value, 77, "恢复不得覆盖 redo 前的外部状态。")
	assert_eq(second.stored_value, 2)


func test_setter_rejection_rolls_back_prior_target() -> void:
	var first: ControlledTarget = ControlledTarget.new(1)
	var second: ControlledTarget = ControlledTarget.new(2)
	second.rejected_values.append(20)
	var command: GFEditorPropertyBatchCommand = GFEditorPropertyBatchCommand.new()
	var _configured: GFEditorPropertyBatchCommand = command.configure([
		{
			"target": first,
			"property_name": &"value",
			"new_value": 10,
		},
		{
			"target": second,
			"property_name": &"value",
			"new_value": 20,
		},
	])

	var execute_error: Error = command.execute()
	var report: Dictionary = command.get_transaction_report()

	assert_ne(execute_error, OK, "运行期 setter 拒绝必须让事务失败。")
	assert_eq(first.stored_value, 1, "前面已成功写入的目标必须恢复。")
	assert_eq(second.stored_value, 2)
	assert_true(
		GF_VARIANT_ACCESS.get_option_bool(report, "rolled_back"),
		"完整恢复 attempt guard 后报告应明确 rolled_back。"
	)
	assert_false(
		GF_VARIANT_ACCESS.get_option_bool(report, "recovery_required"),
		"完整回滚不应要求人工恢复。"
	)
	assert_eq(
		GF_VARIANT_ACCESS.get_option_string_name(report, "status"),
		&"apply_failed"
	)


func test_final_verification_rolls_back_cross_setter_pollution() -> void:
	var first: ControlledTarget = ControlledTarget.new(1)
	var second: ControlledTarget = ControlledTarget.new(2)
	second.before_set = func(requested_value: int) -> void:
		if requested_value == 20:
			first.stored_value = 999
	var command: GFEditorPropertyBatchCommand = GFEditorPropertyBatchCommand.new()
	var _configured: GFEditorPropertyBatchCommand = command.configure([
		{
			"target": first,
			"property_name": &"value",
			"new_value": 10,
		},
		{
			"target": second,
			"property_name": &"value",
			"new_value": 20,
		},
	])

	var execute_error: Error = command.execute()
	var report: Dictionary = command.get_transaction_report()

	assert_ne(
		execute_error,
		OK,
		"后续 setter 污染先前目标时，最终状态验证必须让事务失败。"
	)
	assert_eq(first.stored_value, 1, "跨 setter 污染必须恢复到 attempt guard。")
	assert_eq(second.stored_value, 2)
	assert_true(GF_VARIANT_ACCESS.get_option_bool(report, "rolled_back"))
	assert_eq(
		GF_VARIANT_ACCESS.get_option_string_name(report, "status"),
		&"apply_failed"
	)


func test_rollback_failure_seals_command_and_allows_explicit_recovery() -> void:
	var first: ControlledTarget = ControlledTarget.new(1)
	var second: ControlledTarget = ControlledTarget.new(2)
	second.rejected_values.append(20)
	second.before_set = func(requested_value: int) -> void:
		if requested_value == 20 and not first.rejected_values.has(1):
			first.rejected_values.append(1)
	var command: GFEditorPropertyBatchCommand = GFEditorPropertyBatchCommand.new()
	var _configured: GFEditorPropertyBatchCommand = command.configure([
		{
			"target": first,
			"property_name": &"value",
			"new_value": 10,
		},
		{
			"target": second,
			"property_name": &"value",
			"new_value": 20,
		},
	])

	var execute_error: Error = command.execute()
	var failure_report: Dictionary = command.get_transaction_report()

	assert_ne(execute_error, OK)
	assert_eq(first.stored_value, 10, "恢复 setter 被拒绝时应保留可诊断的残余状态。")
	assert_eq(second.stored_value, 2)
	assert_true(command.is_sealed(), "发生过写入尝试后不得再修改事务配置。")
	assert_false(command.is_executed())
	assert_true(
		GF_VARIANT_ACCESS.get_option_bool(failure_report, "recovery_required"),
		"不完整回滚必须显式要求恢复。"
	)
	assert_false(GF_VARIANT_ACCESS.get_option_bool(failure_report, "rolled_back"))
	assert_eq(
		GF_VARIANT_ACCESS.get_option_string_name(failure_report, "status"),
		&"rollback_failed"
	)

	first.rejected_values.clear()
	assert_eq(
		command.revert(),
		OK,
		"首次 execute 未成功但留有残余状态时，应允许显式 revert 重试恢复。"
	)
	assert_eq(first.stored_value, 1)
	assert_eq(second.stored_value, 2)
	assert_false(
		GF_VARIANT_ACCESS.get_option_bool(
			command.get_transaction_report(),
			"recovery_required"
		)
	)


func test_undo_failure_rolls_forward_to_complete_executed_state() -> void:
	var first: ControlledTarget = ControlledTarget.new(1)
	var second: ControlledTarget = ControlledTarget.new(2)
	var command: GFEditorPropertyBatchCommand = GFEditorPropertyBatchCommand.new()
	var _configured: GFEditorPropertyBatchCommand = command.configure([
		{
			"target": first,
			"property_name": &"value",
			"new_value": 10,
		},
		{
			"target": second,
			"property_name": &"value",
			"new_value": 20,
		},
	])
	assert_eq(command.execute(), OK)
	first.rejected_values.append(1)

	var revert_error: Error = command.revert()
	var report: Dictionary = command.get_transaction_report()

	assert_ne(revert_error, OK, "任一 undo setter 拒绝必须让 undo 失败。")
	assert_eq(first.stored_value, 10, "失败 undo 应恢复到撤销前完整状态。")
	assert_eq(second.stored_value, 20, "已撤销条目必须向前补偿。")
	assert_true(command.is_executed(), "补偿成功后命令仍应处于 executed 状态。")
	assert_true(GF_VARIANT_ACCESS.get_option_bool(report, "rolled_back"))
	assert_false(GF_VARIANT_ACCESS.get_option_bool(report, "recovery_required"))
	assert_eq(
		GF_VARIANT_ACCESS.get_option_string_name(report, "status"),
		&"revert_failed"
	)

	first.rejected_values.clear()
	assert_eq(command.revert(), OK, "目标恢复可写后应能再次 undo。")
	assert_eq(first.stored_value, 1)
	assert_eq(second.stored_value, 2)


func test_incomplete_undo_compensation_recovers_executed_guard_before_retry() -> void:
	var first: ControlledTarget = ControlledTarget.new(1)
	var second: ControlledTarget = ControlledTarget.new(2)
	var command: GFEditorPropertyBatchCommand = GFEditorPropertyBatchCommand.new()
	var _configured: GFEditorPropertyBatchCommand = command.configure([
		{
			"target": first,
			"property_name": &"value",
			"new_value": 10,
		},
		{
			"target": second,
			"property_name": &"value",
			"new_value": 20,
		},
	])
	assert_eq(command.execute(), OK)
	first.rejected_values.append(1)
	second.before_set = func(requested_value: int) -> void:
		if requested_value == 20 and not second.rejected_values.has(20):
			second.rejected_values.append(20)

	assert_ne(command.revert(), OK, "undo 与前向补偿均不完整时必须要求恢复。")
	assert_true(command.is_executed())
	assert_eq(first.stored_value, 10)
	assert_eq(second.stored_value, 2)
	assert_true(
		GF_VARIANT_ACCESS.get_option_bool(
			command.get_transaction_report(),
			"recovery_required"
		)
	)

	second.rejected_values.clear()
	second.before_set = Callable()
	assert_eq(command.recover(), OK, "显式恢复应回到 undo 前的 executed guard。")
	assert_eq(first.stored_value, 10)
	assert_eq(second.stored_value, 20)
	assert_true(command.is_executed(), "恢复 executed guard 不等于完成 undo。")

	first.rejected_values.clear()
	assert_eq(command.revert(), OK, "恢复完整 executed 状态后应能重试 undo。")
	assert_eq(first.stored_value, 1)
	assert_eq(second.stored_value, 2)


func test_overlapping_selector_is_rejected_without_writes() -> void:
	var target: ValueTarget = ValueTarget.new()
	target.vector_value = Vector2(1.0, 2.0)
	var command: GFEditorPropertyBatchCommand = GFEditorPropertyBatchCommand.new()
	var _configured: GFEditorPropertyBatchCommand = command.configure([
		{
			"target": target,
			"property_name": &"vector_value",
			"new_value": Vector2(3.0, 4.0),
		},
		{
			"target": target,
			"property_path": ^"vector_value:x",
			"new_value": 8.0,
		},
	])

	var report: Dictionary = command.validate()

	assert_false(
		GF_VARIANT_ACCESS.get_option_bool(report, "ok"),
		"直接根属性与其 indexed 子路径不得出现在同一事务。"
	)
	assert_eq(
		GF_VARIANT_ACCESS.get_option_string_name(report, "status"),
		&"preflight_failed"
	)
	assert_eq(target.vector_value, Vector2(1.0, 2.0))
	assert_eq(command.execute(), ERR_UNAVAILABLE)


func test_equivalent_indexed_path_aliases_are_rejected_without_writes() -> void:
	var target: ValueTarget = ValueTarget.new()
	target.vector_value = Vector2(1.0, 2.0)
	var command: GFEditorPropertyBatchCommand = GFEditorPropertyBatchCommand.new()
	var _configured: GFEditorPropertyBatchCommand = command.configure([
		{
			"target": target,
			"property_path": ^"vector_value:x",
			"new_value": 3.0,
		},
		{
			"target": target,
			"property_path": ^":vector_value:x",
			"new_value": 4.0,
		},
	])

	var report: Dictionary = command.validate()

	assert_false(
		GF_VARIANT_ACCESS.get_option_bool(report, "ok"),
		"等价 indexed path 写法必须在零写入预检阶段识别为重叠。"
	)
	assert_eq(
		GF_VARIANT_ACCESS.get_option_string_name(report, "status"),
		&"preflight_failed"
	)
	assert_eq(target.vector_value, Vector2(1.0, 2.0))
	assert_eq(command.execute(), ERR_UNAVAILABLE)


func test_subname_root_alias_overlaps_descendant_without_writes() -> void:
	var target: ValueTarget = ValueTarget.new()
	target.vector_value = Vector2(1.0, 2.0)
	var command: GFEditorPropertyBatchCommand = GFEditorPropertyBatchCommand.new()
	var _configured: GFEditorPropertyBatchCommand = command.configure([
		{
			"target": target,
			"property_path": ^":vector_value",
			"new_value": Vector2(3.0, 4.0),
		},
		{
			"target": target,
			"property_path": ^"vector_value:x",
			"new_value": 8.0,
		},
	])

	var report: Dictionary = command.validate()

	assert_false(
		GF_VARIANT_ACCESS.get_option_bool(report, "ok"),
		"以 subname 起始的根 selector 必须与其后代路径判定为重叠。"
	)
	assert_eq(
		GF_VARIANT_ACCESS.get_option_string_name(report, "status"),
		&"preflight_failed"
	)
	assert_eq(target.vector_value, Vector2(1.0, 2.0))
	assert_eq(command.execute(), ERR_UNAVAILABLE)


func test_configuration_copies_values_and_is_sealed_after_first_write() -> void:
	var target: ValueTarget = ValueTarget.new()
	target.payload = {
		"items": [],
	}
	var requested_payload: Dictionary = {
		"items": [1],
	}
	var command: GFEditorPropertyBatchCommand = GFEditorPropertyBatchCommand.new()
	var _configured: GFEditorPropertyBatchCommand = command.configure([
		{
			"target": target,
			"property_name": &"payload",
			"new_value": requested_payload,
		},
	])
	var requested_items: Array = GF_VARIANT_ACCESS.get_option_array(
		requested_payload,
		"items"
	)
	requested_items.append(2)

	assert_eq(command.execute(), OK)
	var applied_items: Array = GF_VARIANT_ACCESS.get_option_array(
		target.payload,
		"items"
	)
	assert_eq(applied_items, [1], "调用方后续修改输入集合不得改变已配置命令。")

	var _reconfigured: GFEditorPropertyBatchCommand = command.configure([
		{
			"target": target,
			"property_name": &"payload",
			"new_value": { "items": [99] },
		},
	])
	assert_push_error("[GFEditorCommand] 命令配置已冻结，不能修改：configure。")

	assert_eq(command.revert(), OK)
	assert_eq(command.execute(), OK)
	applied_items = GF_VARIANT_ACCESS.get_option_array(target.payload, "items")
	assert_eq(applied_items, [1], "冻结后的 reconfigure 不得改变 redo 内容。")


func test_exact_direct_property_and_indexed_path_share_one_transaction() -> void:
	var target: SelectorTarget = SelectorTarget.new()
	target.exact_value = "old"
	target.vector_value = Vector2(1.0, 2.0)
	var command: GFEditorPropertyBatchCommand = GFEditorPropertyBatchCommand.new()
	var _configured: GFEditorPropertyBatchCommand = command.configure([
		{
			"target": target,
			"property_name": &"colon:like",
			"new_value": "new",
		},
		{
			"target": target,
			"property_path": ^"vector_value:x",
			"new_value": 8.0,
		},
	])

	assert_eq(command.execute(), OK)
	assert_eq(target.exact_value, "new", "property_name 必须按精确直接属性写入。")
	assert_eq(target.vector_value, Vector2(8.0, 2.0))
	assert_eq(command.revert(), OK)
	assert_eq(target.exact_value, "old")
	assert_eq(target.vector_value, Vector2(1.0, 2.0))


# --- 辅助类型 ---

class ValueTarget:
	extends RefCounted

	var value: int = 0
	var vector_value: Vector2 = Vector2.ZERO
	var payload: Dictionary = {}


class ControlledTarget:
	extends RefCounted

	var stored_value: int = 0
	var rejected_values: Array[int] = []
	var before_set: Callable = Callable()
	var set_attempts: int = 0


	func _init(initial_value: int = 0) -> void:
		stored_value = initial_value


	func _get_property_list() -> Array[Dictionary]:
		return [{
			"name": "value",
			"type": TYPE_INT,
			"usage": PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_STORAGE,
		}]


	func _get(property: StringName) -> Variant:
		if property == &"value":
			return stored_value
		return null


	func _set(property: StringName, raw_value: Variant) -> bool:
		if property != &"value":
			return false
		var requested_value: int = GF_VARIANT_ACCESS.to_int(raw_value)
		set_attempts += 1
		if before_set.is_valid():
			var _callback_result: Variant = before_set.call(requested_value)
		if rejected_values.has(requested_value):
			return false
		stored_value = requested_value
		return true


class SelectorTarget:
	extends RefCounted

	var exact_value: String = ""
	var vector_value: Vector2 = Vector2.ZERO


	func _get_property_list() -> Array[Dictionary]:
		return [{
			"name": "colon:like",
			"type": TYPE_STRING,
			"usage": PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_STORAGE,
		}]


	func _get(property: StringName) -> Variant:
		if property == &"colon:like":
			return exact_value
		return null


	func _set(property: StringName, raw_value: Variant) -> bool:
		if property != &"colon:like":
			return false
		exact_value = GF_VARIANT_ACCESS.to_text(raw_value)
		return true
