## 测试通用策略 Provider 与 Registry。
extends GutTest


func test_policy_registry_evaluates_matching_providers_in_priority_order() -> void:
	var first: RecordingPolicyProvider = RecordingPolicyProvider.new()
	var _first_configured: GFPolicyProvider = first.configure(&"first", PackedStringArray(["import_plan"]))
	first.priority = 20
	var second: RecordingPolicyProvider = RecordingPolicyProvider.new()
	var _second_configured: GFPolicyProvider = second.configure(&"second", PackedStringArray(["import_plan"]))
	second.priority = 10
	var skipped: RecordingPolicyProvider = RecordingPolicyProvider.new()
	var _skipped_configured: GFPolicyProvider = skipped.configure(&"skipped", PackedStringArray(["other"]))

	var registry: GFPolicyRegistry = GFPolicyRegistry.new()
	assert_true(registry.register_provider(first), "有效 provider 应可注册。")
	assert_true(registry.register_provider(second), "第二个 provider 应可注册。")
	assert_true(registry.register_provider(skipped), "不匹配 kind 的 provider 也应可注册。")

	var result: Dictionary = registry.evaluate_artifact({
		"kind": "import_plan",
		"id": "items",
	})
	var results: Array = GFVariantData.get_option_array(result, "results")
	var first_result: Dictionary = GFVariantData.as_dictionary(results[0])
	var second_result: Dictionary = GFVariantData.as_dictionary(results[1])

	assert_true(GFVariantData.get_option_bool(result, "ok"), "全部匹配策略通过时汇总结果应通过。")
	assert_eq(GFVariantData.get_option_int(result, "provider_count"), 2, "只应执行支持该 artifact kind 的 provider。")
	assert_eq(GFVariantData.get_option_string_name(first_result, "provider_id"), &"second", "低 priority provider 应先执行。")
	assert_eq(GFVariantData.get_option_string_name(second_result, "provider_id"), &"first", "高 priority provider 应后执行。")
	assert_eq(first.evaluate_count, 1, "匹配 provider 应执行。")
	assert_eq(skipped.evaluate_count, 0, "不匹配 provider 不应执行。")


func test_policy_registry_aggregates_failed_policy_issues() -> void:
	var provider: RecordingPolicyProvider = RecordingPolicyProvider.new()
	var _configured_provider: GFPolicyProvider = provider.configure(&"deny", PackedStringArray(["asset"]))
	provider.should_fail = true
	var registry: GFPolicyRegistry = GFPolicyRegistry.new()
	var _registered: bool = registry.register_provider(provider)

	var result: Dictionary = registry.evaluate_artifact({ "artifact_kind": "asset" })
	var issues: Array = GFVariantData.get_option_array(result, "issues")
	var issue: Dictionary = GFVariantData.as_dictionary(issues[0])

	assert_false(GFVariantData.get_option_bool(result, "ok"), "任一策略失败时汇总结果应失败。")
	assert_eq(GFVariantData.get_option_string(issue, "kind"), "denied", "失败策略 issue 应进入汇总。")


class RecordingPolicyProvider extends GFPolicyProvider:
	var evaluate_count: int = 0
	var should_fail: bool = false


	func _evaluate_policy(_artifact: Dictionary, _context: Dictionary) -> Dictionary:
		evaluate_count += 1
		if should_fail:
			return make_result(false, &"failed", _artifact, [
				{
					"kind": "denied",
					"message": "denied by test policy",
				},
			])
		return make_result(true, &"passed", _artifact)
