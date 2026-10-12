# 示例工厂观察顺序、取消和前置拒绝，不为示例引入另一套框架 API。
extends GutTest


const _BUILDER_SCRIPT = preload("res://examples/action_queue/stagger_builder.gd")
const _SCENE_KEY: StringName = &"example.staggered_ui"


func test_empty_targets_complete_without_a_factory_or_host() -> void:
	var result: Dictionary = _BUILDER_SCRIPT.build([], 0.1, Callable(), null)
	assert_eq(result, {"ok": true, "action": null, "error": &""})


func test_invalid_inputs_reject_before_calling_the_factory() -> void:
	var target: Node = Node.new()
	add_child_autofree(target)
	var counter: Array[int] = [0]
	var factory: Callable = func(_target: Node) -> GFVisualAction:
		counter[0] += 1
		return GFAction.callback(func() -> void: pass)
	for interval: float in [-0.1, NAN, INF]:
		var result: Dictionary = _BUILDER_SCRIPT.build([target], interval, factory, self)
		var invalid_interval_rejected: bool = result.get("ok") is bool and result.get("ok") == false
		assert_true(invalid_interval_rejected)
	var duplicate_result: Dictionary = _BUILDER_SCRIPT.build([target, target], 0.1, factory, self)
	var duplicate_target_rejected: bool = duplicate_result.get("error") is StringName and duplicate_result.get("error") == &"duplicate_target"
	assert_true(duplicate_target_rejected)
	assert_eq(counter[0], 0)


func test_ordered_targets_complete_once_after_the_last_action() -> void:
	var targets: Array[Node] = _targets(3)
	var order: Array[int] = []
	var factory: Callable = func(target: Node) -> GFVisualAction:
		var index: int = targets.find(target)
		return GFAction.sequence([
			GFAction.callback(func() -> void: order.append(index)),
			GFAction.wait(0.02, self),
		])
	var result: Dictionary = _BUILDER_SCRIPT.build(targets, 0.04, factory, self)
	var group: GFVisualActionGroup = _group(result)
	assert_not_null(group)
	if group == null:
		return
	var completion: Variant = group.execute()
	assert_true(completion is Signal)
	if completion is Signal:
		var signal_value: Signal = completion
		await signal_value
	assert_eq(order, [0, 1, 2])
	group.cancel()
	assert_eq(order, [0, 1, 2])


func test_cancelled_delays_never_start_later_targets() -> void:
	var targets: Array[Node] = _targets(3)
	var order: Array[int] = []
	var result: Dictionary = _BUILDER_SCRIPT.build(targets, 0.2, func(target: Node) -> GFVisualAction:
		var index: int = targets.find(target)
		return GFAction.callback(func() -> void: order.append(index))
	, self)
	var group: GFVisualActionGroup = _group(result)
	assert_not_null(group)
	if group == null:
		return
	var _completion: Variant = group.execute()
	await get_tree().process_frame
	await get_tree().process_frame
	group.cancel()
	var before: Array[int] = order.duplicate()
	await get_tree().create_timer(0.45).timeout
	assert_eq(order, before)
	assert_false(order.has(1))
	assert_false(order.has(2))


func test_factory_reusing_an_action_rejects_without_playback() -> void:
	var targets: Array[Node] = _targets(2)
	var hits: Array[int] = [0]
	var reused: GFVisualAction = GFAction.callback(func() -> void: hits[0] += 1)
	var result: Dictionary = _BUILDER_SCRIPT.build(targets, 0.04, func(_target: Node) -> GFVisualAction: return reused, self)
	var reused_action_rejected: bool = result.get("error") is StringName and result.get("error") == &"reused_action"
	var no_action_created: bool = result.has("action") and result.get("action") == null
	assert_true(reused_action_rejected)
	assert_true(no_action_created)
	assert_eq(hits[0], 0)


func test_reentrant_factory_removing_a_target_rejects_the_entire_build() -> void:
	var targets: Array[Node] = _targets(2)
	var hits: Array[int] = [0]
	var result: Dictionary = _BUILDER_SCRIPT.build(targets, 0.04, func(_target: Node) -> GFVisualAction:
		targets[1].get_parent().remove_child(targets[1])
		return GFAction.callback(func() -> void: hits[0] += 1)
	, self)
	var changed_target_rejected: bool = result.get("error") is StringName and result.get("error") == &"target_or_host_changed"
	var no_action_created: bool = result.has("action") and result.get("action") == null
	assert_true(changed_target_rejected)
	assert_true(no_action_created)
	assert_eq(hits[0], 0)


func test_reentrant_factory_freeing_a_target_rejects_without_a_script_error() -> void:
	var targets: Array[Node] = _targets(2)
	var hits: Array[int] = [0]
	var result: Dictionary = _BUILDER_SCRIPT.build(targets, 0.04, func(_target: Node) -> GFVisualAction:
		targets[1].free()
		return GFAction.callback(func() -> void: hits[0] += 1)
	, self)
	var freed_target_rejected: bool = result.get("error") is StringName and result.get("error") == &"target_or_host_changed"
	var no_action_created: bool = result.has("action") and result.get("action") == null
	assert_true(freed_target_rejected)
	assert_true(no_action_created)
	assert_eq(hits[0], 0)


func test_reentrant_factory_freeing_the_host_rejects_without_a_script_error() -> void:
	var targets: Array[Node] = _targets(1)
	var host: Node = Node.new()
	add_child_autofree(host)
	var hits: Array[int] = [0]
	var result: Dictionary = _BUILDER_SCRIPT.build(targets, 0.04, func(_target: Node) -> GFVisualAction:
		host.free()
		return GFAction.callback(func() -> void: hits[0] += 1)
	, host)
	var freed_host_rejected: bool = result.get("error") is StringName and result.get("error") == &"target_or_host_changed"
	var no_action_created: bool = result.has("action") and result.get("action") == null
	assert_true(freed_host_rejected)
	assert_true(no_action_created)
	assert_eq(hits[0], 0)


func test_scene_buttons_pause_cancel_and_restart_the_visible_cards() -> void:
	var resolver: GFResourceResolverUtility = GFResourceResolverUtility.new()
	resolver.init()
	assert_true(resolver.register_path(_SCENE_KEY, "res://examples/action_queue/staggered_ui.tscn", "PackedScene"))
	var loaded: Resource = resolver.load(_SCENE_KEY)
	resolver.dispose()
	assert_true(loaded is PackedScene)
	if not loaded is PackedScene:
		return
	var packed: PackedScene = loaded
	var scene: Node = packed.instantiate()
	add_child_autofree(scene)
	var start: Button = _find_button(scene, "开始 / 重播")
	var pause: Button = _find_button(scene, "暂停")
	var cancel: Button = _find_button(scene, "取消")
	assert_not_null(start)
	assert_not_null(pause)
	assert_not_null(cancel)
	if start == null or pause == null or cancel == null:
		return
	start.pressed.emit()
	await get_tree().create_timer(0.12).timeout
	assert_false(pause.disabled)
	pause.pressed.emit()
	var paused: Array[float] = _card_alpha(scene)
	assert_eq(paused.size(), 12)
	await get_tree().create_timer(0.25).timeout
	assert_eq(_card_alpha(scene), paused)
	pause.pressed.emit()
	cancel.pressed.emit()
	var cancelled: Array[float] = _card_alpha(scene)
	await get_tree().create_timer(1.4).timeout
	assert_eq(_card_alpha(scene), cancelled)
	assert_true(pause.disabled)
	start.pressed.emit()
	await get_tree().create_timer(1.4).timeout
	for alpha: float in _card_alpha(scene):
		assert_almost_eq(alpha, 1.0, 0.0001)
	assert_true(pause.disabled)


func _targets(count: int) -> Array[Node]:
	var result: Array[Node] = []
	for _index: int in range(count):
		var target: Node = Node.new()
		add_child_autofree(target)
		result.append(target)
	return result


func _group(result: Dictionary) -> GFVisualActionGroup:
	var value: Variant = result.get("action")
	if value is GFVisualActionGroup:
		var group: GFVisualActionGroup = value
		return group
	return null


func _find_button(scene: Node, text: String) -> Button:
	for child: Node in scene.find_children("*", "Button", true, false):
		if child is Button:
			var button: Button = child
			if button.text == text:
				return button
	return null


func _card_alpha(scene: Node) -> Array[float]:
	var result: Array[float] = []
	for child: Node in scene.find_children("*", "GridContainer", true, false):
		for card: Node in child.get_children():
			if card is CanvasItem:
				var canvas: CanvasItem = card
				result.append(canvas.modulate.a)
	return result
