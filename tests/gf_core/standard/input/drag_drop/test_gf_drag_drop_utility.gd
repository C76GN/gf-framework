## 测试通用拖拽会话与落点匹配工具。
extends GutTest


# --- 常量 ---

const _GF_DRAG_DROP_CONTROLLER_SCRIPT = preload("res://addons/gf/standard/input/drag_drop/gf_drag_drop_controller.gd")


# --- 测试方法 ---

## 验证拖拽释放会选择命中的最高优先级落点。
func test_drop_chooses_highest_priority_accepting_zone() -> void:
	var utility: GFDragDropUtility = GFDragDropUtility.new()
	var _low_zone: GFDropZone = utility.register_rect_zone(
		&"low",
		Rect2(Vector2.ZERO, Vector2(100.0, 100.0)),
		PackedStringArray(["item"]),
		{ "priority": 1 }
	)
	var _high_zone: GFDropZone = utility.register_rect_zone(
		&"high",
		Rect2(Vector2.ZERO, Vector2(100.0, 100.0)),
		PackedStringArray(["item"]),
		{ "priority": 10 }
	)

	var session_id: int = utility.start_drag(&"item", { "id": "sample" }, Vector2(10.0, 10.0))
	var result: Dictionary = utility.drop(session_id, Vector2(20.0, 20.0))

	assert_true(GFVariantData.get_option_bool(result, "ok"), "命中可接收落点时应返回成功。")
	assert_eq(GFVariantData.get_option_string_name(result, "zone_id"), &"high", "应选择最高优先级落点。")
	assert_false(utility.has_active_session(session_id), "成功 drop 后会话应结束。")


## 验证落点拒绝时保留当前拖拽会话。
func test_rejected_drop_keeps_session_active() -> void:
	var utility: GFDragDropUtility = GFDragDropUtility.new()
	var _locked_zone: GFDropZone = utility.register_rect_zone(
		&"locked",
		Rect2(Vector2.ZERO, Vector2(100.0, 100.0)),
		PackedStringArray(["item"]),
		{
			"drop": func(_session: GFDragSession, _zone: GFDropZone, _position: Variant) -> Dictionary:
				return {
					"ok": false,
					"reason": &"locked",
				},
		}
	)

	var session_id: int = utility.start_drag(&"item", null, Vector2(5.0, 5.0))
	var result: Dictionary = utility.drop(session_id, Vector2(10.0, 10.0))

	assert_false(GFVariantData.get_option_bool(result, "ok", true), "落点回调可拒绝释放。")
	assert_eq(GFVariantData.get_option_string_name(result, "reason"), &"locked", "拒绝原因应透传。")
	assert_true(utility.has_active_session(session_id), "拒绝 drop 后会话应继续保持。")


## 验证布尔拒绝结果会得到稳定默认原因。
func test_boolean_false_drop_uses_default_reject_reason() -> void:
	var utility: GFDragDropUtility = GFDragDropUtility.new()
	var reject_drop: Callable = func(_session: GFDragSession, _zone: GFDropZone, _position: Variant) -> bool:
		return false
	var _rejecting_zone: GFDropZone = utility.register_rect_zone(
		&"rejecting",
		Rect2(Vector2.ZERO, Vector2(100.0, 100.0)),
		PackedStringArray(["item"]),
		{
			"drop": reject_drop,
		}
	)

	var session_id: int = utility.start_drag(&"item", null, Vector2(5.0, 5.0))
	var result: Dictionary = utility.drop(session_id, Vector2(10.0, 10.0))

	assert_false(GFVariantData.get_option_bool(result, "ok", true), "布尔 false 应表示 drop 被拒绝。")
	assert_eq(GFVariantData.get_option_string_name(result, "reason"), &"drop_rejected", "未显式提供原因时应给出稳定默认原因。")
	assert_true(utility.has_active_session(session_id), "拒绝 drop 后会话应继续保持。")


## 验证 Control 落点按全局矩形命中。
func test_control_zone_uses_global_rect() -> void:
	var utility: GFDragDropUtility = GFDragDropUtility.new()
	var control: Control = Control.new()
	control.position = Vector2(40.0, 40.0)
	control.size = Vector2(30.0, 30.0)
	add_child_autofree(control)
	await get_tree().process_frame

	var _control_zone: GFDropZone = utility.register_control_zone(&"control", control, PackedStringArray(["ui"]))
	var session_id: int = utility.start_drag(&"ui", null, Vector2(45.0, 45.0))

	assert_eq(utility.get_drop_candidates(session_id, Vector2(45.0, 45.0)).size(), 1, "指针在控件全局矩形内应命中落点。")
	assert_eq(utility.get_drop_candidates(session_id, Vector2(10.0, 10.0)).size(), 0, "指针在控件外不应命中落点。")


## 验证隐藏 Control 不再作为落点候选。
func test_control_zone_ignores_hidden_or_detached_controls() -> void:
	var utility: GFDragDropUtility = GFDragDropUtility.new()
	var control: Control = Control.new()
	control.position = Vector2(40.0, 40.0)
	control.size = Vector2(30.0, 30.0)
	add_child_autofree(control)
	await get_tree().process_frame

	var _control_zone: GFDropZone = utility.register_control_zone(&"control", control, PackedStringArray(["ui"]))
	var session_id: int = utility.start_drag(&"ui", null, Vector2(45.0, 45.0))
	control.visible = false

	assert_eq(utility.get_drop_candidates(session_id, Vector2(45.0, 45.0)).size(), 0, "隐藏 Control 不应继续命中落点。")


## 验证 Control 落点遵循通用不可交互状态。
func test_control_zone_ignores_non_interactive_controls() -> void:
	var utility: GFDragDropUtility = GFDragDropUtility.new()
	var control: Control = Control.new()
	control.position = Vector2(40.0, 40.0)
	control.size = Vector2(30.0, 30.0)
	add_child_autofree(control)
	await get_tree().process_frame

	var _control_zone: GFDropZone = utility.register_control_zone(&"control", control, PackedStringArray(["ui"]))
	var session_id: int = utility.start_drag(&"ui", null, Vector2(45.0, 45.0))

	control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	assert_eq(utility.get_drop_candidates(session_id, Vector2(45.0, 45.0)).size(), 0, "mouse_filter ignore 的 Control 不应命中落点。")

	var button: Button = Button.new()
	button.position = Vector2(80.0, 40.0)
	button.size = Vector2(30.0, 30.0)
	add_child_autofree(button)
	await get_tree().process_frame
	var _button_zone: GFDropZone = utility.register_control_zone(&"button", button, PackedStringArray(["ui"]))

	button.disabled = true
	assert_eq(utility.get_drop_candidates(session_id, Vector2(85.0, 45.0)).size(), 0, "禁用按钮不应命中落点。")

	button.disabled = false
	assert_eq(utility.get_drop_candidates(session_id, Vector2(85.0, 45.0)).size(), 1, "恢复交互后按钮应重新命中落点。")


## 验证释放后的 Control 落点会从注册表剪枝。
func test_control_zone_is_pruned_after_control_is_freed() -> void:
	var utility: GFDragDropUtility = GFDragDropUtility.new()
	watch_signals(utility)
	var control: Control = Control.new()
	control.position = Vector2(40.0, 40.0)
	control.size = Vector2(30.0, 30.0)
	add_child(control)
	await get_tree().process_frame

	var _control_zone: GFDropZone = utility.register_control_zone(&"control", control, PackedStringArray(["ui"]))
	var session_id: int = utility.start_drag(&"ui", null, Vector2(45.0, 45.0))
	control.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame

	assert_eq(utility.get_drop_candidates(session_id, Vector2(45.0, 45.0)).size(), 0, "已释放 Control 的落点不应继续作为候选。")
	assert_null(utility.get_zone(&"control"), "已释放 Control 的落点应从注册表移除。")
	assert_signal_emit_count(utility, "drop_zone_unregistered", 1, "剪枝失效落点时应发注销信号。")


## 验证落点剪枝也可被项目或控制器显式调用。
func test_prune_stale_zones_reports_removed_count() -> void:
	var utility: GFDragDropUtility = GFDragDropUtility.new()
	var control: Control = Control.new()
	control.position = Vector2(40.0, 40.0)
	control.size = Vector2(30.0, 30.0)
	add_child(control)
	await get_tree().process_frame

	var _control_zone: GFDropZone = utility.register_control_zone(&"control", control, PackedStringArray(["ui"]))
	control.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame

	assert_eq(utility.prune_stale_zones(), 1, "显式剪枝应报告移除的失效落点数量。")
	assert_eq(utility.prune_stale_zones(), 0, "重复剪枝不应重复报告。")


## 验证 only_accepting 查询会先检查接收规则，避免无意义命中检测。
func test_only_accepting_candidates_skip_contains_when_zone_cannot_accept() -> void:
	var utility: GFDragDropUtility = GFDragDropUtility.new()
	var counters: Dictionary = {
		"contains": 0,
		"accepts": 0,
	}
	var zone: GFDropZone = GFDropZone.new()
	zone.zone_id = &"slot"
	zone.accepted_types = PackedStringArray(["item"])
	zone.contains_callable = func(_position: Variant, _session: GFDragSession) -> bool:
		counters["contains"] = GFVariantData.get_option_int(counters, "contains") + 1
		return true
	zone.can_accept_callable = func(_session: GFDragSession, _zone: GFDropZone) -> bool:
		counters["accepts"] = GFVariantData.get_option_int(counters, "accepts") + 1
		return false
	var _registered: bool = utility.register_zone(zone)
	var session_id: int = utility.start_drag(&"item", null, Vector2.ZERO)

	assert_eq(utility.get_drop_candidates(session_id, Vector2.ZERO, true).size(), 0, "不可接收落点不应出现在 only_accepting 结果中。")
	assert_eq(GFVariantData.get_option_int(counters, "accepts"), 1, "应检查可接收规则。")
	assert_eq(GFVariantData.get_option_int(counters, "contains"), 0, "不可接收时不应继续执行命中检测。")


## 验证调试快照默认可直接 JSON 序列化。
func test_debug_snapshot_defaults_to_json_compatible_values() -> void:
	var utility: GFDragDropUtility = GFDragDropUtility.new()
	var _zone: GFDropZone = utility.register_rect_zone(
		&"slot",
		Rect2(Vector2.ZERO, Vector2(100.0, 100.0)),
		PackedStringArray(["item"]),
		{
			"metadata": {
				"tags": PackedStringArray(["hotbar", "bag"]),
				"origin": Vector2(1.0, 2.0),
			},
		}
	)
	var session_id: int = utility.start_drag(
		&"item",
		{ "payload_position": Vector2(3.0, 4.0) },
		Vector2(5.0, 6.0),
		null,
		{ "cursor": Vector2(7.0, 8.0) }
	)
	var _updated: bool = utility.update_drag(session_id, Vector2(9.0, 10.0))

	var snapshot: Dictionary = utility.get_debug_snapshot()
	var json_text: String = JSON.stringify(snapshot)

	assert_true(json_text.length() > 0, "JSON 兼容调试快照应可序列化为文本。")
	assert_true(json_text.find(GFVariantJsonCodec.JSON_MARKER_KEY) >= 0, "Godot 专有类型应使用 GF JSON 标记编码。")


## 验证重复注册同 ID 落点会先发出注销事件。
func test_register_zone_replaces_duplicate_id_with_unregister_signal() -> void:
	var utility: GFDragDropUtility = GFDragDropUtility.new()
	watch_signals(utility)
	var first_zone: GFDropZone = GFDropZone.from_rect(&"slot", Rect2(Vector2.ZERO, Vector2.ONE))
	var second_zone: GFDropZone = GFDropZone.from_rect(&"slot", Rect2(Vector2.ZERO, Vector2(2.0, 2.0)))

	assert_true(utility.register_zone(first_zone), "首次注册应成功。")
	assert_true(utility.register_zone(second_zone), "重复 ID 注册应替换旧落点。")

	assert_signal_emit_count(utility, "drop_zone_registered", 2, "两次注册都应发注册信号。")
	assert_signal_emit_count(utility, "drop_zone_unregistered", 1, "替换旧落点前应发注销信号。")
	assert_eq(utility.get_zone(&"slot"), second_zone, "重复注册后应保留新落点。")


## 验证释放到无落点位置会结束拖拽会话。
func test_drop_without_zone_rejects_and_ends_session() -> void:
	var utility: GFDragDropUtility = GFDragDropUtility.new()
	watch_signals(utility)
	var session_id: int = utility.start_drag(&"item", null, Vector2.ZERO)

	var result: Dictionary = utility.drop(session_id, Vector2(500.0, 500.0))

	assert_false(GFVariantData.get_option_bool(result, "ok", true), "无落点释放应返回失败。")
	assert_eq(GFVariantData.get_option_string_name(result, "reason"), &"no_drop_zone", "无落点释放应给出稳定原因。")
	assert_false(utility.has_active_session(session_id), "无落点释放也应结束拖拽会话。")
	assert_signal_emitted(utility, "drag_drop_rejected", "无落点释放应发拒绝信号。")


## 验证可选控制器能用单指针驱动底层拖放工具。
func test_controller_uses_pointer_capture_for_active_drag() -> void:
	var controller: Node = _new_drag_drop_controller()
	add_child_autofree(controller)
	var _zone: Variant = controller.call(
		"register_rect_zone",
		&"slot",
		Rect2(Vector2.ZERO, Vector2(100.0, 100.0)),
		PackedStringArray(["item"])
	)

	var session_id: int = GFVariantData.to_int(controller.call(
		"start_drag",
		&"item",
		null,
		Vector2.ZERO,
		null,
		{ "pointer_id": 2 }
	))

	assert_gt(session_id, 0, "控制器应能启动拖拽会话。")
	assert_false(GFVariantData.to_bool(controller.call("update_pointer", Vector2(10.0, 10.0), 3)), "非捕获指针不应更新拖拽。")
	assert_true(GFVariantData.to_bool(controller.call("update_pointer", Vector2(10.0, 10.0), 2)), "捕获指针应能更新拖拽。")

	var wrong_pointer_result: Dictionary = GFVariantData.to_dictionary(controller.call("drop", Vector2(10.0, 10.0), 3))
	assert_false(GFVariantData.get_option_bool(wrong_pointer_result, "ok", true), "非捕获指针不应释放拖拽。")
	assert_eq(GFVariantData.get_option_string_name(wrong_pointer_result, "reason"), &"pointer_mismatch", "错误指针应返回稳定原因。")
	assert_true(GFVariantData.to_bool(controller.call("has_active_drag")), "错误指针释放不应结束活动拖拽。")

	var result: Dictionary = GFVariantData.to_dictionary(controller.call("drop", Vector2(10.0, 10.0), 2))
	assert_true(GFVariantData.get_option_bool(result, "ok"), "捕获指针应能完成释放。")
	assert_false(GFVariantData.to_bool(controller.call("has_active_drag")), "成功释放后控制器不应保留活动拖拽。")


## 验证控制器在 source 离树时自动取消拖拽。
func test_controller_cancels_drag_when_source_exits_tree() -> void:
	var controller: Node = _new_drag_drop_controller()
	add_child_autofree(controller)
	watch_signals(controller)
	var source: Control = Control.new()
	add_child(source)
	await get_tree().process_frame

	var session_id: int = GFVariantData.to_int(controller.call("start_drag", &"ui", null, Vector2.ZERO, source))
	assert_gt(session_id, 0, "控制器应能用 source 启动拖拽。")

	source.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame

	assert_false(GFVariantData.to_bool(controller.call("has_active_drag")), "source 离树后控制器应取消拖拽。")
	assert_signal_emit_count(controller, "drag_cancelled", 1, "source 离树应发出一次取消信号。")


## 验证控制器可临时 reparent source，并在取消时恢复原父级。
func test_controller_restores_reparented_source_on_cancel() -> void:
	var controller: Node = _new_drag_drop_controller()
	add_child_autofree(controller)
	var source_parent: Control = Control.new()
	var drag_parent: Control = Control.new()
	var source: Control = Control.new()
	add_child_autofree(source_parent)
	add_child_autofree(drag_parent)
	source_parent.add_child(source)
	await get_tree().process_frame

	var session_id: int = GFVariantData.to_int(controller.call(
		"start_drag",
		&"ui",
		null,
		Vector2.ZERO,
		source,
		{
			"drag_parent": drag_parent,
			"restore_source_parent_on_cancel": true,
		}
	))

	assert_gt(session_id, 0, "控制器应能启动带 drag_parent 的拖拽。")
	assert_eq(source.get_parent(), drag_parent, "开始拖拽时 source 应被临时移动到 drag_parent。")

	assert_true(GFVariantData.to_bool(controller.call("cancel_drag", &"test_cancel")), "取消活动拖拽应成功。")
	assert_eq(source.get_parent(), source_parent, "取消后 source 应恢复到原父级。")


## 验证底层拒绝启动时不会留下 source reparent 副作用。
func test_controller_failed_start_rolls_back_drag_visual_transaction() -> void:
	var controller: Node = _new_drag_drop_controller()
	add_child_autofree(controller)
	var source_parent: Control = Control.new()
	var drag_parent: Control = Control.new()
	var source: Control = Control.new()
	add_child_autofree(source_parent)
	add_child_autofree(drag_parent)
	source_parent.add_child(source)
	await get_tree().process_frame

	var session_id: int = GFVariantData.to_int(controller.call(
		"start_drag",
		&"",
		null,
		Vector2.ZERO,
		source,
		{ "drag_parent": drag_parent }
	))

	assert_eq(session_id, -1, "空拖拽类型应拒绝启动。")
	assert_eq(source.get_parent(), source_parent, "失败启动不得改变 source 父级。")
	assert_eq(source.tree_exited.get_connections().size(), 0, "失败启动不得留下 source 生命周期监听。")


## 验证控制器在提交前拒绝 source 子孙作为 drag_parent。
func test_controller_rejects_descendant_drag_parent_before_mutation() -> void:
	var controller: Node = _new_drag_drop_controller()
	add_child_autofree(controller)
	var source_parent: Control = Control.new()
	var source: Control = Control.new()
	var source_child: Control = Control.new()
	add_child_autofree(source_parent)
	source_parent.add_child(source)
	source.add_child(source_child)
	await get_tree().process_frame

	var session_id: int = GFVariantData.to_int(controller.call(
		"start_drag",
		&"ui",
		null,
		Vector2.ZERO,
		source,
		{ "drag_parent": source_child }
	))

	assert_eq(session_id, -1, "source 子孙不能作为 drag_parent。")
	assert_eq(source.get_parent(), source_parent, "非法拓扑不得改变 source 父级。")
	assert_false(GFVariantData.to_bool(controller.call("has_active_drag")), "非法拓扑不得创建会话。")


## 验证正常终态会断开 source 生命周期监听，重复会话不会累积回调。
func test_controller_disconnects_source_lifetime_listener_after_each_session() -> void:
	var controller: Node = _new_drag_drop_controller()
	add_child_autofree(controller)
	var source: Control = Control.new()
	add_child_autofree(source)
	await get_tree().process_frame

	for iteration: int in range(3):
		var session_id: int = GFVariantData.to_int(controller.call("start_drag", &"ui", null, Vector2.ZERO, source))
		assert_gt(session_id, 0, "每轮拖拽都应成功启动。")
		assert_eq(source.tree_exited.get_connections().size(), 1, "活动会话只应有一个 source 生命周期监听。")
		var result: Dictionary = GFVariantData.to_dictionary(controller.call("drop", Vector2(500.0, 500.0)))
		assert_false(GFVariantData.get_option_bool(result, "ok", true), "无落点释放应结束本轮会话。")
		assert_eq(source.tree_exited.get_connections().size(), 0, "会话终态必须断开 source 生命周期监听。")
		assert_false(GFVariantData.to_bool(controller.call("has_active_drag")), "会话终态后不得保留活动拖拽。")


## 验证控制器会随指针更新报告当前最佳落点。
func test_controller_drag_moved_reports_best_zone() -> void:
	var controller: Node = _new_drag_drop_controller()
	add_child_autofree(controller)
	watch_signals(controller)
	var _low_zone: Variant = controller.call(
		"register_rect_zone",
		&"low",
		Rect2(Vector2.ZERO, Vector2(100.0, 100.0)),
		PackedStringArray(["item"]),
		{ "priority": 1 }
	)
	var _high_zone: Variant = controller.call(
		"register_rect_zone",
		&"high",
		Rect2(Vector2.ZERO, Vector2(100.0, 100.0)),
		PackedStringArray(["item"]),
		{ "priority": 5 }
	)

	var session_id: int = GFVariantData.to_int(controller.call("start_drag", &"item", null, Vector2.ZERO))
	assert_true(GFVariantData.to_bool(controller.call("update_pointer", Vector2(10.0, 10.0))), "控制器应能更新指针位置。")

	assert_signal_emit_count(controller, "drag_moved", 1, "更新指针应发出移动信号。")
	var moved_parameters: Array = get_signal_parameters(controller, "drag_moved")
	assert_eq(GFVariantData.to_int(moved_parameters[0]), session_id, "移动信号应包含会话 ID。")
	assert_eq(GFVariantData.to_string_name(moved_parameters[3]), &"high", "移动信号应报告最高优先级落点。")


func _new_drag_drop_controller() -> Node:
	var controller: Node = _GF_DRAG_DROP_CONTROLLER_SCRIPT.new()
	return controller
