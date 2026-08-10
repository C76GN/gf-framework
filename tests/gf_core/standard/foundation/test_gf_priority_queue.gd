## 测试 GFPriorityQueue 的通用稳定优先队列行为。
extends GutTest


# --- 常量 ---

const GF_PRIORITY_QUEUE_SCRIPT = preload("res://addons/gf/standard/foundation/collections/gf_priority_queue.gd")
const GF_PRIORITY_WORK_QUEUE_SCRIPT = preload("res://addons/gf/standard/foundation/collections/gf_priority_work_queue.gd")


# --- 测试方法 ---

func test_priority_queue_pops_high_priority_first_with_stable_ties() -> void:
	var priority_queue: GF_PRIORITY_QUEUE_SCRIPT = GF_PRIORITY_QUEUE_SCRIPT.new()

	assert_true(priority_queue.push("first", 0))
	assert_true(priority_queue.push("low", -1))
	assert_true(priority_queue.push("last", 0))
	assert_true(priority_queue.push("high", 10))
	assert_true(priority_queue.push("front", 0, true))

	assert_eq(priority_queue.to_array(), ["high", "front", "first", "last", "low"], "队列应按 priority 和稳定同级顺序导出。")
	assert_eq(GFVariantData.to_text(priority_queue.pop()), "high", "pop 应先返回最高 priority 元素。")
	assert_eq(GFVariantData.to_text(priority_queue.pop()), "front", "front 元素应排在同 priority 既有元素之前。")
	assert_eq(GFVariantData.to_text(priority_queue.pop()), "first", "同 priority 普通元素应保持入队顺序。")
	assert_eq(priority_queue.size(), 2, "pop 后队列大小应减少。")


func test_priority_queue_can_pop_low_priority_first() -> void:
	var priority_queue: GF_PRIORITY_QUEUE_SCRIPT = GF_PRIORITY_QUEUE_SCRIPT.new(false)

	assert_true(priority_queue.push("high", 10.5))
	assert_true(priority_queue.push("low", -5.25))
	assert_true(priority_queue.push("normal", 0.0))

	assert_eq(priority_queue.to_array(), ["low", "normal", "high"], "低优先模式应先弹出较小 priority。")
	assert_almost_eq(priority_queue.peek_priority(), -5.25, 0.001, "peek_priority 应返回当前顶部优先级。")


func test_priority_queue_can_use_explicit_stable_order() -> void:
	var priority_queue: GF_PRIORITY_QUEUE_SCRIPT = GF_PRIORITY_QUEUE_SCRIPT.new(false)

	assert_true(priority_queue.push_with_order("second", 1.5, 20))
	assert_true(priority_queue.push_with_order("first", 1.5, 10))
	assert_true(priority_queue.push_with_order("lowest", 0.5, 30))

	assert_eq(priority_queue.to_array(), ["lowest", "first", "second"], "显式 order 应在相同 priority 下稳定排序。")


func test_priority_queue_keeps_insertion_order_for_duplicate_explicit_keys() -> void:
	var priority_queue: GF_PRIORITY_QUEUE_SCRIPT = GF_PRIORITY_QUEUE_SCRIPT.new()

	assert_true(priority_queue.push_with_order("A", 1.0, 7))
	assert_true(priority_queue.push_with_order("B", 1.0, 7))
	assert_true(priority_queue.push_with_order("C", 1.0, 7))

	assert_eq(priority_queue.to_array(), ["A", "B", "C"], "相同 priority/order 必须用内部入队序形成稳定全序。")


func test_priority_queue_removes_and_updates_values() -> void:
	var priority_queue: GF_PRIORITY_QUEUE_SCRIPT = GF_PRIORITY_QUEUE_SCRIPT.new()

	assert_true(priority_queue.push("a", 1))
	assert_true(priority_queue.push("b", 2))
	assert_true(priority_queue.push("c", 3))

	assert_true(priority_queue.remove_value("b"), "remove_value 应移除匹配值。")
	assert_false(priority_queue.has_value("b"), "移除后不应继续包含该值。")
	assert_true(priority_queue.set_priority("a", 9), "set_priority 应更新匹配值。")
	assert_eq(priority_queue.to_array(), ["a", "c"], "更新后应按新 priority 排序。")
	assert_false(priority_queue.set_priority("missing", 9), "不存在值不应更新成功。")


func test_priority_queue_duplicates_entries_without_sharing_nested_values_when_deep() -> void:
	var priority_queue: GF_PRIORITY_QUEUE_SCRIPT = GF_PRIORITY_QUEUE_SCRIPT.new()
	var payload: Dictionary = {
		"items": [1],
	}
	assert_true(priority_queue.push(payload, 1))

	var shallow_copy: GF_PRIORITY_QUEUE_SCRIPT = priority_queue.duplicate_priority_queue(false)
	var deep_copy: GF_PRIORITY_QUEUE_SCRIPT = priority_queue.duplicate_priority_queue(true)
	var payload_items: Array = GFVariantData.as_array(payload["items"])
	payload_items.append(2)

	assert_eq(GFVariantData.as_array(GFVariantData.as_dictionary(shallow_copy.peek())["items"]), [1, 2], "浅复制应保留引用语义。")
	assert_eq(GFVariantData.as_array(GFVariantData.as_dictionary(deep_copy.peek())["items"]), [1], "深复制应复制嵌套值。")

	priority_queue.clear()
	assert_true(priority_queue.is_empty(), "clear 后队列应为空。")


func test_priority_queue_resets_order_after_becoming_empty() -> void:
	var priority_queue: GF_PRIORITY_QUEUE_SCRIPT = GF_PRIORITY_QUEUE_SCRIPT.new()

	assert_true(priority_queue.push("old", 0))
	assert_eq(GFVariantData.to_text(priority_queue.pop()), "old", "测试队列应先被清空一次。")
	assert_true(priority_queue.push("new", 0))
	assert_true(priority_queue.push("front", 0, true))
	var entries: Array[Dictionary] = priority_queue.to_entry_array()
	var front_entry: Dictionary = entries[0]
	var new_entry: Dictionary = entries[1]

	assert_eq(GFVariantData.get_option_int(front_entry, "order"), -1, "清空后 front order 应从 -1 重新开始。")
	assert_eq(GFVariantData.get_option_int(new_entry, "order"), 0, "清空后普通 order 应从 0 重新开始。")
	assert_eq(priority_queue.to_array(), ["front", "new"], "清空后的稳定顺序应保持可预测。")


func test_priority_queue_rejects_non_finite_priorities_and_uses_strict_order() -> void:
	var priority_queue: GF_PRIORITY_QUEUE_SCRIPT = GF_PRIORITY_QUEUE_SCRIPT.new()

	assert_false(priority_queue.push("nan", NAN), "NaN priority 应被拒绝。")
	assert_false(priority_queue.push_with_order("inf", INF, 0), "Infinity priority 应被拒绝。")
	assert_true(priority_queue.push("lower", 1.0), "有限 priority 应入队。")
	assert_true(priority_queue.push("higher", 1.0000001), "相近但不同的有限 priority 应入队。")
	assert_false(priority_queue.set_priority("lower", -INF), "set_priority 不应写入非有限值。")

	assert_eq(priority_queue.to_array(), ["higher", "lower"], "priority 排序应使用严格数值全序，而不是近似相等。")


func test_priority_work_queue_aging_prevents_old_low_priority_work_from_starving() -> void:
	var work_queue: GF_PRIORITY_WORK_QUEUE_SCRIPT = GF_PRIORITY_WORK_QUEUE_SCRIPT.new()
	work_queue.aging_interval_msec = 1000
	work_queue.aging_step = 10.0

	assert_true(work_queue.push_at("old-low", 0.0, 0), "旧低优先工作应能入队。")
	assert_true(work_queue.push_at("new-high", 15.0, 2000), "新高优先工作应能入队。")

	assert_eq(GFVariantData.to_text(work_queue.pop_at(2000)), "old-low", "等待加成应让长期等待工作最终先执行。")
	assert_eq(GFVariantData.to_text(work_queue.pop_at(2000)), "new-high", "剩余高优先工作随后执行。")


func test_priority_work_queue_keeps_stable_ties_and_reports_effective_priority() -> void:
	var work_queue: GF_PRIORITY_WORK_QUEUE_SCRIPT = GF_PRIORITY_WORK_QUEUE_SCRIPT.new()
	work_queue.aging_interval_msec = 1000
	work_queue.aging_step = 2.0

	assert_true(work_queue.push_at("first", 1.0, 1000))
	assert_true(work_queue.push_at("second", 3.0, 2000))
	var entries: Array[Dictionary] = work_queue.to_entry_array(3000)

	assert_eq(GFVariantData.get_option_string(entries[0], "value"), "first", "相同有效优先级应保持稳定入队顺序。")
	assert_almost_eq(GFVariantData.get_option_float(entries[0], "effective_priority"), 5.0, 0.001, "快照应报告等待加成后的优先级。")
	assert_eq(GFVariantData.get_option_int(entries[0], "waited_msec"), 2000, "快照应报告非负等待时间。")
	assert_true(work_queue.remove_value("second"), "工作队列应支持取消等待值。")
	assert_eq(work_queue.size(), 1, "移除后数量应更新。")


func test_priority_work_queue_compares_overflowing_aging_without_emitting_infinity() -> void:
	var work_queue: GF_PRIORITY_WORK_QUEUE_SCRIPT = GF_PRIORITY_WORK_QUEUE_SCRIPT.new()
	work_queue.aging_interval_msec = 1
	work_queue.aging_step = 1.0e308
	assert_true(work_queue.push_at("newer", 1.5e308, 1), "极大但有限的较新工作应被接受。")
	assert_true(work_queue.push_at("older", 1.0e308, 0), "极大但有限的较旧工作应被接受。")

	var entries: Array[Dictionary] = work_queue.to_entry_array(2)
	var snapshot_text: String = JSON.stringify(work_queue.get_debug_snapshot(2))

	assert_eq(GFVariantData.get_option_string(entries[0], "value"), "older", "共同尺度比较应保留数学上更高的 aging 顺序，而不是退化为入队 tie。")
	for entry: Dictionary in entries:
		assert_true(is_finite(GFVariantData.get_option_float(entry, "effective_priority")), "导出的 effective priority 必须保持有限。")
	assert_false(snapshot_text.contains("1e99999"), "调试快照不得用 JSON 的无穷替代值泄漏派生 Infinity。")
