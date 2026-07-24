## 测试 GFWeakMethodInvocation 的弱所有权、调用状态与调用时参数预检。
extends GutTest


# --- 测试 ---

func test_invoke_returns_method_value_and_stable_identity() -> void:
	var target: InvocationTarget = InvocationTarget.new()
	var target_id: int = target.get_instance_id()
	var invocation: GFWeakMethodInvocation = GFWeakMethodInvocation.new(target, &"add_values")

	var result: Dictionary = invocation.invoke([3, 4])

	assert_eq(_get_report_status(result), GFWeakMethodInvocation.STATUS_INVOKED, "有效目标方法应报告 invoked。")
	assert_true(_get_report_bool(result, "invoked"), "invoked 报告应设置调用标记。")
	assert_eq(GFVariantData.get_option_int(result, "value"), 7, "调用结果应保留方法返回值。")
	assert_eq(GFVariantData.get_option_int(result, "error_code"), OK, "成功调用应报告 OK。")
	assert_eq(GFVariantData.get_option_int(result, "initial_owner_instance_id"), target_id, "报告应保留创建时目标实例 ID。")
	assert_eq(GFVariantData.get_option_string_name(result, "method_name"), &"add_values", "报告应保留方法名。")
	assert_eq(target.call_count, 1, "目标方法应只调用一次。")


func test_false_business_result_is_still_invoked() -> void:
	var target: InvocationTarget = InvocationTarget.new()
	var invocation: GFWeakMethodInvocation = GFWeakMethodInvocation.new(target, &"return_false")

	var result: Dictionary = invocation.invoke()

	assert_eq(_get_report_status(result), GFWeakMethodInvocation.STATUS_INVOKED, "false 业务结果仍应报告 invoked。")
	assert_false(_get_report_bool(result, "value", true), "调用结果应原样保留 false。")
	assert_eq(target.call_count, 1, "原语不得把业务 false 当作预检失败。")


func test_ref_counted_owner_can_release_without_callable_retention() -> void:
	var target: InvocationTarget = InvocationTarget.new()
	var invocation: GFWeakMethodInvocation = GFWeakMethodInvocation.new(target, &"add_values")
	target = null

	var result: Dictionary = invocation.invoke([1, 2])

	assert_eq(
		_get_report_status(result),
		GFWeakMethodInvocation.STATUS_OWNER_RELEASED,
		"调用记录不应阻止 RefCounted owner 释放。"
	)
	assert_false(_get_report_bool(result, "invoked", true), "已释放 owner 不应被调用。")


func test_node_owner_release_is_reported_without_dereference() -> void:
	var target: NodeInvocationTarget = NodeInvocationTarget.new()
	var invocation: GFWeakMethodInvocation = GFWeakMethodInvocation.new(target, &"get_marker")
	target.free()

	var result: Dictionary = invocation.invoke()

	assert_eq(
		_get_report_status(result),
		GFWeakMethodInvocation.STATUS_OWNER_RELEASED,
		"已 free 的 Node owner 应报告 owner_released。"
	)
	assert_true(result.get("value") == null, "释放后调用不应产生返回值。")


func test_missing_method_is_distinct_from_released_owner() -> void:
	var target: InvocationTarget = InvocationTarget.new()
	var invocation: GFWeakMethodInvocation = GFWeakMethodInvocation.new(target, &"missing_method")

	var result: Dictionary = invocation.invoke()

	assert_eq(
		_get_report_status(result),
		GFWeakMethodInvocation.STATUS_METHOD_MISSING,
		"存活 owner 缺少方法时应报告 method_missing。"
	)
	assert_false(_get_report_bool(result, "invoked", true), "缺失方法不应被标记为已调用。")


func test_invalid_construction_reports_failed() -> void:
	var missing_owner: GFWeakMethodInvocation = GFWeakMethodInvocation.new(null, &"add_values")
	var target: InvocationTarget = InvocationTarget.new()
	var missing_method: GFWeakMethodInvocation = GFWeakMethodInvocation.new(target, &"")

	var owner_result: Dictionary = missing_owner.invoke([1, 2])
	var method_result: Dictionary = missing_method.invoke([1, 2])

	assert_eq(_get_report_status(owner_result), GFWeakMethodInvocation.STATUS_FAILED, "空 owner 应在构造预检后报告 failed。")
	assert_eq(_get_report_status(method_result), GFWeakMethodInvocation.STATUS_FAILED, "空方法名应在构造预检后报告 failed。")
	assert_eq(GFVariantData.get_option_int(owner_result, "error_code"), ERR_INVALID_PARAMETER, "无效构造应报告参数错误。")
	assert_eq(target.call_count, 0, "无效方法记录不得调用 owner。")


func test_invalid_argument_count_reports_failed_without_calling_owner() -> void:
	var target: InvocationTarget = InvocationTarget.new()
	var invocation: GFWeakMethodInvocation = GFWeakMethodInvocation.new(target, &"add_values")

	var too_few_result: Dictionary = invocation.invoke([1])
	var too_many_result: Dictionary = invocation.invoke([1, 2, 3])

	assert_eq(_get_report_status(too_few_result), GFWeakMethodInvocation.STATUS_FAILED, "缺少必需参数应报告 failed。")
	assert_eq(_get_report_status(too_many_result), GFWeakMethodInvocation.STATUS_FAILED, "多余参数应报告 failed。")
	assert_eq(GFVariantData.get_option_int(too_few_result, "error_code"), ERR_INVALID_PARAMETER, "参数数量预检失败应报告参数错误。")
	assert_eq(target.call_count, 0, "参数预检失败不得调用 owner。")


func test_argument_preflight_supports_defaults_and_native_varargs() -> void:
	var target: InvocationTarget = InvocationTarget.new()
	var default_invocation: GFWeakMethodInvocation = GFWeakMethodInvocation.new(
		target,
		&"add_with_default"
	)
	var native_invocation: GFWeakMethodInvocation = GFWeakMethodInvocation.new(target, &"call")

	var default_result: Dictionary = default_invocation.invoke([5])
	var native_result: Dictionary = native_invocation.invoke([&"return_false"])

	assert_eq(_get_report_status(default_result), GFWeakMethodInvocation.STATUS_INVOKED, "默认参数应通过数量预检。")
	assert_eq(GFVariantData.get_option_int(default_result, "value"), 7, "调用应使用目标方法的默认参数。")
	assert_eq(_get_report_status(native_result), GFWeakMethodInvocation.STATUS_INVOKED, "原生可变参数方法应通过预检。")
	assert_false(_get_report_bool(native_result, "value", true), "原生 call() 的业务返回值应原样保留。")
	assert_eq(target.call_count, 2, "两个通过预检的方法应各执行一次。")


func test_argument_preflight_accepts_script_override_with_wider_range() -> void:
	var target: ExtendedNativeVirtualTarget = ExtendedNativeVirtualTarget.new()
	var invocation: GFWeakMethodInvocation = GFWeakMethodInvocation.new(target, &"_to_string")

	var result: Dictionary = invocation.invoke(["!"])

	assert_eq(_get_report_status(result), GFWeakMethodInvocation.STATUS_INVOKED, "脚本覆写扩展的可选参数应通过预检。")
	assert_eq(GFVariantData.get_option_string(result, "value"), "target!", "调用应落到脚本覆写，而非同名原生签名。")
	assert_eq(target.call_count, 1, "脚本覆写应只调用一次。")


# --- 私有/辅助方法 ---

func _get_report_bool(report: Dictionary, key: String, fallback: bool = false) -> bool:
	return GFVariantData.get_option_bool(report, key, fallback)


func _get_report_status(report: Dictionary) -> StringName:
	return GFVariantData.get_option_string_name(
		report,
		"status",
		GFWeakMethodInvocation.STATUS_FAILED
	)


# --- 内部类 ---

class InvocationTarget extends RefCounted:
	var call_count: int = 0

	func add_values(left: int, right: int) -> int:
		call_count += 1
		return left + right

	func return_false() -> bool:
		call_count += 1
		return false

	func add_with_default(left: int, right: int = 2) -> int:
		call_count += 1
		return left + right


class NodeInvocationTarget extends Node:
	func get_marker() -> StringName:
		return &"alive"


class ExtendedNativeVirtualTarget extends RefCounted:
	var call_count: int = 0

	func _to_string(suffix: String = "") -> String:
		call_count += 1
		return "target%s" % suffix
