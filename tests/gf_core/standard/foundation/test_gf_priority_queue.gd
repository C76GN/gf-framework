## 测试 GFPriorityQueue 的通用稳定优先队列行为。
extends GutTest


# --- 常量 ---

const GF_PRIORITY_QUEUE_SCRIPT = preload("res://addons/gf/standard/foundation/collections/gf_priority_queue.gd")


# --- 测试方法 ---

func test_priority_queue_pops_high_priority_first_with_stable_ties() -> void:
	var priority_queue: GF_PRIORITY_QUEUE_SCRIPT = GF_PRIORITY_QUEUE_SCRIPT.new()

	priority_queue.push("first", 0)
	priority_queue.push("low", -1)
	priority_queue.push("last", 0)
	priority_queue.push("high", 10)
	priority_queue.push("front", 0, true)

	assert_eq(priority_queue.to_array(), ["high", "front", "first", "last", "low"], "队列应按 priority 和稳定同级顺序导出。")
	assert_eq(GFVariantData.to_text(priority_queue.pop()), "high", "pop 应先返回最高 priority 元素。")
	assert_eq(GFVariantData.to_text(priority_queue.pop()), "front", "front 元素应排在同 priority 既有元素之前。")
	assert_eq(GFVariantData.to_text(priority_queue.pop()), "first", "同 priority 普通元素应保持入队顺序。")
	assert_eq(priority_queue.size(), 2, "pop 后队列大小应减少。")


func test_priority_queue_can_pop_low_priority_first() -> void:
	var priority_queue: GF_PRIORITY_QUEUE_SCRIPT = GF_PRIORITY_QUEUE_SCRIPT.new(false)

	priority_queue.push("high", 10)
	priority_queue.push("low", -5)
	priority_queue.push("normal", 0)

	assert_eq(priority_queue.to_array(), ["low", "normal", "high"], "低优先模式应先弹出较小 priority。")
	assert_eq(priority_queue.peek_priority(), -5, "peek_priority 应返回当前顶部优先级。")


func test_priority_queue_removes_and_updates_values() -> void:
	var priority_queue: GF_PRIORITY_QUEUE_SCRIPT = GF_PRIORITY_QUEUE_SCRIPT.new()

	priority_queue.push("a", 1)
	priority_queue.push("b", 2)
	priority_queue.push("c", 3)

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
	priority_queue.push(payload, 1)

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

	priority_queue.push("old", 0)
	assert_eq(GFVariantData.to_text(priority_queue.pop()), "old", "测试队列应先被清空一次。")
	priority_queue.push("new", 0)
	priority_queue.push("front", 0, true)
	var entries: Array[Dictionary] = priority_queue.to_entry_array()
	var front_entry: Dictionary = entries[0]
	var new_entry: Dictionary = entries[1]

	assert_eq(GFVariantData.get_option_int(front_entry, "order"), -1, "清空后 front order 应从 -1 重新开始。")
	assert_eq(GFVariantData.get_option_int(new_entry, "order"), 0, "清空后普通 order 应从 0 重新开始。")
	assert_eq(priority_queue.to_array(), ["front", "new"], "清空后的稳定顺序应保持可预测。")
