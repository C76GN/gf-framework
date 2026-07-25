# One-shot test cleanup scope with LIFO callbacks and lifecycle leak diagnostics.
extends RefCounted


# --- 常量 ---

const DEFAULT_SETTLE_FRAME_COUNT: int = 3


# --- 私有变量 ---

var _scene_tree: SceneTree
var _cleanup_callbacks: Array[Callable] = []
var _release_expectations: Array[Dictionary] = []
var _orphan_baseline: Dictionary = {}
var _cleanup_started: bool = false
var _cleanup_report: Dictionary = {}


# --- Godot 生命周期方法 ---

func _init(scene_tree: SceneTree) -> void:
	_scene_tree = scene_tree
	_orphan_baseline = _capture_orphan_ids()


# --- 框架内部方法 ---

func defer_cleanup(cleanup_callback: Callable) -> bool:
	if _cleanup_started or not cleanup_callback.is_valid():
		return false
	_cleanup_callbacks.append(cleanup_callback)
	return true


func expect_released(target: Object, label: String = "") -> int:
	if _cleanup_started or target == null:
		return 0

	var instance_id: int = target.get_instance_id()
	_release_expectations.append({
		"instance_id": instance_id,
		"label": label,
		"weak_ref": weakref(target),
	})
	return instance_id


func defer_queue_free(target: Node, label: String = "") -> int:
	if _cleanup_started or target == null:
		return 0

	var target_ref: WeakRef = weakref(target)
	var instance_id: int = expect_released(target, label)
	var registered: bool = defer_cleanup(func() -> void:
		var raw_target: Variant = target_ref.get_ref()
		if raw_target is Node:
			var live_target: Node = raw_target
			live_target.queue_free()
	)
	return instance_id if registered else 0


func defer_free(target: Object, label: String = "") -> int:
	if _cleanup_started or target == null or target is RefCounted:
		return 0

	var target_ref: WeakRef = weakref(target)
	var instance_id: int = expect_released(target, label)
	var registered: bool = defer_cleanup(func() -> void:
		var raw_target: Variant = target_ref.get_ref()
		if raw_target is Object:
			var live_target: Object = raw_target
			live_target.free()
	)
	return instance_id if registered else 0


func cleanup(settle_frame_count: int = DEFAULT_SETTLE_FRAME_COUNT) -> Dictionary:
	if _cleanup_started:
		return _cleanup_report.duplicate(true)

	_cleanup_started = true
	var cleanup_failures: Array[String] = []
	var cleanup_count: int = 0
	while not _cleanup_callbacks.is_empty():
		var cleanup_callback: Callable = _cleanup_callbacks.pop_back()
		if not cleanup_callback.is_valid():
			cleanup_failures.append("cleanup callback was released before teardown")
			continue
		var _cleanup_result: Variant = await cleanup_callback.call()
		cleanup_count += 1

	var frames_waited: int = await _settle_releases(settle_frame_count)
	var unreleased: Array[Dictionary] = _collect_unreleased()
	var new_orphans: Array[Dictionary] = _collect_new_orphans()
	_release_expectations.clear()

	_cleanup_report = {
		"ok": cleanup_failures.is_empty() and unreleased.is_empty() and new_orphans.is_empty(),
		"cleanup_count": cleanup_count,
		"frames_waited": frames_waited,
		"cleanup_failures": cleanup_failures,
		"unreleased": unreleased,
		"new_orphans": new_orphans,
	}
	return _cleanup_report.duplicate(true)


func assert_clean(test_case: GutTest, settle_frame_count: int = DEFAULT_SETTLE_FRAME_COUNT) -> Dictionary:
	var report: Dictionary = await cleanup(settle_frame_count)
	var cleanup_failures: Array[String] = _dictionary_string_array(report, "cleanup_failures")
	var unreleased: Array[Dictionary] = _dictionary_array(report, "unreleased")
	var new_orphans: Array[Dictionary] = _dictionary_array(report, "new_orphans")

	test_case.assert_eq(cleanup_failures, [], "生命周期清理回调必须全部可执行。")
	test_case.assert_eq(unreleased, [], "生命周期 scope 登记的对象必须完成释放。")
	test_case.assert_eq(new_orphans, [], "生命周期 scope 内不得新增孤儿节点。")
	test_case.assert_no_new_orphans("生命周期 scope 清理后仍存在 GUT 记录的孤儿节点。")
	return report


# --- 私有/辅助方法 ---

func _settle_releases(settle_frame_count: int) -> int:
	if not is_instance_valid(_scene_tree):
		return 0

	var wait_limit: int = maxi(settle_frame_count, 1)
	for frame_index: int in range(wait_limit):
		await _scene_tree.process_frame
		if _collect_unreleased().is_empty():
			return frame_index + 1
	return wait_limit


func _collect_unreleased() -> Array[Dictionary]:
	var unreleased: Array[Dictionary] = []
	for expectation: Dictionary in _release_expectations:
		var raw_weak_ref: Variant = expectation.get("weak_ref")
		if not raw_weak_ref is WeakRef:
			unreleased.append(_release_detail(expectation))
			continue

		var target_ref: WeakRef = raw_weak_ref
		if target_ref.get_ref() != null:
			unreleased.append(_release_detail(expectation))
	return unreleased


func _release_detail(expectation: Dictionary) -> Dictionary:
	return {
		"instance_id": _dictionary_int(expectation, "instance_id"),
		"label": _dictionary_string(expectation, "label"),
	}


func _capture_orphan_ids() -> Dictionary:
	var orphan_ids: Dictionary = {}
	for orphan_id: int in Node.get_orphan_node_ids():
		orphan_ids[orphan_id] = true
	return orphan_ids


func _collect_new_orphans() -> Array[Dictionary]:
	var new_orphans: Array[Dictionary] = []
	for orphan_id: int in Node.get_orphan_node_ids():
		if _orphan_baseline.has(orphan_id):
			continue
		new_orphans.append(_orphan_detail(orphan_id))
	return new_orphans


func _orphan_detail(orphan_id: int) -> Dictionary:
	var detail: Dictionary = {
		"instance_id": orphan_id,
		"class": "<released>",
		"name": "",
	}
	if not is_instance_id_valid(orphan_id):
		return detail

	var orphan_object: Object = instance_from_id(orphan_id)
	if not orphan_object is Node:
		return detail

	var orphan_node: Node = orphan_object
	detail["class"] = orphan_node.get_class()
	detail["name"] = String(orphan_node.name)
	return detail


func _dictionary_array(source: Dictionary, key: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var raw_value: Variant = source.get(key)
	if not raw_value is Array:
		return result

	var values: Array = raw_value
	for raw_entry: Variant in values:
		if raw_entry is Dictionary:
			var entry: Dictionary = raw_entry
			result.append(entry)
	return result


func _dictionary_string_array(source: Dictionary, key: String) -> Array[String]:
	var result: Array[String] = []
	var raw_value: Variant = source.get(key)
	if not raw_value is Array:
		return result

	var values: Array = raw_value
	for raw_entry: Variant in values:
		if raw_entry is String:
			result.append(raw_entry)
	return result


func _dictionary_int(source: Dictionary, key: String) -> int:
	var raw_value: Variant = source.get(key, 0)
	return raw_value if raw_value is int else 0


func _dictionary_string(source: Dictionary, key: String) -> String:
	var raw_value: Variant = source.get(key, "")
	return raw_value if raw_value is String else ""
