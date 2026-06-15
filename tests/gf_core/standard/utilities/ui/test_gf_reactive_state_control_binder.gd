## 测试 GFReactiveStateControlBinder 的 Control 与状态路径双向绑定。
extends GutTest


# --- 常量 ---

const GFReactiveStateControlBinderBase = preload("res://addons/gf/standard/utilities/ui/gf_reactive_state_control_binder.gd")
const GFReactiveStateStoreBase = preload("res://addons/gf/standard/utilities/state/gf_reactive_state_store.gd")


# --- 私有变量 ---

var _controls: Array[Control] = []


# --- Godot 生命周期方法 ---

func after_each() -> void:
	for control: Control in _controls:
		if is_instance_valid(control):
			control.free()
	_controls.clear()


# --- 测试方法 ---

func test_bind_control_syncs_store_value_to_control() -> void:
	var store: GFReactiveStateStoreBase = GFReactiveStateStoreBase.new({
		"profile": {
			"name": "Ada",
		},
	})
	var binder: GFReactiveStateControlBinderBase = GFReactiveStateControlBinderBase.new()
	var line_edit: LineEdit = LineEdit.new()
	_track_control(line_edit)

	assert_true(binder.bind_control(store, "profile.name", line_edit), "绑定有效 store 和 control 应成功。")

	assert_eq(line_edit.text, "Ada", "初始同步应把 store 值写入控件。")


func test_bind_control_rejects_invalid_store_and_control() -> void:
	var store: GFReactiveStateStoreBase = GFReactiveStateStoreBase.new({})
	var invalid_store: RefCounted = RefCounted.new()
	var binder: GFReactiveStateControlBinderBase = GFReactiveStateControlBinderBase.new()
	var line_edit: LineEdit = LineEdit.new()
	var null_control: Control = null
	_track_control(line_edit)

	assert_false(binder.bind_control(invalid_store, "profile.name", line_edit), "非 GFReactiveStateStore 不应被绑定。")
	assert_push_error("[GFReactiveStateControlBinder] bind_control 失败：store 必须是 GFReactiveStateStore。")
	assert_false(binder.bind_control(store, "profile.name", null_control), "无效 Control 不应被绑定。")
	assert_push_error("[GFReactiveStateControlBinder] bind_control 失败：control 无效。")
	assert_eq(binder.get_binding_count(), 0, "无效绑定不应留下记录。")


func test_control_signal_updates_store_path() -> void:
	var store: GFReactiveStateStoreBase = GFReactiveStateStoreBase.new({
		"profile": {
			"name": "Ada",
		},
	})
	var binder: GFReactiveStateControlBinderBase = GFReactiveStateControlBinderBase.new()
	var line_edit: LineEdit = LineEdit.new()
	_track_control(line_edit)
	var _bind_result: Variant = binder.bind_control(store, "profile.name", line_edit)

	line_edit.text = "Grace"
	line_edit.text_changed.emit("Grace")

	assert_eq(GFVariantData.to_text(store.get_value("profile.name")), "Grace", "控件值变化应写回 store。")


func test_rebinding_same_control_replaces_previous_path_subscription() -> void:
	var store: GFReactiveStateStoreBase = GFReactiveStateStoreBase.new({
		"profile": {
			"first": "Ada",
			"last": "Lovelace",
		},
	})
	var binder: GFReactiveStateControlBinderBase = GFReactiveStateControlBinderBase.new()
	var line_edit: LineEdit = LineEdit.new()
	_track_control(line_edit)

	var _first_bind_result: Variant = binder.bind_control(store, "profile.first", line_edit)
	var _second_bind_result: Variant = binder.bind_control(store, "profile.last", line_edit)
	var _old_path_result: Variant = store.set_value("profile.first", "Grace")
	var _new_path_result: Variant = store.set_value("profile.last", "Byron")

	assert_eq(binder.get_binding_count(), 1, "同一 Control 重新绑定应替换旧绑定，而不是叠加绑定。")
	assert_eq(store.get_subscription_count(), 1, "旧路径订阅应在重新绑定时被取消。")
	assert_eq(_get_signal_connection_count(line_edit, &"text_changed"), 1, "重新绑定后控件值变化信号不应重复连接。")
	assert_eq(line_edit.text, "Byron", "重新绑定后只有新路径变更应同步到控件。")


func test_control_signal_prunes_binding_when_store_is_released() -> void:
	var store: GFReactiveStateStoreBase = GFReactiveStateStoreBase.new({
		"profile": {
			"name": "Ada",
		},
	})
	var binder: GFReactiveStateControlBinderBase = GFReactiveStateControlBinderBase.new()
	var line_edit: LineEdit = LineEdit.new()
	_track_control(line_edit)
	var _bind_result: Variant = binder.bind_control(store, "profile.name", line_edit)

	assert_eq(binder.get_binding_count(), 1, "绑定后应记录一个有效绑定。")
	assert_eq(_get_signal_connection_count(line_edit, &"text_changed"), 1, "绑定后应连接控件值变化信号。")

	store = null
	line_edit.text = "Grace"
	line_edit.text_changed.emit("Grace")

	assert_eq(_get_signal_connection_count(line_edit, &"text_changed"), 0, "store 释放后控件回调应主动断开值变化信号。")
	assert_eq(binder.get_binding_count(), 0, "store 释放后控件回调应移除绑定记录。")


func test_store_path_change_updates_control_without_duplicate_loop() -> void:
	var store: GFReactiveStateStoreBase = GFReactiveStateStoreBase.new({
		"enabled": false,
	})
	var binder: GFReactiveStateControlBinderBase = GFReactiveStateControlBinderBase.new()
	var checkbox: CheckBox = CheckBox.new()
	_track_control(checkbox)
	var _bind_result: Variant = binder.bind_control(store, "enabled", checkbox)
	watch_signals(store)

	var _set_result: Variant = store.set_value("enabled", true)

	assert_true(checkbox.button_pressed, "store 变化应同步到 CheckBox。")
	assert_signal_emit_count(store, "state_changed", 1)


func test_write_initial_to_store_uses_control_value() -> void:
	var store: GFReactiveStateStoreBase = GFReactiveStateStoreBase.new({})
	var binder: GFReactiveStateControlBinderBase = GFReactiveStateControlBinderBase.new()
	var line_edit: LineEdit = LineEdit.new()
	line_edit.text = "Initial"
	_track_control(line_edit)

	var _bind_result: Variant = binder.bind_control(store, "profile.name", line_edit, {
		"write_initial_to_store": true,
	})

	assert_eq(GFVariantData.to_text(store.get_value("profile.name")), "Initial", "write_initial_to_store 应用控件值初始化 store。")


func test_control_tree_exit_clears_binding_and_store_subscription() -> void:
	var store: GFReactiveStateStoreBase = GFReactiveStateStoreBase.new({
		"name": "Ada",
	})
	var binder: GFReactiveStateControlBinderBase = GFReactiveStateControlBinderBase.new()
	var line_edit: LineEdit = LineEdit.new()
	add_child(line_edit)
	_controls.append(line_edit)
	var _bind_result: Variant = binder.bind_control(store, "name", line_edit)

	remove_child(line_edit)
	line_edit.tree_exited.emit()

	assert_eq(binder.get_binding_count(), 0, "Control 退出树后 binder 应清理绑定。")
	assert_eq(store.get_subscription_count(), 0, "Control 退出树后 store 订阅也应清理。")


# --- 私有/辅助方法 ---

func _track_control(control: Control) -> void:
	_controls.append(control)


func _get_signal_connection_count(control: Object, signal_name: StringName) -> int:
	var connections: Array = control.get_signal_connection_list(signal_name)
	return connections.size()
