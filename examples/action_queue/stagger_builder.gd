# 有序交错动画示例；只组合既有动作，不注册新的框架播放器或自动扫描目标。
extends RefCounted


const _MAX_TARGETS: int = 64
const _MAX_WAIT_SECONDS: float = 120.0


static func build(targets: Array[Node], interval_seconds: float, factory: Callable, host: Node) -> Dictionary:
	if not is_finite(interval_seconds) or interval_seconds < 0.0:
		return _result(false, null, &"invalid_interval")
	if targets.size() > _MAX_TARGETS or float(maxi(0, targets.size() - 1)) * interval_seconds > _MAX_WAIT_SECONDS:
		return _result(false, null, &"wait_budget")
	if targets.is_empty():
		return _result(true, null, &"")
	if not factory.is_valid() or not _available(host):
		return _result(false, null, &"unavailable_factory_or_host")
	var ordered_targets: Array[Node] = targets.duplicate()
	var target_ids: Dictionary = {}
	for target: Node in ordered_targets:
		if not _available(target):
			return _result(false, null, &"unavailable_target")
		if target_ids.has(target.get_instance_id()):
			return _result(false, null, &"duplicate_target")
		target_ids[target.get_instance_id()] = true
	var action_ids: Dictionary = {}
	var branches: Array = []
	for index: int in range(ordered_targets.size()):
		if not _all_available(ordered_targets, host):
			return _result(false, null, &"target_or_host_changed")
		var produced: Variant = factory.call(ordered_targets[index])
		if not _all_available(ordered_targets, host):
			return _result(false, null, &"target_or_host_changed")
		if not produced is GFVisualAction:
			return _result(false, null, &"invalid_factory_result")
		var action: GFVisualAction = produced
		if action_ids.has(action.get_instance_id()):
			return _result(false, null, &"reused_action")
		action_ids[action.get_instance_id()] = true
		branches.append(GFAction.sequence([
			GFAction.wait(float(index) * interval_seconds, host),
			action,
		]))
	return _result(true, GFAction.parallel(branches), &"")


static func _available(target: Variant) -> bool:
	if not is_instance_valid(target) or not target is Node:
		return false
	var node: Node = target
	return node.is_inside_tree() and not node.is_queued_for_deletion()


static func _all_available(targets: Array[Node], host: Variant) -> bool:
	if not _available(host):
		return false
	for target: Node in targets:
		if not _available(target):
			return false
	return true


static func _result(ok: bool, action: GFVisualActionGroup, error: StringName) -> Dictionary:
	return {"ok": ok, "action": action, "error": error}
