## 测试 GFBudgetLedger 的通用预算账本能力。
extends GutTest


# --- 常量 ---

const GFBudgetLedgerBase = preload("res://addons/gf/standard/foundation/budget/gf_budget_ledger.gd")


# --- 测试 ---

func test_budget_ledger_consumes_and_releases_budget() -> void:
	var ledger: GFBudgetLedgerBase = GFBudgetLedgerBase.new()
	ledger.set_capacity(&"energy", 10.0)

	var consumed: Dictionary = ledger.consume(&"energy", 3.0)

	assert_true(GFVariantData.get_option_bool(consumed, "ok", false), "预算充足时应允许消费。")
	assert_eq(ledger.get_available(&"energy"), 7.0, "消费后可用量应减少。")

	ledger.release(&"energy", 2.0)
	assert_eq(ledger.get_available(&"energy"), 9.0, "释放后可用量应增加。")


func test_budget_ledger_rejects_insufficient_budget() -> void:
	var ledger: GFBudgetLedgerBase = GFBudgetLedgerBase.new()
	ledger.set_capacity(&"turn_points", 2.0)

	var result: Dictionary = ledger.consume(&"turn_points", 3.0)

	assert_false(GFVariantData.get_option_bool(result, "ok", true), "预算不足时应拒绝消费。")
	assert_eq(GFVariantData.get_option_string(result, "reason", ""), "insufficient_budget", "失败原因应可诊断。")
	assert_eq(ledger.get_available(&"turn_points"), 2.0, "失败消费不应改变可用量。")


func test_budget_ledger_rejects_positive_consumption_lost_to_float_precision() -> void:
	var ledger: GFBudgetLedgerBase = GFBudgetLedgerBase.new()
	var rejected_reasons: Array[String] = []
	var _connect_result: Error = ledger.budget_rejected.connect(
		func(_budget_id: StringName, _amount: float, reason: String) -> void:
			rejected_reasons.append(reason)
	) as Error
	assert_eq(_connect_result, OK, "测试应能监听精度拒绝信号。")
	ledger.set_capacity(&"quota", 1.0e20)
	var before: float = ledger.get_available(&"quota")

	var result: Dictionary = ledger.consume(&"quota", 1.0)

	assert_false(ledger.can_consume(&"quota", 1.0), "不能表示余额变化的小正数不得被 can_consume 接受。")
	assert_false(GFVariantData.get_option_bool(result, "ok", true), "正消费不会降低余额时必须失败关闭。")
	assert_eq(GFVariantData.get_option_string(result, "reason"), "precision_loss", "精度拒绝应有稳定原因。")
	assert_eq(ledger.get_available(&"quota"), before, "精度拒绝不得改变余额。")
	assert_eq(rejected_reasons, ["precision_loss"], "精度拒绝应通过现有诊断信号可观察。")


func test_budget_ledger_rejects_empty_id_and_nonfinite_amounts() -> void:
	var ledger: GFBudgetLedgerBase = GFBudgetLedgerBase.new()
	var rejected_reasons: Array[String] = []
	var _connect_result: Error = ledger.budget_rejected.connect(func(_budget_id: StringName, _amount: float, reason: String) -> void:
		rejected_reasons.append(reason)
	) as Error
	assert_eq(_connect_result, OK, "测试应能监听预算拒绝信号。")

	ledger.set_capacity(&"energy", INF)
	var empty_id_result: Dictionary = ledger.consume(&"", 1.0)
	var invalid_amount_result: Dictionary = ledger.consume(&"energy", NAN)

	assert_eq(ledger.get_available(&"energy"), 0.0, "非有限 capacity 应归一为 0。")
	assert_false(ledger.can_consume(&"", 1.0), "空预算 ID 不应允许消费。")
	assert_false(GFVariantData.get_option_bool(empty_id_result, "ok", true), "空预算 ID 应拒绝消费。")
	assert_eq(GFVariantData.get_option_string(empty_id_result, "reason"), "empty_budget_id", "空预算 ID 应有稳定拒绝原因。")
	assert_false(GFVariantData.get_option_bool(invalid_amount_result, "ok", true), "非有限消费量应拒绝。")
	assert_eq(GFVariantData.get_option_string(invalid_amount_result, "reason"), "invalid_amount", "非有限消费量应有稳定拒绝原因。")
	assert_eq(rejected_reasons, ["empty_budget_id", "invalid_amount"], "拒绝信号应覆盖空 ID 和非法数值。")


func test_budget_ledger_snapshot_is_decoupled() -> void:
	var ledger: GFBudgetLedgerBase = GFBudgetLedgerBase.new()
	ledger.set_capacity(&"quota", 4.0)

	var snapshot: Dictionary = ledger.get_snapshot()
	var quota: Dictionary = GFVariantData.get_option_dictionary(snapshot, "quota", {})
	quota["available"] = 0.0

	assert_eq(ledger.get_available(&"quota"), 4.0, "修改快照不应污染账本。")


func test_budget_ledger_release_missing_budget_does_not_create_entry() -> void:
	var ledger: GFBudgetLedgerBase = GFBudgetLedgerBase.new()
	var changed_budget_ids: Array[StringName] = []
	var _connect_result: Error = ledger.budget_changed.connect(func(budget_id: StringName, _available: float, _capacity: float) -> void:
		changed_budget_ids.append(budget_id)
	) as Error
	assert_eq(_connect_result, OK, "测试应能监听预算变化信号。")

	ledger.release(&"missing", 2.0)

	assert_eq(ledger.get_snapshot(), {}, "释放未知预算不应创建 0/0 条目。")
	assert_eq(changed_budget_ids, [], "释放未知预算不应发出变化信号。")


func test_budget_ledger_clear_emits_cleared_budget_ids() -> void:
	var ledger: GFBudgetLedgerBase = GFBudgetLedgerBase.new()
	var capture: BudgetSignalCapture = BudgetSignalCapture.new()
	var _connect_result: Error = ledger.budgets_cleared.connect(func(budget_ids: PackedStringArray) -> void:
		capture.cleared_budget_ids = budget_ids
	) as Error
	assert_eq(_connect_result, OK, "测试应能监听清空信号。")
	ledger.set_capacity(&"mana", 3.0)
	ledger.set_capacity(&"energy", 2.0)

	ledger.clear()

	assert_eq(ledger.get_snapshot(), {}, "clear 应清空所有预算。")
	assert_eq(capture.cleared_budget_ids, PackedStringArray(["energy", "mana"]), "clear 应报告被清空的预算 ID。")


func test_budget_consumed_reentrancy_never_emits_stale_budget_changed_state() -> void:
	var ledger: GFBudgetLedgerBase = GFBudgetLedgerBase.new()
	ledger.set_capacity(&"energy", 10.0)
	var observed_available: Array[float] = []
	var on_budget_consumed: Callable = func(budget_id: StringName, _amount: float) -> void:
		ledger.release(budget_id, 1.0)
	var on_budget_changed: Callable = func(_budget_id: StringName, available: float, _capacity: float) -> void:
		observed_available.append(available)
	var _consumed_connected: Error = ledger.budget_consumed.connect(on_budget_consumed) as Error
	var _changed_connected: Error = ledger.budget_changed.connect(on_budget_changed) as Error

	var result: Dictionary = ledger.consume(&"energy", 3.0)

	assert_true(GFVariantData.get_option_bool(result, "ok"), "测试消费应成功。")
	assert_eq(ledger.get_available(&"energy"), 8.0, "重入 release 后账本真值应为 8。")
	assert_eq(observed_available, [8.0, 8.0], "consume 的后续变化信号只能描述发射时的当前状态。")
	ledger.budget_consumed.disconnect(on_budget_consumed)
	ledger.budget_changed.disconnect(on_budget_changed)


# --- 内部类 ---

class BudgetSignalCapture:
	extends RefCounted

	var cleared_budget_ids: PackedStringArray = PackedStringArray()
