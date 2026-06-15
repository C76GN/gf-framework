## 测试 GFDeque 的通用双端队列行为。
extends GutTest


# --- 常量 ---

const GFDequeBase = preload("res://addons/gf/standard/foundation/collections/gf_deque.gd")


# --- 测试方法 ---

## 验证双端追加、移除、回绕与扩容后仍保持队列顺序。
func test_deque_preserves_order_across_wrap_and_growth() -> void:
	var deque: GFDequeBase = GFDequeBase.new(3)

	deque.push_back(1)
	deque.push_back(2)
	deque.push_back(3)
	assert_eq(_variant_to_int(deque.pop_front()), 1, "队头弹出应返回最早元素。")
	assert_eq(_variant_to_int(deque.pop_front()), 2, "连续弹出应推进环形头部。")

	deque.push_back(4)
	deque.push_front(0)
	deque.push_back(5)

	assert_eq(deque.to_array(), [0, 3, 4, 5], "回绕并扩容后应保留队头到队尾顺序。")
	assert_eq(_variant_to_int(deque.pop_back()), 5, "队尾弹出应返回最后追加元素。")
	assert_eq(_variant_to_int(deque.pop_front()), 0, "队头插入元素应优先弹出。")
	assert_eq(deque.to_array(), [3, 4], "剩余队列顺序应稳定。")


## 验证索引读取、替换和两端裁剪。
func test_deque_indexes_and_trims_without_business_policy() -> void:
	var deque: GFDequeBase = GFDequeBase.from_array(["a", "b", "c", "d"], 2)

	assert_eq(GFVariantData.to_text(deque.at(0)), "a", "正向索引应读取队头。")
	assert_eq(GFVariantData.to_text(deque.at(-1)), "d", "负索引应从队尾读取。")
	assert_eq(GFVariantData.to_text(deque.at(99, "fallback")), "fallback", "越界索引应返回默认值。")
	assert_true(deque.set_at(-2, "C"), "负索引替换应成功。")
	assert_false(deque.set_at(99, "x"), "越界替换应失败。")

	assert_eq(deque.trim_front(2), 2, "从队头裁剪应返回移除数量。")
	assert_eq(deque.to_array(), ["C", "d"], "队头裁剪应保留较新的队尾元素。")
	assert_eq(deque.trim_back(1), 1, "从队尾裁剪应返回移除数量。")
	assert_eq(deque.to_array(), ["C"], "队尾裁剪应保留较早的队头元素。")


## 验证复制与清空不会泄漏内部顺序状态。
func test_deque_duplicates_and_reuses_storage() -> void:
	var deque: GFDequeBase = GFDequeBase.new(1)
	var payload: Dictionary = { "items": [1] }
	deque.push_back(payload)
	deque.push_back({ "items": [2] })
	var _removed_value: Variant = deque.pop_front()
	deque.push_front(payload)

	var shallow_copy: GFDequeBase = deque.duplicate_deque(false)
	var deep_copy: GFDequeBase = deque.duplicate_deque(true)
	var payload_items: Array = GFVariantData.as_array(payload["items"])
	payload_items.append(3)

	assert_eq(GFVariantData.as_array(GFVariantData.as_dictionary(shallow_copy.at(0))["items"]), [1, 3], "浅复制应保留引用语义。")
	assert_eq(GFVariantData.as_array(GFVariantData.as_dictionary(deep_copy.at(0))["items"]), [1], "深复制应复制嵌套值。")

	deque.clear()
	assert_true(deque.is_empty(), "清空后队列应为空。")
	deque.push_back("reused")
	assert_eq(deque.to_array(), ["reused"], "清空后应能继续复用底层存储。")


# --- 私有/辅助方法 ---

func _variant_to_int(value: Variant) -> int:
	return GFVariantData.to_int(value, 0)
