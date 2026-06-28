## 测试小型异步流程辅助。
extends GutTest


func test_async_flow_retry_stops_after_successful_attempt() -> void:
	var state: Dictionary = { "calls": 0 }

	var result: Dictionary = await GFAsyncFlowTools.retry_async(func() -> Dictionary:
		state["calls"] = GFVariantData.get_option_int(state, "calls") + 1
		if GFVariantData.get_option_int(state, "calls") < 2:
			return { "ok": false, "error": "try again" }
		return { "ok": true, "value": "done" }
	, { "attempts": 3 })

	assert_true(GFVariantData.get_option_bool(result, "ok"), "第二次成功后 retry 应完成。")
	assert_eq(GFVariantData.get_option_int(result, "attempts"), 2, "retry 应报告实际尝试次数。")
	assert_eq(GFVariantData.get_option_string(result, "value"), "done", "retry 应返回成功值。")


func test_async_flow_each_collects_values_in_order() -> void:
	var result: Dictionary = await GFAsyncFlowTools.each_async([1, 2, 3], func(item: int) -> Dictionary:
		return { "ok": true, "value": item * 2 }
	)
	var values: Array = GFVariantData.get_option_array(result, "value")

	assert_true(GFVariantData.get_option_bool(result, "ok"), "each_async 全部成功时应成功。")
	assert_eq(values, [2, 4, 6], "each_async 应按输入顺序收集值。")


func test_async_flow_fold_uses_previous_accumulator() -> void:
	var result: Dictionary = await GFAsyncFlowTools.fold_async([1, 2, 3], func(total: int, item: int) -> Dictionary:
		return { "ok": true, "value": total + item }
	, 0)

	assert_true(GFVariantData.get_option_bool(result, "ok"), "fold_async 全部成功时应成功。")
	assert_eq(GFVariantData.get_option_int(result, "value"), 6, "fold_async 应把每次返回值作为下一次累加值。")
