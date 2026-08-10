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


## 验证循环 metadata 会被安全复制，并在 JSON 快照中转成循环标记。
func test_debug_snapshot_handles_cyclic_metadata_without_raw_fallback() -> void:
	var cyclic_metadata: Dictionary = {
		"not_a_number": NAN,
		"resource": Resource.new(),
	}
	cyclic_metadata["self"] = cyclic_metadata
	var utility: GFDragDropUtility = GFDragDropUtility.new()
	var _zone: GFDropZone = utility.register_rect_zone(
		&"slot",
		Rect2(Vector2.ZERO, Vector2.ONE),
		PackedStringArray(["item"]),
		{ "metadata": cyclic_metadata }
	)
	var session_id: int = utility.start_drag(
		&"item",
		null,
		Vector2.ZERO,
		null,
		cyclic_metadata
	)

	var stored_session: GFDragSession = utility.get_session(session_id)
	var raw_snapshot: Dictionary = stored_session.to_dictionary(false)
	var copied_metadata: Dictionary = GFVariantData.as_dictionary(
		GFVariantData.get_option_value(raw_snapshot, "metadata")
	)
	assert_false(is_same(copied_metadata, cyclic_metadata), "会话必须取得独立 metadata 图。")
	assert_true(
		is_same(GFVariantData.get_option_value(copied_metadata, "self"), copied_metadata),
		"安全复制必须保留循环图结构，不能递归溢出。"
	)

	var json_text: String = JSON.stringify(utility.get_debug_snapshot(true))
	assert_true(json_text.contains("CircularReference"), "循环 metadata 必须转成 JSON-safe typed marker。")
	assert_true(json_text.contains("\"Float\""), "非有限浮点必须转成 JSON-safe typed marker。")
	assert_false(json_text.contains("Resource#"), "不支持的 Resource 不得以对象身份字符串泄漏。")

	var controller: Node = _new_drag_drop_controller()
	add_child_autofree(controller)
	var controller_session_id: int = GFVariantData.to_int(controller.call(
		"start_drag",
		&"item",
		null,
		Vector2.ZERO,
		null,
		{ "metadata": cyclic_metadata }
	))
	assert_gt(controller_session_id, 0, "控制器必须接受可安全复制的循环 metadata。")
	var controller_json: String = JSON.stringify(controller.call("get_debug_snapshot", true))
	assert_true(controller_json.contains("CircularReference"), "控制器二次快照也必须保持 JSON-safe 循环标记。")
	var controller_session: GFDragSession = controller.call("get_active_session")
	assert_not_null(controller_session, "控制器活动会话应可用于测试夹具清理。")

	# 测试有意构造五份带 Resource 的自引用字典；行为断言完成后逐一断环，
	# 避免测试夹具把 Resource 保留到 ObjectDB 退出阶段。
	cyclic_metadata.clear()
	_zone.metadata.clear()
	stored_session.metadata.clear()
	copied_metadata.clear()
	controller_session.metadata.clear()
	var _utility_cancelled: bool = utility.cancel_drag(session_id)
	utility.clear_zones()
	var _controller_cancelled: bool = GFVariantData.to_bool(controller.call("cancel_drag", &"cleanup"))


## 验证超深 metadata 在 codec 预算处返回顶层 TraversalLimit，而不是 raw 值。
func test_debug_snapshot_bounds_deep_metadata_before_json_output() -> void:
	var deep_metadata: Dictionary = {}
	var cursor: Dictionary = deep_metadata
	for depth: int in range(80):
		var next_level: Dictionary = { "depth": depth }
		cursor["next"] = next_level
		cursor = next_level
	var session: GFDragSession = GFDragSession.new()
	session.setup(1, &"item", null, Vector2.ZERO, null, deep_metadata)

	var json_snapshot: Dictionary = session.to_dictionary(true)
	var json_text: String = JSON.stringify(json_snapshot)

	assert_true(json_text.contains("TraversalLimit"), "超深 metadata 必须由 traversal budget 截断。")
	assert_true(json_text.contains("max_depth"), "截断结果必须包含可诊断的预算原因。")


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


## 验证替换回调中的新注册拥有后续 key，outer 注册不能覆盖它。
func test_register_zone_reentry_preserves_callback_registration() -> void:
	var utility: GFDragDropUtility = GFDragDropUtility.new()
	var first_zone: GFDropZone = GFDropZone.from_rect(&"slot", Rect2(Vector2.ZERO, Vector2.ONE))
	var outer_zone: GFDropZone = GFDropZone.from_rect(&"slot", Rect2(Vector2.ZERO, Vector2(2.0, 2.0)))
	var callback_zone: GFDropZone = GFDropZone.from_rect(&"slot", Rect2(Vector2.ZERO, Vector2(3.0, 3.0)))
	assert_true(utility.register_zone(first_zone), "测试前置落点必须注册成功。")
	var unregister_callback: Callable = func(zone_id: StringName) -> void:
		if zone_id == &"slot":
			var _registered_callback_zone: bool = utility.register_zone(callback_zone)
	var _reentry_connected: Error = utility.drop_zone_unregistered.connect(unregister_callback) as Error

	assert_false(utility.register_zone(outer_zone), "outer 注册失去 key 后必须报告失败。")
	assert_eq(utility.get_zone(&"slot"), callback_zone, "同步回调取得的注册不得被 outer 操作覆盖。")
	utility.drop_zone_unregistered.disconnect(unregister_callback)


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


## 验证捕获模式不能把 inactive sentinel 当成活动 pointer。
func test_controller_rejects_inactive_pointer_sentinel() -> void:
	var controller: Node = _new_drag_drop_controller()
	add_child_autofree(controller)

	var session_id: int = GFVariantData.to_int(controller.call(
		"start_drag",
		&"item",
		null,
		Vector2.ZERO,
		null,
		{
			"capture_pointer": true,
			"pointer_id": -1,
		}
	))

	assert_eq(session_id, -1, "inactive sentinel 不得成为控制器捕获 ID。")
	assert_false(GFVariantData.to_bool(controller.call("has_active_drag")), "拒绝 sentinel 后不得创建会话。")
	var snapshot: Dictionary = GFVariantData.to_dictionary(controller.call("get_debug_snapshot"))
	assert_false(
		GFVariantData.get_option_bool(GFVariantData.get_option_dictionary(snapshot, "pointer_capture"), "active"),
		"拒绝 sentinel 后 pointer capture 必须保持 inactive。"
	)


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


## 验证候选回调取消会话后，controller 不在终态之后继续发布 moved。
func test_controller_does_not_emit_moved_after_candidate_callback_cancels() -> void:
	var controller: Node = _new_drag_drop_controller()
	add_child_autofree(controller)
	watch_signals(controller)
	var utility: GFDragDropUtility = controller.call("get_utility")
	var _zone: Variant = controller.call(
		"register_rect_zone",
		&"slot",
		Rect2(Vector2.ZERO, Vector2(100.0, 100.0)),
		PackedStringArray(["item"]),
		{
			"can_accept": func(session: GFDragSession, _drop_zone: GFDropZone) -> bool:
				var _cancelled: bool = utility.cancel_drag(session.session_id)
				return true,
		}
	)
	var session_id: int = GFVariantData.to_int(controller.call(
		"start_drag",
		&"item",
		null,
		Vector2.ZERO
	))
	assert_gt(session_id, 0, "测试前置会话必须启动成功。")

	var _updated: bool = GFVariantData.to_bool(controller.call(
		"update_pointer",
		Vector2.ONE
	))

	assert_false(GFVariantData.to_bool(controller.call("has_active_drag")), "候选回调应已取消会话。")
	assert_signal_emit_count(controller, "drag_cancelled", 1, "取消终态只应发布一次。")
	assert_signal_not_emitted(controller, "drag_moved", "取消终态之后不得再发布旧会话 moved。")
	utility.clear_zones()


## 验证 started 回调取消同一 Utility 会话时，控制器完整回滚开始事务。
func test_controller_started_reentry_cancel_rolls_back_start_transaction() -> void:
	var controller: Node = _new_drag_drop_controller()
	add_child_autofree(controller)
	var source_parent: Control = Control.new()
	var drag_parent: Control = Control.new()
	var source: Control = Control.new()
	add_child_autofree(source_parent)
	add_child_autofree(drag_parent)
	source_parent.add_child(source)
	await get_tree().process_frame

	var callback_state: Dictionary = {
		"cancel_first": true,
		"started": 0,
		"cancelled": 0,
	}
	var _started_connected: Error = controller.connect("drag_started", func(started_session_id: int, _drag_type: StringName) -> void:
		callback_state["started"] = GFVariantData.get_option_int(callback_state, "started") + 1
		if GFVariantData.get_option_bool(callback_state, "cancel_first"):
			callback_state["cancel_first"] = false
			var utility: GFDragDropUtility = controller.call("get_utility")
			var _cancelled: bool = utility.cancel_drag(started_session_id)
	)
	var _cancelled_connected: Error = controller.connect("drag_cancelled", func(_session_id: int, _reason: StringName) -> void:
		callback_state["cancelled"] = GFVariantData.get_option_int(callback_state, "cancelled") + 1
	)

	var session_id: int = GFVariantData.to_int(controller.call(
		"start_drag",
		&"ui",
		null,
		Vector2.ZERO,
		source,
		{ "drag_parent": drag_parent }
	))

	assert_eq(session_id, -1, "started 回调内取消后，外层 start 不得返回失效会话 ID。")
	assert_eq(source.get_parent(), source_parent, "取消开始事务必须恢复 source 原父级。")
	assert_false(GFVariantData.to_bool(controller.call("has_active_drag")), "控制器不得保留幽灵活动 ID。")
	assert_eq(source.tree_exited.get_connections().size(), 0, "回滚后不得留下 source 生命周期监听。")
	var snapshot: Dictionary = GFVariantData.to_dictionary(controller.call("get_debug_snapshot"))
	assert_false(
		GFVariantData.get_option_bool(GFVariantData.get_option_dictionary(snapshot, "pointer_capture"), "active"),
		"回滚后必须释放 pointer capture。"
	)
	assert_eq(GFVariantData.get_option_int(callback_state, "started"), 1, "已提交后发布的 started 只应出现一次。")
	assert_eq(GFVariantData.get_option_int(callback_state, "cancelled"), 1, "已宣布的会话应有且仅有一次取消终态。")

	var next_session_id: int = GFVariantData.to_int(controller.call(
		"start_drag",
		&"ui",
		null,
		Vector2.ZERO,
		source
	))
	assert_gt(next_session_id, 0, "回滚后控制器应能立即开始下一会话。")
	var _next_cancelled: bool = GFVariantData.to_bool(controller.call("cancel_drag", &"cleanup"))


## 验证 Utility 的 pre-commit started 回调取消时，控制器不发布半提交生命周期。
func test_controller_utility_started_cancel_rolls_back_before_public_start() -> void:
	var controller: Node = _new_drag_drop_controller()
	add_child_autofree(controller)
	watch_signals(controller)
	var source_parent: Control = Control.new()
	var drag_parent: Control = Control.new()
	var source: Control = Control.new()
	add_child_autofree(source_parent)
	add_child_autofree(drag_parent)
	source_parent.add_child(source)
	await get_tree().process_frame
	var utility: GFDragDropUtility = controller.call("get_utility")
	var started_callback: Callable = func(started_session_id: int, drag_type: StringName) -> void:
		if drag_type == &"precommit":
			var _cancelled: bool = utility.cancel_drag(started_session_id)
	var _precommit_cancel_connected: Error = utility.drag_started.connect(started_callback) as Error

	var session_id: int = GFVariantData.to_int(controller.call(
		"start_drag",
		&"precommit",
		null,
		Vector2.ZERO,
		source,
		{ "drag_parent": drag_parent }
	))

	assert_eq(session_id, -1, "pre-commit Utility 取消后 controller start 必须失败。")
	assert_eq(source.get_parent(), source_parent, "失败事务必须恢复 source 原父级。")
	assert_eq(source.tree_exited.get_connections().size(), 0, "失败事务不得留下 source 监听。")
	assert_signal_not_emitted(controller, "drag_started", "未提交会话不得发布 controller started。")
	assert_signal_not_emitted(controller, "drag_cancelled", "未曾公开的会话不得发布 controller terminal。")
	utility.drag_started.disconnect(started_callback)


## 验证 cancel 终态先释放旧 lease，再允许 signal 回调开始下一会话。
func test_controller_cancel_signal_can_start_next_after_old_cleanup() -> void:
	var controller: Node = _new_drag_drop_controller()
	add_child_autofree(controller)
	var source_parent: Control = Control.new()
	var drag_parent: Control = Control.new()
	var old_source: Control = Control.new()
	var next_source: Control = Control.new()
	add_child_autofree(source_parent)
	add_child_autofree(drag_parent)
	source_parent.add_child(old_source)
	source_parent.add_child(next_source)
	await get_tree().process_frame

	var callback_state: Dictionary = {
		"old_session_id": -1,
		"next_session_id": -1,
	}
	var _cancel_next_connected: Error = controller.connect("drag_cancelled", func(session_id: int, _reason: StringName) -> void:
		if session_id != GFVariantData.get_option_int(callback_state, "old_session_id"):
			return
		callback_state["next_session_id"] = GFVariantData.to_int(controller.call(
			"start_drag",
			&"next",
			null,
			Vector2.ONE,
			next_source
		))
	)

	var old_session_id: int = GFVariantData.to_int(controller.call(
		"start_drag",
		&"old",
		null,
		Vector2.ZERO,
		old_source,
		{ "drag_parent": drag_parent }
	))
	callback_state["old_session_id"] = old_session_id
	assert_true(GFVariantData.to_bool(controller.call("cancel_drag", &"next_requested")), "旧会话应成功取消。")

	var next_session_id: int = GFVariantData.get_option_int(callback_state, "next_session_id", -1)
	assert_gt(next_session_id, 0, "取消信号回调应能开始下一会话。")
	assert_eq(old_source.get_parent(), source_parent, "发布取消信号前应恢复旧 source。")
	assert_eq(old_source.tree_exited.get_connections().size(), 0, "旧 source 监听必须先断开。")
	assert_eq(GFVariantData.to_int(controller.call("get_active_session_id")), next_session_id, "旧 finish 不得清理新会话。")
	assert_true(GFVariantData.to_bool(controller.call("has_active_drag")), "新会话应持续有效。")
	var _next_cancelled: bool = GFVariantData.to_bool(controller.call("cancel_drag", &"cleanup"))


## 验证 dropped 终态先释放旧 lease，再允许 signal 回调开始下一会话。
func test_controller_dropped_signal_can_start_next_after_old_cleanup() -> void:
	var controller: Node = _new_drag_drop_controller()
	add_child_autofree(controller)
	var _zone: Variant = controller.call(
		"register_rect_zone",
		&"slot",
		Rect2(Vector2.ZERO, Vector2(100.0, 100.0)),
		PackedStringArray(["old"])
	)
	var source_parent: Control = Control.new()
	var drag_parent: Control = Control.new()
	var old_source: Control = Control.new()
	var next_source: Control = Control.new()
	add_child_autofree(source_parent)
	add_child_autofree(drag_parent)
	source_parent.add_child(old_source)
	source_parent.add_child(next_source)
	await get_tree().process_frame

	var callback_state: Dictionary = {
		"old_session_id": -1,
		"next_session_id": -1,
	}
	var _dropped_next_connected: Error = controller.connect("drag_dropped", func(session_id: int, _zone_id: StringName, _result: Dictionary) -> void:
		if session_id != GFVariantData.get_option_int(callback_state, "old_session_id"):
			return
		callback_state["next_session_id"] = GFVariantData.to_int(controller.call(
			"start_drag",
			&"next",
			null,
			Vector2.ONE,
			next_source
		))
	)

	var old_session_id: int = GFVariantData.to_int(controller.call(
		"start_drag",
		&"old",
		null,
		Vector2.ZERO,
		old_source,
		{
			"drag_parent": drag_parent,
			"restore_source_parent_on_success": true,
		}
	))
	callback_state["old_session_id"] = old_session_id
	var result: Dictionary = GFVariantData.to_dictionary(controller.call("drop", Vector2(10.0, 10.0)))

	assert_true(GFVariantData.get_option_bool(result, "ok"), "旧会话应成功 drop。")
	var next_session_id: int = GFVariantData.get_option_int(callback_state, "next_session_id", -1)
	assert_gt(next_session_id, 0, "dropped 回调应能开始下一会话。")
	assert_eq(old_source.get_parent(), source_parent, "发布 dropped 前应按成功选项恢复旧 source。")
	assert_eq(old_source.tree_exited.get_connections().size(), 0, "旧 source 监听必须先断开。")
	assert_eq(GFVariantData.to_int(controller.call("get_active_session_id")), next_session_id, "旧 dropped handler 不得清理新会话。")
	var _next_cancelled: bool = GFVariantData.to_bool(controller.call("cancel_drag", &"cleanup"))


## 验证 terminal reject 先释放旧 lease，再允许 signal 回调开始下一会话。
func test_controller_terminal_reject_signal_can_start_next_after_old_cleanup() -> void:
	var controller: Node = _new_drag_drop_controller()
	add_child_autofree(controller)
	var source_parent: Control = Control.new()
	var drag_parent: Control = Control.new()
	var old_source: Control = Control.new()
	var next_source: Control = Control.new()
	add_child_autofree(source_parent)
	add_child_autofree(drag_parent)
	source_parent.add_child(old_source)
	source_parent.add_child(next_source)
	await get_tree().process_frame

	var callback_state: Dictionary = {
		"old_session_id": -1,
		"next_session_id": -1,
	}
	var _rejected_next_connected: Error = controller.connect("drag_drop_rejected", func(session_id: int, _reason: StringName) -> void:
		if session_id != GFVariantData.get_option_int(callback_state, "old_session_id"):
			return
		callback_state["next_session_id"] = GFVariantData.to_int(controller.call(
			"start_drag",
			&"next",
			null,
			Vector2.ONE,
			next_source
		))
	)

	var old_session_id: int = GFVariantData.to_int(controller.call(
		"start_drag",
		&"old",
		null,
		Vector2.ZERO,
		old_source,
		{ "drag_parent": drag_parent }
	))
	callback_state["old_session_id"] = old_session_id
	var result: Dictionary = GFVariantData.to_dictionary(controller.call("drop", Vector2(500.0, 500.0)))

	assert_false(GFVariantData.get_option_bool(result, "ok", true), "无落点应产生 terminal reject。")
	var next_session_id: int = GFVariantData.get_option_int(callback_state, "next_session_id", -1)
	assert_gt(next_session_id, 0, "terminal reject 回调应能开始下一会话。")
	assert_eq(old_source.get_parent(), source_parent, "发布 reject 前应恢复旧 source。")
	assert_eq(old_source.tree_exited.get_connections().size(), 0, "旧 source 监听必须先断开。")
	assert_eq(GFVariantData.to_int(controller.call("get_active_session_id")), next_session_id, "旧 reject handler 不得清理新会话。")
	var _next_cancelled: bool = GFVariantData.to_bool(controller.call("cancel_drag", &"cleanup"))


## 验证 drop Callable 内取消同一会话不能再提交 dropped 终态。
func test_drop_callback_cancel_cannot_commit_second_terminal() -> void:
	var utility: GFDragDropUtility = GFDragDropUtility.new()
	var counts: Dictionary = {
		"cancelled": 0,
		"dropped": 0,
	}
	var _cancel_count_connected: Error = utility.drag_cancelled.connect(func(_session_id: int) -> void:
		counts["cancelled"] = GFVariantData.get_option_int(counts, "cancelled") + 1
	) as Error
	var _drop_count_connected: Error = utility.drag_dropped.connect(func(_session_id: int, _zone_id: StringName, _result: Dictionary) -> void:
		counts["dropped"] = GFVariantData.get_option_int(counts, "dropped") + 1
	) as Error
	var _zone: GFDropZone = utility.register_rect_zone(
		&"slot",
		Rect2(Vector2.ZERO, Vector2(100.0, 100.0)),
		PackedStringArray(["item"]),
		{
			"drop": func(session: GFDragSession, _drop_zone: GFDropZone, _position: Variant) -> Dictionary:
				var _cancelled: bool = utility.cancel_drag(session.session_id)
				return { "ok": true },
		}
	)
	var session_id: int = utility.start_drag(&"item", null, Vector2.ZERO)

	var result: Dictionary = utility.drop(session_id, Vector2.ONE)

	assert_false(GFVariantData.get_option_bool(result, "ok", true), "callback 取消获胜后外层 drop 必须失败闭合。")
	assert_eq(GFVariantData.get_option_string_name(result, "reason"), &"session_cancelled", "返回值必须解释终态已由取消提交。")
	assert_eq(GFVariantData.get_option_int(counts, "cancelled"), 1, "会话只应有一次取消终态。")
	assert_eq(GFVariantData.get_option_int(counts, "dropped"), 0, "取消后不得再发 dropped。")
	utility.clear_zones()


## 验证候选 Callable 内取消同一会话后，outer drop 不再继续到 drop callback。
func test_can_accept_callback_cancel_stops_outer_drop() -> void:
	var utility: GFDragDropUtility = GFDragDropUtility.new()
	var counts: Dictionary = {
		"cancelled": 0,
		"dropped": 0,
		"drop_calls": 0,
	}
	var _candidate_cancel_connected: Error = utility.drag_cancelled.connect(func(_session_id: int) -> void:
		counts["cancelled"] = GFVariantData.get_option_int(counts, "cancelled") + 1
	) as Error
	var _candidate_drop_connected: Error = utility.drag_dropped.connect(func(_session_id: int, _zone_id: StringName, _result: Dictionary) -> void:
		counts["dropped"] = GFVariantData.get_option_int(counts, "dropped") + 1
	) as Error
	var _zone: GFDropZone = utility.register_rect_zone(
		&"slot",
		Rect2(Vector2.ZERO, Vector2(100.0, 100.0)),
		PackedStringArray(["item"]),
		{
			"can_accept": func(session: GFDragSession, _drop_zone: GFDropZone) -> bool:
				var _cancelled: bool = utility.cancel_drag(session.session_id)
				return true,
			"drop": func(_session: GFDragSession, _drop_zone: GFDropZone, _position: Variant) -> Dictionary:
				counts["drop_calls"] = GFVariantData.get_option_int(counts, "drop_calls") + 1
				return { "ok": true },
		}
	)
	var session_id: int = utility.start_drag(&"item", null, Vector2.ZERO)

	var result: Dictionary = utility.drop(session_id, Vector2.ONE)

	assert_false(GFVariantData.get_option_bool(result, "ok", true), "候选计算期间取消后 outer drop 必须失败闭合。")
	assert_eq(GFVariantData.get_option_string_name(result, "reason"), &"session_cancelled", "取消原因必须稳定。")
	assert_eq(GFVariantData.get_option_int(counts, "cancelled"), 1, "候选回调取消只应发布一次终态。")
	assert_eq(GFVariantData.get_option_int(counts, "dropped"), 0, "取消后不得发布 dropped。")
	assert_eq(GFVariantData.get_option_int(counts, "drop_calls"), 0, "取消后不得继续调用 drop callback。")
	utility.clear_zones()


## 验证公开候选查询在项目回调取消会话后立即停止使用旧 session。
func test_candidate_queries_stop_after_callback_cancels_session() -> void:
	var utility: GFDragDropUtility = GFDragDropUtility.new()
	var _zone: GFDropZone = utility.register_rect_zone(
		&"slot",
		Rect2(Vector2.ZERO, Vector2(100.0, 100.0)),
		PackedStringArray(["item"]),
		{
			"can_accept": func(session: GFDragSession, _drop_zone: GFDropZone) -> bool:
				var _cancelled: bool = utility.cancel_drag(session.session_id)
				return true,
		}
	)

	var list_session_id: int = utility.start_drag(&"item", null, Vector2.ZERO)
	var candidates: Array[GFDropZone] = utility.get_drop_candidates(
		list_session_id,
		Vector2.ONE
	)
	assert_eq(candidates, [], "session 在 callback 中结束后，候选列表必须失败关闭为空。")

	var best_session_id: int = utility.start_drag(&"item", null, Vector2.ZERO)
	var best_zone: GFDropZone = utility.get_best_drop_zone(best_session_id, Vector2.ONE)
	assert_null(best_zone, "session 在 callback 中结束后，最佳落点必须失败关闭为空。")
	assert_false(utility.has_active_session(list_session_id), "列表查询中的 callback 应已取消旧会话。")
	assert_false(utility.has_active_session(best_session_id), "最佳查询中的 callback 应已取消旧会话。")
	utility.clear_zones()


## 验证候选回调注销自身后，outer drop 不会调用已失去 authority 的落点。
func test_can_accept_unregistering_zone_rejects_before_drop_callback() -> void:
	var utility: GFDragDropUtility = GFDragDropUtility.new()
	var state: Dictionary = { "drop_calls": 0 }
	var _zone: GFDropZone = utility.register_rect_zone(
		&"slot",
		Rect2(Vector2.ZERO, Vector2(100.0, 100.0)),
		PackedStringArray(["item"]),
		{
			"can_accept": func(_session: GFDragSession, _drop_zone: GFDropZone) -> bool:
				var _unregistered: bool = utility.unregister_zone(&"slot")
				return true,
			"drop": func(_session: GFDragSession, _drop_zone: GFDropZone, _position: Variant) -> Dictionary:
				state["drop_calls"] = GFVariantData.get_option_int(state, "drop_calls") + 1
				return { "ok": true },
		}
	)
	var session_id: int = utility.start_drag(&"item", null, Vector2.ZERO)

	var result: Dictionary = utility.drop(session_id, Vector2.ONE)

	assert_false(GFVariantData.get_option_bool(result, "ok", true), "注销后的候选不得提交 drop。")
	assert_eq(GFVariantData.get_option_string_name(result, "reason"), &"drop_zone_changed", "authority 变化必须有稳定原因。")
	assert_eq(GFVariantData.get_option_int(state, "drop_calls"), 0, "失去注册 authority 后不得调用业务 drop callback。")
	assert_true(utility.has_active_session(session_id), "落点变化是可重试拒绝，不应静默终止会话。")
	var _cancelled: bool = utility.cancel_drag(session_id)


## 验证递归 drop 被 resolving guard 拒绝，但外层仍可提交单一成功终态。
func test_recursive_drop_is_rejected_without_double_terminal() -> void:
	var utility: GFDragDropUtility = GFDragDropUtility.new()
	var state: Dictionary = {
		"calls": 0,
		"dropped": 0,
		"inner_result": {},
	}
	var _recursive_drop_connected: Error = utility.drag_dropped.connect(func(_session_id: int, _zone_id: StringName, _result: Dictionary) -> void:
		state["dropped"] = GFVariantData.get_option_int(state, "dropped") + 1
	) as Error
	var _zone: GFDropZone = utility.register_rect_zone(
		&"slot",
		Rect2(Vector2.ZERO, Vector2(100.0, 100.0)),
		PackedStringArray(["item"]),
		{
			"drop": func(session: GFDragSession, _drop_zone: GFDropZone, position: Variant) -> Dictionary:
				state["calls"] = GFVariantData.get_option_int(state, "calls") + 1
				if GFVariantData.get_option_int(state, "calls") == 1:
					var recursive_position: Vector2 = GFVariantData.to_vector2(position)
					state["inner_result"] = utility.drop(session.session_id, recursive_position)
				return { "ok": true },
		}
	)
	var session_id: int = utility.start_drag(&"item", null, Vector2.ZERO)

	var result: Dictionary = utility.drop(session_id, Vector2.ONE)
	var inner_result: Dictionary = GFVariantData.get_option_dictionary(state, "inner_result")

	assert_true(GFVariantData.get_option_bool(result, "ok"), "外层 drop 可继续提交成功。")
	assert_false(GFVariantData.get_option_bool(inner_result, "ok", true), "递归 drop 必须被拒绝。")
	assert_eq(GFVariantData.get_option_string_name(inner_result, "reason"), &"session_resolving", "递归拒绝原因必须稳定。")
	assert_eq(GFVariantData.get_option_int(state, "calls"), 1, "resolving guard 必须阻止第二次 callback。")
	assert_eq(GFVariantData.get_option_int(state, "dropped"), 1, "同一会话只能发布一次 dropped。")
	utility.clear_zones()


## 验证 clear_sessions 只清理开始时的快照，不吞掉回调新建会话。
func test_clear_sessions_preserves_session_created_by_cancel_callback() -> void:
	var utility: GFDragDropUtility = GFDragDropUtility.new()
	var old_session_id: int = utility.start_drag(&"old", null, Vector2.ZERO)
	var callback_state: Dictionary = { "next_session_id": -1 }
	var cancelled_callback: Callable = func(session_id: int) -> void:
		if session_id == old_session_id:
			callback_state["next_session_id"] = utility.start_drag(&"next", null, Vector2.ONE)
	var _clear_sessions_connected: Error = utility.drag_cancelled.connect(cancelled_callback) as Error

	utility.clear_sessions()

	var next_session_id: int = GFVariantData.get_option_int(callback_state, "next_session_id", -1)
	assert_false(utility.has_active_session(old_session_id), "clear 开始时的旧会话必须被取消。")
	assert_gt(next_session_id, 0, "取消回调应能建立下一会话。")
	assert_true(utility.has_active_session(next_session_id), "回调新建会话不得被 outer clear 静默删除。")
	var _cancelled: bool = utility.cancel_drag(next_session_id)
	utility.drag_cancelled.disconnect(cancelled_callback)


## 验证 clear_zones 只清理开始时的快照，不吞掉回调新注册落点。
func test_clear_zones_preserves_zone_registered_by_unregister_callback() -> void:
	var utility: GFDragDropUtility = GFDragDropUtility.new()
	var _old_zone: GFDropZone = utility.register_rect_zone(&"old", Rect2(Vector2.ZERO, Vector2.ONE))
	var unregistered_callback: Callable = func(zone_id: StringName) -> void:
		if zone_id == &"old":
			var _next_zone: GFDropZone = utility.register_rect_zone(
				&"next",
				Rect2(Vector2.ZERO, Vector2(2.0, 2.0))
			)
	var _clear_zones_connected: Error = utility.drop_zone_unregistered.connect(unregistered_callback) as Error

	utility.clear_zones()

	assert_null(utility.get_zone(&"old"), "clear 开始时的旧落点必须被移除。")
	assert_not_null(utility.get_zone(&"next"), "回调新注册落点不得被 outer clear 静默删除。")
	utility.drop_zone_unregistered.disconnect(unregistered_callback)


## 验证仍有效但 parentless 的 source 可在自动取消中恢复。
func test_controller_restores_parentless_source_on_cancel() -> void:
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
		{ "drag_parent": drag_parent }
	))
	assert_gt(session_id, 0, "测试前置拖拽必须成功。")

	drag_parent.remove_child(source)
	await get_tree().process_frame

	assert_eq(source.get_parent(), source_parent, "有效 parentless source 应恢复到原父级。")
	assert_false(GFVariantData.to_bool(controller.call("has_active_drag")), "source 离树后会话必须取消。")
	assert_eq(source.tree_exited.get_connections().size(), 0, "自动取消后不得保留 source 监听。")
	if source.get_parent() == null:
		source_parent.add_child(source)


## 验证 original parent 已释放时，取消会安全闭合且不遗留监听。
func test_controller_cancel_skips_invalid_original_parent_without_leak() -> void:
	var controller: Node = _new_drag_drop_controller()
	add_child_autofree(controller)
	var source_parent: Control = Control.new()
	var drag_parent: Control = Control.new()
	var source: Control = Control.new()
	add_child(source_parent)
	add_child_autofree(drag_parent)
	source_parent.add_child(source)
	await get_tree().process_frame

	var session_id: int = GFVariantData.to_int(controller.call(
		"start_drag",
		&"ui",
		null,
		Vector2.ZERO,
		source,
		{ "drag_parent": drag_parent }
	))
	assert_gt(session_id, 0, "测试前置拖拽必须成功。")
	source_parent.queue_free()
	await get_tree().process_frame

	assert_true(GFVariantData.to_bool(controller.call("cancel_drag", &"original_parent_freed")), "原父级失效不应阻止会话取消。")
	assert_false(GFVariantData.to_bool(controller.call("has_active_drag")), "取消后控制器必须 idle。")
	assert_eq(source.tree_exited.get_connections().size(), 0, "无法恢复 parent 时仍必须断开 source 监听。")
	assert_eq(source.get_parent(), drag_parent, "原父级失效时不得执行非法 reparent。")


func _new_drag_drop_controller() -> Node:
	var controller: Node = _GF_DRAG_DROP_CONTROLLER_SCRIPT.new()
	return controller
