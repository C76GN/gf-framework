## 测试通用拖拽会话与落点匹配工具。
extends GutTest


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
