extends GutTest


# --- 常量 ---

const GF_OBJECT_CANDIDATE_REGISTRY_SCRIPT = preload("res://addons/gf/standard/common/gf_object_candidate_registry.gd")


# --- 辅助类 ---

class ReceiverCandidate extends Node:
	func receive_interaction(_context: Variant = null, _interaction_id: StringName = &"") -> Dictionary:
		return {
			"ok": true,
		}


# --- 测试方法 ---

func test_candidate_registry_sorts_by_priority_and_stable_order() -> void:
	var registry: RefCounted = GF_OBJECT_CANDIDATE_REGISTRY_SCRIPT.new()
	var first: Node = Node.new()
	var second: Node = Node.new()
	var third: Node = Node.new()
	add_child_autofree(first)
	add_child_autofree(second)
	add_child_autofree(third)

	assert_true(GFVariantData.to_bool(registry.call("register_candidate", first, { "priority": 1, "group": &"usable" })))
	assert_true(GFVariantData.to_bool(registry.call("register_candidate", second, { "priority": 5, "group": &"usable" })))
	assert_true(GFVariantData.to_bool(registry.call("register_candidate", third, { "priority": 5, "group": &"usable" })))

	var candidates: Array = GFVariantData.as_array(registry.call("get_candidates", { "group": &"usable" }))

	assert_same(_get_candidate_snapshot_object(candidates, 0), second, "高优先级候选应排在前面。")
	assert_same(_get_candidate_snapshot_object(candidates, 1), third, "同优先级应保持注册顺序。")
	assert_same(_get_candidate_snapshot_object(candidates, 2), first, "低优先级候选应排在后面。")


func test_candidate_registry_applies_limit_after_sorting() -> void:
	var registry: RefCounted = GF_OBJECT_CANDIDATE_REGISTRY_SCRIPT.new()
	var low_priority: Node = Node.new()
	var high_priority: Node = Node.new()
	add_child_autofree(low_priority)
	add_child_autofree(high_priority)

	assert_true(GFVariantData.to_bool(registry.call("register_candidate", low_priority, { "priority": 1 })))
	assert_true(GFVariantData.to_bool(registry.call("register_candidate", high_priority, { "priority": 9 })))

	var candidates: Array = GFVariantData.as_array(registry.call("get_candidates", { "max_count": 1 }))

	assert_eq(candidates.size(), 1, "max_count 应在排序后截断。")
	assert_same(_get_candidate_snapshot_object(candidates, 0), high_priority, "最高优先级候选不能被注册顺序截掉。")


func test_candidate_registry_filters_method_and_prunes_freed_objects() -> void:
	var registry: RefCounted = GF_OBJECT_CANDIDATE_REGISTRY_SCRIPT.new()
	var receiver: ReceiverCandidate = ReceiverCandidate.new()
	var plain: Node = Node.new()
	var freed: Node = Node.new()
	add_child_autofree(receiver)
	add_child_autofree(plain)

	assert_true(GFVariantData.to_bool(registry.call("register_candidate", receiver, { "priority": 2 })))
	assert_true(GFVariantData.to_bool(registry.call("register_candidate", plain, { "priority": 3 })))
	assert_true(GFVariantData.to_bool(registry.call("register_candidate", freed, { "priority": 4 })))
	freed.free()

	var receiver_objects: Array = GFVariantData.as_array(registry.call("get_candidate_objects", { "method_name": &"receive_interaction" }))
	var snapshot: Dictionary = GFVariantData.as_dictionary(registry.call("get_debug_snapshot"))

	assert_eq(receiver_objects.size(), 1, "method_name 过滤应只保留暴露目标方法的候选。")
	assert_same(_get_array_object(receiver_objects, 0), receiver, "过滤结果应返回有效 receiver。")
	assert_eq(GFVariantData.get_option_int(snapshot, "count"), 2, "查询时应清理已释放候选。")
	assert_eq(GFVariantData.get_option_int(snapshot, "valid_count"), 2, "调试快照应统计仍有效候选。")


func test_candidate_registry_can_unregister_owner() -> void:
	var registry: RefCounted = GF_OBJECT_CANDIDATE_REGISTRY_SCRIPT.new()
	var candidate_owner: Node = Node.new()
	var owned: Node = Node.new()
	var other: Node = Node.new()
	add_child_autofree(candidate_owner)
	add_child_autofree(owned)
	add_child_autofree(other)

	assert_true(GFVariantData.to_bool(registry.call("register_candidate", owned, { "owner": candidate_owner })))
	assert_true(GFVariantData.to_bool(registry.call("register_candidate", other, { "owner": &"other_owner" })))

	var removed_count: int = GFVariantData.to_int(registry.call("unregister_owner", candidate_owner))

	assert_eq(removed_count, 1, "按 owner 移除应只删除对应候选。")
	var remaining_objects: Array = GFVariantData.as_array(registry.call("get_candidate_objects"))
	assert_eq(remaining_objects.size(), 1, "其他 owner 的候选应保留。")
	assert_same(_get_array_object(remaining_objects, 0), other, "保留项应为其他 owner 候选。")


func test_candidate_registry_notifies_once_per_successful_mutation() -> void:
	var registry: RefCounted = GF_OBJECT_CANDIDATE_REGISTRY_SCRIPT.new()
	var candidate_owner: Node = Node.new()
	var first: Node = Node.new()
	var second: Node = Node.new()
	add_child_autofree(candidate_owner)
	add_child_autofree(first)
	add_child_autofree(second)
	watch_signals(registry)

	assert_eq(GFVariantData.to_int(registry.call("get_revision")), 0, "新注册表 revision 应从 0 开始。")
	assert_true(GFVariantData.to_bool(registry.call("register_candidate", first, { "owner": candidate_owner })))
	assert_true(GFVariantData.to_bool(registry.call("register_candidate", second, { "owner": candidate_owner })))
	assert_eq(GFVariantData.to_int(registry.call("unregister_owner", candidate_owner)), 2, "批量 owner 移除应删除全部关联候选。")

	assert_eq(GFVariantData.to_int(registry.call("get_revision")), 3, "两次注册和一次批量移除应推进三次 revision。")
	assert_signal_emit_count(registry, "candidates_changed", 3, "一次公开变更操作只应发出一次通知。")
	assert_signal_emitted_with_parameters(registry, "candidates_changed", [1], 0)
	assert_signal_emitted_with_parameters(registry, "candidates_changed", [2], 1)
	assert_signal_emitted_with_parameters(registry, "candidates_changed", [3], 2)

	assert_false(GFVariantData.to_bool(registry.call("unregister_candidate_id", first.get_instance_id())), "移除不存在的候选应为 no-op。")
	registry.call("clear")
	assert_eq(GFVariantData.to_int(registry.call("get_revision")), 3, "无效移除和空 clear 不应推进 revision。")
	assert_signal_emit_count(registry, "candidates_changed", 3, "no-op 不应发出候选变化通知。")


func test_candidate_registry_skips_idempotent_updates_and_notifies_real_updates() -> void:
	var registry: RefCounted = GF_OBJECT_CANDIDATE_REGISTRY_SCRIPT.new()
	var candidate: Node = Node.new()
	add_child_autofree(candidate)
	watch_signals(registry)
	var options: Dictionary = {
		"priority": 2,
		"group": &"usable",
		"stable_key": &"door",
		"metadata": { "label": "Door" },
	}

	assert_true(GFVariantData.to_bool(registry.call("register_candidate", candidate, options)))
	assert_true(GFVariantData.to_bool(registry.call("register_candidate", candidate, options)), "幂等注册仍应报告候选有效。")
	assert_eq(GFVariantData.to_int(registry.call("get_revision")), 1, "相同记录的幂等注册不应推进 revision。")
	assert_signal_emit_count(registry, "candidates_changed", 1, "相同记录的幂等注册不应发出变化通知。")

	options["priority"] = 3
	assert_true(GFVariantData.to_bool(registry.call("register_candidate", candidate, options)))
	assert_eq(GFVariantData.to_int(registry.call("get_revision")), 2, "候选字段更新应推进 revision。")
	assert_signal_emitted_with_parameters(registry, "candidates_changed", [2], 1)

	registry.call("clear")
	assert_eq(GFVariantData.to_int(registry.call("get_revision")), 3, "非空 clear 应推进 revision。")
	assert_signal_emitted_with_parameters(registry, "candidates_changed", [3], 2)


func test_candidate_registry_batches_prune_and_exposes_revision_in_snapshot() -> void:
	var registry: RefCounted = GF_OBJECT_CANDIDATE_REGISTRY_SCRIPT.new()
	var first: Node = Node.new()
	var second: Node = Node.new()
	watch_signals(registry)

	assert_true(GFVariantData.to_bool(registry.call("register_candidate", first)))
	assert_true(GFVariantData.to_bool(registry.call("register_candidate", second)))
	first.free()
	second.free()
	assert_eq(GFVariantData.to_int(registry.call("prune_invalid")), 2, "一次清理应移除全部失效候选。")

	var snapshot: Dictionary = GFVariantData.as_dictionary(registry.call("get_debug_snapshot"))
	assert_eq(GFVariantData.to_int(registry.call("get_revision")), 3, "批量清理应只推进一次 revision。")
	assert_eq(GFVariantData.get_option_int(snapshot, "revision"), 3, "调试快照应暴露当前 revision。")
	assert_signal_emit_count(registry, "candidates_changed", 3, "两次注册和一次批量清理应发出三次通知。")


# --- 私有/辅助方法 ---

func _get_candidate_snapshot_object(candidates: Array, index: int) -> Object:
	if index < 0 or index >= candidates.size():
		return null
	var snapshot_value: Variant = candidates[index]
	if snapshot_value is Dictionary:
		var snapshot: Dictionary = snapshot_value
		var object_value: Variant = GFVariantData.get_option_value(snapshot, "object")
		if object_value is Object:
			var object_candidate: Object = object_value
			return object_candidate
	return null


func _get_array_object(objects: Array, index: int) -> Object:
	if index < 0 or index >= objects.size():
		return null
	var object_value: Variant = objects[index]
	if object_value is Object:
		var object_candidate: Object = object_value
		return object_candidate
	return null
