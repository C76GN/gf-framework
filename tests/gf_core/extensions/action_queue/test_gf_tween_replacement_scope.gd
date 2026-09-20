# 验证替换作用域的弱所有权、精确租约和两阶段终态通知。
extends GutTest


# --- 私有变量 ---

var _scopes: Array[GFTweenReplacementScope] = []
var _notification_witnesses: Array[WeakRef] = []


# --- Godot 生命周期方法 ---

func after_each() -> void:
	for scope: GFTweenReplacementScope in _scopes:
		scope.dispose()
	_scopes.clear()
	for witness: WeakRef in _notification_witnesses:
		assert_true(witness.get_ref() == null, "终态通知不能留下捕获自身的测试回调循环。")
	_notification_witnesses.clear()


# --- 测试方法 ---

func test_claim_counts_actions_and_release_requires_matching_action_and_lease() -> void:
	var scope: GFTweenReplacementScope = _scope()
	var target: RefCounted = RefCounted.new()
	var first: FakeAction = FakeAction.new("first")
	var other: FakeAction = FakeAction.new("other")
	var lease: int = _claim(scope, first, target, [^"position", ^"position:x", ^"modulate:a"])
	assert_gt(lease, 0)
	assert_eq(scope.get_active_count(), 1)
	assert_true(scope.owns(first, lease))
	assert_false(scope.owns(other, lease))
	scope.release(other, lease)
	scope.release(first, lease + 1)
	assert_true(scope.owns(first, lease))
	scope.release(first, lease)
	scope.release(first, lease)
	assert_eq(scope.get_active_count(), 0)
	assert_false(scope.owns(first, lease))
	assert_true(first.detached_leases.is_empty(), "正常释放不应停止或通知动作。")
	assert_true(first.notified_generations.is_empty())


func test_property_root_and_components_replace_each_other_conservatively() -> void:
	var paths: Array[NodePath] = [^"position", ^"position:x", ^"position:y", ^"position"]
	var scope: GFTweenReplacementScope = _scope()
	var target: RefCounted = RefCounted.new()
	var actions: Array[FakeAction] = []
	for path: NodePath in paths:
		var action: FakeAction = FakeAction.new(String(path))
		assert_gt(_claim(scope, action, target, [path]), 0)
		actions.append(action)
		assert_eq(scope.get_active_count(), 1)
	for index: int in range(actions.size() - 1):
		assert_eq(actions[index].detached_leases.size(), 1)
		assert_eq(actions[index].notified_generations, [1])
		assert_false(actions[index].running)
	var latest_action: FakeAction = actions[actions.size() - 1]
	assert_true(latest_action.running)


func test_different_roots_targets_and_scopes_remain_independent() -> void:
	var scope: GFTweenReplacementScope = _scope()
	var second_scope: GFTweenReplacementScope = _scope()
	var target: RefCounted = RefCounted.new()
	var other_target: RefCounted = RefCounted.new()
	var first: FakeAction = FakeAction.new("position")
	var second: FakeAction = FakeAction.new("color")
	var third: FakeAction = FakeAction.new("other_target")
	var fourth: FakeAction = FakeAction.new("other_scope")
	assert_gt(_claim(scope, first, target, [^"position"]), 0)
	assert_gt(_claim(scope, second, target, [^"modulate:a"]), 0)
	assert_gt(_claim(scope, third, other_target, [^"position"]), 0)
	assert_gt(_claim(second_scope, fourth, target, [^"position"]), 0)
	assert_eq(scope.get_active_count(), 3)
	assert_eq(second_scope.get_active_count(), 1)
	assert_true(first.running and second.running and third.running and fourth.running)


func test_rotation_alias_is_normalized_only_for_native_node_2d_and_node_3d() -> void:
	var targets: Array[Node] = [Node2D.new(), Node3D.new()]
	for target: Node in targets:
		add_child_autofree(target)
		var scope: GFTweenReplacementScope = _scope()
		var first: FakeAction = FakeAction.new("radians")
		var second: FakeAction = FakeAction.new("degrees")
		assert_gt(_claim(scope, first, target, [^"rotation"]), 0)
		assert_gt(_claim(scope, second, target, [^"rotation_degrees"]), 0)
		assert_false(first.running)
		assert_eq(scope.get_active_count(), 1)
	var plain_target: RefCounted = RefCounted.new()
	var plain_scope: GFTweenReplacementScope = _scope()
	var first_plain: FakeAction = FakeAction.new("plain_radians")
	var second_plain: FakeAction = FakeAction.new("plain_degrees")
	assert_gt(_claim(plain_scope, first_plain, plain_target, [^"rotation"]), 0)
	assert_gt(_claim(plain_scope, second_plain, plain_target, [^"rotation_degrees"]), 0)
	assert_eq(plain_scope.get_active_count(), 2)
	assert_true(first_plain.running)


func test_global_and_project_property_aliases_are_not_inferred() -> void:
	var scope: GFTweenReplacementScope = _scope()
	var target: Node2D = Node2D.new()
	add_child_autofree(target)
	var local_action: FakeAction = FakeAction.new("local")
	var global_action: FakeAction = FakeAction.new("global")
	assert_gt(_claim(scope, local_action, target, [^"position"]), 0)
	assert_gt(_claim(scope, global_action, target, [^"global_position"]), 0)
	assert_eq(scope.get_active_count(), 2)
	assert_true(local_action.running)


func test_all_conflicting_actions_detach_before_first_notification() -> void:
	var scope: GFTweenReplacementScope = _scope()
	var target: RefCounted = RefCounted.new()
	var events: Array[String] = []
	var first: FakeAction = FakeAction.new("position", events)
	var second: FakeAction = FakeAction.new("color", events)
	var replacement: FakeAction = FakeAction.new("replacement", events)
	assert_gt(_claim(scope, first, target, [^"position"]), 0)
	assert_gt(_claim(scope, second, target, [^"modulate"]), 0)
	first.on_notify = func() -> void:
		assert_false(second.running, "首个通知前必须已停止所有旧写入者。")
		assert_eq(scope.get_active_count(), 1)
	assert_gt(_claim(scope, replacement, target, [^"position:x", ^"modulate:a"]), 0)
	assert_eq(events, ["detach:position", "detach:color", "notify:position", "notify:color"])
	assert_true(replacement.running)
	assert_eq(first.notified_generations, [1])
	assert_eq(second.notified_generations, [1])


func test_callback_reentrancy_keeps_the_later_claim_and_outer_claim_returns_zero() -> void:
	var scope: GFTweenReplacementScope = _scope()
	var target: RefCounted = RefCounted.new()
	var events: Array[String] = []
	var first: FakeAction = FakeAction.new("first", events)
	var outer: FakeAction = FakeAction.new("outer", events)
	var later: FakeAction = FakeAction.new("later", events)
	assert_gt(_claim(scope, first, target, [^"position"]), 0)
	first.on_notify = func() -> void:
		assert_gt(_claim(scope, later, target, [^"position:x"]), 0)
	var outer_lease: int = _claim(scope, outer, target, [^"position"])
	assert_eq(outer_lease, 0)
	assert_false(outer.running)
	assert_eq(outer.notified_generations, [1])
	assert_true(scope.owns(later, later.lease))
	assert_true(later.running)
	assert_eq(scope.get_active_count(), 1)
	assert_eq(events, ["detach:first", "notify:first", "detach:outer", "notify:outer"])


func test_reentrant_claim_survives_later_notifications_and_stale_release() -> void:
	var scope: GFTweenReplacementScope = _scope()
	var target: RefCounted = RefCounted.new()
	var events: Array[String] = []
	var first: FakeAction = FakeAction.new("first", events)
	var second: FakeAction = FakeAction.new("second", events)
	var outer: FakeAction = FakeAction.new("outer", events)
	var later: FakeAction = FakeAction.new("later", events)
	var first_lease: int = _claim(scope, first, target, [^"position"])
	var second_lease: int = _claim(scope, second, target, [^"modulate"])
	first.on_notify = func() -> void:
		assert_false(second.running)
		assert_gt(_claim(scope, later, target, [^"position", ^"modulate"]), 0)
	second.on_notify = func() -> void:
		scope.release(second, second_lease)
		assert_true(scope.owns(later, later.lease))
	assert_eq(_claim(scope, outer, target, [^"position", ^"modulate"]), 0)
	scope.release(first, first_lease)
	assert_true(scope.owns(later, later.lease))
	assert_eq(events, [
		"detach:first", "detach:second", "notify:first", "detach:outer", "notify:outer", "notify:second",
	])
	# 测试调用帧自身也持有闭包临时值，返回后再验证最后的弱引用已释放。
	_notification_witnesses.append(weakref(second))


func test_dispose_detaches_all_before_notify_and_rejects_reentrant_claims() -> void:
	var scope: GFTweenReplacementScope = _scope()
	var target: RefCounted = RefCounted.new()
	var events: Array[String] = []
	var first: FakeAction = FakeAction.new("first", events)
	var second: FakeAction = FakeAction.new("second", events)
	var later: FakeAction = FakeAction.new("later", events)
	assert_gt(_claim(scope, first, target, [^"position"]), 0)
	assert_gt(_claim(scope, second, target, [^"modulate"]), 0)
	first.on_notify = func() -> void:
		assert_true(scope.is_disposed())
		assert_false(second.running)
		assert_eq(scope.get_active_count(), 0)
		assert_eq(_claim(scope, later, target, [^"position"]), 0)
		scope.dispose()
	scope.dispose()
	scope.dispose()
	assert_true(scope.is_disposed())
	assert_eq(scope.get_active_count(), 0)
	assert_eq(events, ["detach:first", "detach:second", "notify:first", "notify:second"])
	assert_true(later.detached_leases.is_empty())


func test_dispose_from_replacement_notification_invalidates_pending_claim() -> void:
	var scope: GFTweenReplacementScope = _scope()
	var target: RefCounted = RefCounted.new()
	var first: FakeAction = FakeAction.new("first")
	var replacement: FakeAction = FakeAction.new("replacement")
	assert_gt(_claim(scope, first, target, [^"position"]), 0)
	first.on_notify = func() -> void: scope.dispose()
	assert_eq(_claim(scope, replacement, target, [^"position"]), 0)
	assert_false(replacement.running)
	assert_eq(replacement.notified_generations, [1])
	assert_true(scope.is_disposed())
	assert_eq(scope.get_active_count(), 0)


func test_scope_does_not_keep_action_or_target_alive() -> void:
	var scope: GFTweenReplacementScope = _scope()
	var target: RefCounted = RefCounted.new()
	var action: FakeAction = FakeAction.new("temporary_action")
	assert_gt(_claim(scope, action, target, [^"position"]), 0)
	var action_ref: WeakRef = weakref(action)
	action = null
	assert_true(action_ref.get_ref() == null)
	assert_eq(scope.get_active_count(), 0)
	var next_action: FakeAction = FakeAction.new("temporary_target")
	var next_lease: int = _claim(scope, next_action, target, [^"position"])
	var target_ref: WeakRef = weakref(target)
	target = null
	assert_true(target_ref.get_ref() == null)
	assert_false(scope.owns(next_action, next_lease))
	assert_eq(scope.get_active_count(), 0)


func test_invalid_or_queued_for_deletion_targets_do_not_displace_old_actions() -> void:
	var scope: GFTweenReplacementScope = _scope()
	var target: Node2D = Node2D.new()
	add_child_autofree(target)
	var first: FakeAction = FakeAction.new("first")
	var replacement: FakeAction = FakeAction.new("replacement")
	assert_gt(_claim(scope, first, target, [^"position"]), 0)
	assert_eq(scope.claim(replacement, null, [^"position"]), 0)
	assert_true(first.running)
	target.queue_free()
	assert_eq(scope.claim(replacement, target, [^"position"]), 0)
	assert_eq(scope.get_active_count(), 0)
	assert_true(first.detached_leases.is_empty())


func test_invalid_protocol_and_empty_paths_are_rejected_before_old_detach() -> void:
	var scope: GFTweenReplacementScope = _scope()
	var target: RefCounted = RefCounted.new()
	var first: FakeAction = FakeAction.new("first")
	var lease: int = _claim(scope, first, target, [^"position"])
	var invalid_actions: Array[Object] = [
		RefCounted.new(), MissingNotifyAction.new(), WrongDetachArityAction.new(),
		WrongNotifyArityAction.new(), WrongArgumentTypeAction.new(),
	]
	for invalid_action: Object in invalid_actions:
		assert_eq(scope.claim(invalid_action, target, [^"position"]), 0)
		assert_true(scope.owns(first, lease))
	var valid_action: FakeAction = FakeAction.new("valid")
	assert_eq(scope.claim(valid_action, target, []), 0)
	assert_eq(scope.claim(valid_action, target, [^"position", NodePath()]), 0)
	assert_eq(scope.claim(null, target, [^"position"]), 0)
	assert_true(first.detached_leases.is_empty())
	assert_eq(scope.get_active_count(), 1)


func test_protocol_optional_arguments_accept_one_supplied_integer() -> void:
	var scope: GFTweenReplacementScope = _scope()
	var target: RefCounted = RefCounted.new()
	var action: OptionalArgumentsAction = OptionalArgumentsAction.new()
	var first_lease: int = scope.claim(action, target, [^"position"])
	assert_gt(first_lease, 0)
	var replacement: FakeAction = FakeAction.new("replacement")
	assert_gt(_claim(scope, replacement, target, [^"position"]), 0)
	assert_eq(action.detached_lease, first_lease)
	assert_eq(action.notified_generation, 7)


func test_same_action_reclaim_has_new_lease_and_old_release_cannot_remove_it() -> void:
	var scope: GFTweenReplacementScope = _scope()
	var target: RefCounted = RefCounted.new()
	var other_target: RefCounted = RefCounted.new()
	var action: FakeAction = FakeAction.new("reused")
	var old_lease: int = _claim(scope, action, target, [^"position"])
	var new_lease: int = _claim(scope, action, other_target, [^"modulate"])
	assert_gt(new_lease, old_lease)
	assert_eq(scope.get_active_count(), 1)
	assert_false(scope.owns(action, old_lease))
	scope.release(action, old_lease)
	assert_true(scope.owns(action, new_lease))
	assert_eq(action.detached_leases, [old_lease])


func test_property_input_mutation_cannot_change_registered_roots() -> void:
	var scope: GFTweenReplacementScope = _scope()
	var target: RefCounted = RefCounted.new()
	var first: FakeAction = FakeAction.new("first")
	var paths: Array[NodePath] = [^"position:x"]
	assert_gt(_claim(scope, first, target, paths), 0)
	paths[0] = ^"modulate"
	var replacement: FakeAction = FakeAction.new("replacement")
	assert_gt(_claim(scope, replacement, target, [^"position:y"]), 0)
	assert_false(first.running)
	assert_eq(scope.get_active_count(), 1)


# --- 私有/辅助方法 ---

func _scope() -> GFTweenReplacementScope:
	var scope: GFTweenReplacementScope = GFTweenReplacementScope.new()
	_scopes.append(scope)
	return scope


func _claim(
	scope: GFTweenReplacementScope,
	action: FakeAction,
	target: Object,
	paths: Array[NodePath]
) -> int:
	action.lease = scope.claim(action, target, paths)
	return action.lease


# --- 内部类 ---

class FakeAction extends RefCounted:
	var label: String = ""
	var events: Array[String] = []
	var lease: int = 0
	var running: bool = true
	var detached_leases: Array[int] = []
	var notified_generations: Array[int] = []
	var on_notify: Callable = Callable()


	func _init(action_label: String, action_events: Array[String] = []) -> void:
		label = action_label
		events = action_events


	func detach_replacement(stopped_lease: int) -> int:
		detached_leases.append(stopped_lease)
		events.append("detach:" + label)
		running = false
		lease = 0
		return 1


	func notify_replaced(stopped_generation: int) -> void:
		notified_generations.append(stopped_generation)
		events.append("notify:" + label)
		# 一次性终态回调先摘除，避免回调捕获本动作后形成 RefCounted 循环。
		var callback: Callable = on_notify
		on_notify = Callable()
		if callback.is_valid():
			var _callback_result: Variant = callback.call()


class MissingNotifyAction extends RefCounted:
	func detach_replacement(_lease: int) -> int:
		return 1


class WrongDetachArityAction extends RefCounted:
	func detach_replacement() -> int:
		return 1


	func notify_replaced(_generation: int) -> void:
		pass


class WrongNotifyArityAction extends RefCounted:
	func detach_replacement(_lease: int) -> int:
		return 1


	func notify_replaced(_generation: int, _required: int) -> void:
		pass


class WrongArgumentTypeAction extends RefCounted:
	func detach_replacement(_lease: String) -> int:
		return 1


	func notify_replaced(_generation: int) -> void:
		pass


class OptionalArgumentsAction extends RefCounted:
	var detached_lease: int = 0
	var notified_generation: int = 0


	func detach_replacement(lease: int, _optional: int = 0) -> int:
		detached_lease = lease
		return 7


	func notify_replaced(generation: int, _optional: int = 0) -> void:
		notified_generation = generation
