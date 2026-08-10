## 测试 GFUIUtility 的层级管理与异步生命周期保护。
extends GutTest


const _GF_AUTOLOAD_SCRIPT = preload("res://addons/gf/kernel/core/gf_autoload.gd")
const _PANEL_SCENE_PATH: String = "res://tests/gf_core/fixtures/scene_signal_audit_valid.tscn"


var _ui_utility: GFUIUtility
var _arch: GFArchitecture = null


class ManualAssetUtility extends GFAssetUtility:
	var _callbacks: Dictionary = {}

	func load_async(path: String, on_loaded: Callable, _type_hint: String = "", _options: Dictionary = {}) -> void:
		if not _callbacks.has(path):
			var created_callbacks: Array[Callable] = []
			_callbacks[path] = created_callbacks
		var callbacks_value: Variant = _callbacks[path]
		if callbacks_value is Array:
			var list: Array = callbacks_value
			list.append(on_loaded)

	func resolve(path: String, resource: Resource) -> void:
		if not _callbacks.has(path):
			return

		var callbacks_value: Variant = _callbacks[path]
		var _erase_result_26: Variant = _callbacks.erase(path)
		if not callbacks_value is Array:
			return
		var callbacks: Array = callbacks_value
		for callback: Callable in callbacks:
			callback.call(resource)

	func resolve_next(path: String, resource: Resource) -> void:
		if not _callbacks.has(path):
			return
		var callbacks_value: Variant = _callbacks[path]
		if not callbacks_value is Array:
			return
		var callbacks: Array = callbacks_value
		if callbacks.is_empty():
			var _empty_erase_result: bool = _callbacks.erase(path)
			return
		var callback_value: Variant = callbacks.pop_front()
		if callbacks.is_empty():
			var _erase_result: bool = _callbacks.erase(path)
		if callback_value is Callable:
			var callback: Callable = callback_value
			callback.call(resource)


class SampleModalPanel extends Control:
	signal resolved(result: GFModalResult)

	var config: GFModalConfig = null
	var context: Dictionary = {}
	var did_resolve: bool = false

	func configure(modal_config: GFModalConfig, modal_context: Dictionary = {}) -> void:
		config = modal_config.duplicate_config() if modal_config != null else GFModalConfig.new()
		context = modal_context.duplicate(true)
		did_resolve = false

	func resolve_action(action_id: StringName) -> bool:
		if did_resolve:
			return false
		var action: GFModalAction = config.get_action(action_id) if config != null else null
		if action == null:
			return false
		did_resolve = true
		resolved.emit(action.make_result(context))
		return true

	func resolve_cancel() -> bool:
		if did_resolve:
			return false
		did_resolve = true
		resolved.emit(GFModalResult.create(
			GFModalResult.STATUS_CANCELLED,
			&"cancel",
			null,
			config.metadata if config != null else {},
			context
		))
		return true


class ReadyFocusPanel extends Control:
	var focus_button: Button = Button.new()

	func _init() -> void:
		focus_button.focus_mode = Control.FOCUS_ALL
		add_child(focus_button)

	func _ready() -> void:
		focus_button.grab_focus()


class ModalCallbackState:
	var result: GFModalResult = null
	var status: StringName = &""


func before_each() -> void:
	_ui_utility = GFUIUtility.new()
	_ui_utility.init()
	await get_tree().process_frame


func after_each() -> void:
	GFAutoload.reset_tree_exit_state()
	if _ui_utility != null:
		_ui_utility.dispose()
		_ui_utility = null

	if _arch != null:
		_arch.dispose()
		_arch = null

	Gf._architecture = null
	await get_tree().process_frame


func test_layer_creation() -> void:
	var hud_layer: CanvasLayer = _ui_utility.get_layer_root(GFUIUtility.Layer.HUD)
	var popup_layer: CanvasLayer = _ui_utility.get_layer_root(GFUIUtility.Layer.POPUP)

	assert_not_null(hud_layer, "HUD 层应正确创建。")
	assert_not_null(popup_layer, "POPUP 层应正确创建。")
	assert_eq(hud_layer.get_parent(), get_tree().root, "CanvasLayer 应挂载到 SceneTree.root。")
	assert_eq(hud_layer.layer, 50, "HUD 层的基础 layer 应为 50。")
	assert_eq(popup_layer.layer, 60, "POPUP 层的基础 layer 应为 60。")


func test_repeated_init_does_not_duplicate_layer_roots() -> void:
	assert_eq(GFUIUtility.DEFAULT_LAYER_ID, GFUIUtility.Layer.POPUP, "公开默认层 ID 应与 POPUP 预置保持一致。")
	var original_root: CanvasLayer = _ui_utility.get_layer_root(GFUIUtility.Layer.POPUP)

	_ui_utility.init()

	assert_same(
		_ui_utility.get_layer_root(GFUIUtility.Layer.POPUP),
		original_root,
		"重复 init 不应遗留旧 CanvasLayer 或替换层根。"
	)


func test_custom_layer_definition_creates_independent_overlay_stack() -> void:
	var definition: GFUILayerDefinition = GFUILayerDefinition.new()
	definition.layer_id = 100
	definition.display_name = &"SIDEBAR"
	definition.canvas_layer = 60
	definition.auto_hide_under = false

	assert_true(_ui_utility.register_layer(definition), "运行时应能注册项目自定义逻辑层。")
	var sidebar_root: CanvasLayer = _ui_utility.get_layer_root(100)
	var chat_panel: Control = Control.new()
	var inventory_panel: Control = Control.new()
	_ui_utility.push_panel_instance(chat_panel, 100)
	_ui_utility.push_panel_instance(inventory_panel, 100)

	assert_not_null(sidebar_root, "自定义层应创建 CanvasLayer 根节点。")
	assert_eq(sidebar_root.layer, 60, "逻辑层 ID 不应与 Godot CanvasLayer 排序值耦合。")
	assert_eq(sidebar_root.name, &"GFUILayer_SIDEBAR", "自定义层应使用稳定显示名。")
	assert_eq(_ui_utility.get_panel_stack(100), [chat_panel, inventory_panel], "自定义层应维护独立栈。")
	assert_true(chat_panel.visible, "overlay 层中的下方窗口应保持可见。")
	assert_true(inventory_panel.visible, "overlay 层中的顶部窗口应保持可见。")


func test_panel_hide_under_override_recomputes_complete_stack_visibility() -> void:
	var resident_panel: Control = Control.new()
	var widget_panel: Control = Control.new()
	var modal_panel: Control = Control.new()
	_ui_utility.push_panel_instance(resident_panel, GFUIUtility.Layer.POPUP)
	_ui_utility.push_panel_instance_with_options(widget_panel, GFUIUtility.Layer.POPUP, {
		"hide_under": false,
	})

	assert_true(resident_panel.visible, "非遮挡窗口不应隐藏常驻页面。")
	assert_true(widget_panel.visible, "非遮挡窗口自身应保持可见。")

	_ui_utility.push_panel_instance(modal_panel, GFUIUtility.Layer.POPUP)
	assert_false(resident_panel.visible, "默认遮挡面板应隐藏其下所有页面。")
	assert_false(widget_panel.visible, "默认遮挡面板应隐藏其下所有窗口。")
	assert_true(modal_panel.visible, "栈顶遮挡面板应保持可见。")

	_ui_utility.pop_panel(GFUIUtility.Layer.POPUP)
	assert_true(resident_panel.visible, "弹出遮挡面板后应恢复完整可见性链。")
	assert_true(widget_panel.visible, "弹出遮挡面板后非遮挡窗口应恢复可见。")


func test_layer_operations_preserve_resident_panels_in_other_layers() -> void:
	var resident_panel: Control = Control.new()
	var top_base_panel: Control = Control.new()
	var top_cover_panel: Control = Control.new()
	var top_replacement: Control = Control.new()
	_ui_utility.push_panel_instance(resident_panel, GFUIUtility.Layer.POPUP)
	var resident_parent: Node = resident_panel.get_parent()

	_ui_utility.push_panel_instance(top_base_panel, GFUIUtility.Layer.TOP)
	_ui_utility.push_panel_instance_with_options(top_cover_panel, GFUIUtility.Layer.TOP, {
		"hide_under": true,
	})

	assert_eq(resident_panel.get_parent(), resident_parent, "其他层的 hide_under 不应迁移常驻面板。")
	assert_true(resident_panel.visible, "其他层的 hide_under 不应隐藏常驻面板。")
	assert_eq(_ui_utility.get_panel_stack(GFUIUtility.Layer.POPUP), [resident_panel], "其他层入栈不应改写常驻层栈。")

	_ui_utility.replace_layer_instance(top_replacement, GFUIUtility.Layer.TOP)

	assert_eq(resident_panel.get_parent(), resident_parent, "其他层 replace 不应移除常驻面板。")
	assert_true(resident_panel.visible, "其他层 replace 不应改变常驻面板可见性。")
	assert_eq(_ui_utility.get_panel_stack(GFUIUtility.Layer.POPUP), [resident_panel], "其他层 replace 不应改写常驻层栈。")

	_ui_utility.clear_layer(GFUIUtility.Layer.TOP)

	assert_eq(resident_panel.get_parent(), resident_parent, "其他层 clear 不应移除常驻面板。")
	assert_true(resident_panel.visible, "其他层 clear 不应改变常驻面板可见性。")
	assert_eq(_ui_utility.get_panel_stack(GFUIUtility.Layer.POPUP), [resident_panel], "其他层 clear 不应改写常驻层栈。")


func test_dispose_detaches_layer_roots_immediately() -> void:
	var popup_layer: CanvasLayer = _ui_utility.get_layer_root(GFUIUtility.Layer.POPUP)

	_ui_utility.dispose()
	_ui_utility = null

	assert_null(popup_layer.get_parent(), "dispose 应立即从 SceneTree.root 移除 UI 层级。")

	await get_tree().process_frame
	assert_false(is_instance_valid(popup_layer), "下一帧 UI 层级应完成释放。")


func test_dispose_leaves_layer_roots_attached_during_autoload_tree_exit() -> void:
	var popup_layer: CanvasLayer = _ui_utility.get_layer_root(GFUIUtility.Layer.POPUP)
	_GF_AUTOLOAD_SCRIPT.begin_tree_exit_scope()

	_ui_utility.dispose()
	_ui_utility = null

	assert_not_null(popup_layer.get_parent(), "AutoLoad 退出时不应重入修改 UI 层级的父节点。")

	_GF_AUTOLOAD_SCRIPT.end_tree_exit_scope()
	await get_tree().process_frame
	assert_false(is_instance_valid(popup_layer), "退出阶段登记 queue_free 后仍应完成释放。")


func test_push_and_pop_panel_instance() -> void:
	var panel1: Control = Control.new()
	var panel2: Control = Control.new()

	_ui_utility.push_panel_instance(panel1, GFUIUtility.Layer.POPUP)
	assert_eq(_ui_utility.get_top_panel(GFUIUtility.Layer.POPUP), panel1, "压入 panel1 后栈顶应为 panel1。")
	assert_eq(panel1.get_parent(), _ui_utility.get_layer_root(GFUIUtility.Layer.POPUP), "panel1 应添加到对应的 CanvasLayer 下。")

	_ui_utility.push_panel_instance(panel2, GFUIUtility.Layer.POPUP)
	assert_eq(_ui_utility.get_top_panel(GFUIUtility.Layer.POPUP), panel2, "压入 panel2 后栈顶应为 panel2。")
	assert_false(panel1.visible, "auto_hide_under 开启时，下层面板应自动隐藏。")
	assert_true(panel2.visible, "新压入的面板应保持可见。")

	_ui_utility.pop_panel(GFUIUtility.Layer.POPUP, true)
	assert_eq(_ui_utility.get_top_panel(GFUIUtility.Layer.POPUP), panel1, "弹出 panel2 后栈顶应恢复为 panel1。")
	assert_true(panel1.visible, "弹出顶层后，下层面板应重新可见。")


func test_pop_panel_detaches_freed_panel_immediately() -> void:
	var panel: Control = Control.new()
	var popup_layer: CanvasLayer = _ui_utility.get_layer_root(GFUIUtility.Layer.POPUP)
	_ui_utility.push_panel_instance(panel, GFUIUtility.Layer.POPUP)

	_ui_utility.pop_panel(GFUIUtility.Layer.POPUP)

	assert_null(panel.get_parent(), "弹出并释放面板时，应立即从 UI 层级移除。")
	assert_eq(popup_layer.get_child_count(), 0, "弹出后 POPUP CanvasLayer 不应继续持有旧面板。")
	assert_null(_ui_utility.get_top_panel(GFUIUtility.Layer.POPUP), "弹出后栈顶应为空。")

	await get_tree().process_frame
	assert_false(is_instance_valid(panel), "弹出并释放面板后，下一帧实例应被释放。")


func test_pop_panel_without_free_detaches_and_keeps_instance() -> void:
	var panel: Control = Control.new()
	var popup_layer: CanvasLayer = _ui_utility.get_layer_root(GFUIUtility.Layer.POPUP)
	_ui_utility.push_panel_instance(panel, GFUIUtility.Layer.POPUP)

	_ui_utility.pop_panel(GFUIUtility.Layer.POPUP, false)

	assert_null(panel.get_parent(), "弹出但不释放时，也应立即从 UI 层级移除。")
	assert_eq(popup_layer.get_child_count(), 0, "弹出但不释放后 POPUP CanvasLayer 不应继续持有旧面板。")
	assert_true(is_instance_valid(panel), "do_free 为 false 时，面板实例应交还给调用方复用。")

	panel.free()


func test_panel_signals_and_stack_snapshot() -> void:
	var panel1: Control = Control.new()
	panel1.name = "PanelOne"
	var panel2: Control = Control.new()
	panel2.name = "PanelTwo"
	var opened: Array = []
	var closed: Array = []
	var navigation_tops: Array = []
	var _connect_result_172: Variant = _ui_utility.panel_opened.connect(func(panel: Node, _layer: int) -> void:
		opened.append(panel)
	)
	var _connect_result_175: Variant = _ui_utility.panel_closed.connect(func(panel: Node, _layer: int) -> void:
		closed.append(panel)
	)
	var _connect_result_178: Variant = _ui_utility.navigation_changed.connect(func(_layer: int, top_panel: Node) -> void:
		navigation_tops.append(top_panel)
	)

	_ui_utility.push_panel_instance(panel1, GFUIUtility.Layer.POPUP)
	_ui_utility.push_panel_instance(panel2, GFUIUtility.Layer.POPUP)
	var stack: Array[Node] = _ui_utility.get_panel_stack(GFUIUtility.Layer.POPUP)

	assert_eq(opened, [panel1, panel2], "面板入栈应按顺序发出打开信号。")
	assert_eq(stack, [panel1, panel2], "get_panel_stack 应按从底到顶返回副本。")
	assert_eq(_ui_utility.get_stack_count(GFUIUtility.Layer.POPUP), 2, "栈数量应可查询。")
	assert_true(_ui_utility.is_panel_open(panel1), "已入栈面板应报告为打开。")

	_ui_utility.pop_panel(GFUIUtility.Layer.POPUP)

	assert_eq(closed, [panel2], "弹出面板应发出关闭信号。")
	assert_eq(_array_node(navigation_tops, navigation_tops.size() - 1), panel1, "弹出后导航信号应报告新的栈顶。")


func test_modal_panel_options_and_cancel_dismiss() -> void:
	var panel: Control = Control.new()
	var dismissed: Array = []
	var _connect_result_200: Variant = _ui_utility.panel_dismiss_requested.connect(func(requested_panel: Node, layer: int, reason: String) -> void:
		dismissed.append([requested_panel, layer, reason])
	)

	_ui_utility.push_panel_instance_with_options(panel, GFUIUtility.Layer.POPUP, {
		"modal": true,
		"metadata": {
			"kind": "settings",
		},
	})
	assert_true(_ui_utility.has_modal_open(GFUIUtility.Layer.POPUP), "modal 面板入栈后应可查询。")

	var handled: bool = _ui_utility.request_dismiss_top(GFUIUtility.Layer.POPUP, "cancel")

	assert_true(handled, "modal 面板默认策略应允许取消关闭。")
	assert_eq(dismissed, [[panel, GFUIUtility.Layer.POPUP, "cancel"]], "取消请求应发出信号。")
	assert_null(_ui_utility.get_top_panel(GFUIUtility.Layer.POPUP), "取消关闭后栈顶应为空。")


func test_panel_options_accept_string_name_keys_and_copy_metadata() -> void:
	var panel: Control = Control.new()
	var source_metadata: Dictionary = {
		"nested": {
			"value": 1,
		},
	}

	_ui_utility.push_panel_instance_with_options(panel, GFUIUtility.Layer.POPUP, {
		&"modal": "on",
		&"dismiss_on_cancel": "off",
		&"metadata": source_metadata,
	})
	var options: Dictionary = _ui_utility.get_panel_options(panel)
	var options_metadata: Dictionary = GFVariantData.as_dictionary(options["metadata"])
	var options_nested: Dictionary = GFVariantData.as_dictionary(options_metadata["nested"])
	var source_nested: Dictionary = GFVariantData.as_dictionary(source_metadata["nested"])
	options_nested["value"] = 2

	assert_true(_ui_utility.is_panel_modal(panel), "StringName 选项键应被识别。")
	assert_false(GFVariantData.get_option_bool(options, "dismiss_on_cancel"), "字符串 off 应按 false 读取。")
	assert_eq(GFVariantData.get_option_int(source_nested, "value"), 1, "面板选项 metadata 应复制保存。")


func test_modal_can_refuse_cancel_dismiss() -> void:
	var panel: Control = Control.new()

	_ui_utility.push_panel_instance_with_options(panel, GFUIUtility.Layer.POPUP, {
		"modal": true,
		"dismiss_on_cancel": false,
	})
	var handled: bool = _ui_utility.request_dismiss_top(GFUIUtility.Layer.POPUP, "cancel")

	assert_false(handled, "禁止取消关闭的 modal 不应被 request_dismiss_top 弹出。")
	assert_eq(_ui_utility.get_top_panel(GFUIUtility.Layer.POPUP), panel, "拒绝取消后面板应仍在栈顶。")


func test_modal_config_has_no_implicit_default_action() -> void:
	var config: GFModalConfig = GFModalConfig.new()
	var action: GFModalAction = GFModalAction.new()

	assert_eq(config.get_actions().size(), 0, "空配置不应隐式生成 OK 动作。")
	assert_null(config.get_action(&"ok"), "未声明的动作不应可解析。")
	assert_eq(action.action_id, &"", "动作 ID 默认应为空。")
	assert_eq(action.label, "", "动作显示文本默认应为空。")
	assert_eq(action.result_status, GFModalResult.STATUS_DISMISSED, "动作默认结果应为 dismissed。")

	config.actions = [action]
	assert_eq(config.get_actions().size(), 0, "未显式设置 action_id 的动作不应被面板渲染。")


func test_custom_modal_protocol_returns_result_and_project_closes_panel() -> void:
	var confirm: GFModalAction = GFModalAction.new()
	confirm.action_id = &"confirm"
	confirm.label = "Confirm"
	confirm.result_status = GFModalResult.STATUS_CONFIRMED
	confirm.payload = { "value": 3 }

	var config: GFModalConfig = GFModalConfig.new()
	config.title = "Title"
	config.message = "Message"
	config.actions = [confirm]

	var received: ModalCallbackState = ModalCallbackState.new()
	var panel: SampleModalPanel = SampleModalPanel.new()
	panel.configure(config, { "source": "test" })
	var _connect_result_285: Variant = panel.resolved.connect(func(callback_result: GFModalResult) -> void:
		received.result = callback_result
		_ui_utility.pop_panel(GFUIUtility.Layer.POPUP)
	)
	_ui_utility.push_panel_instance_with_options(panel, GFUIUtility.Layer.POPUP, {
		"mode": GFUIUtility.PanelMode.MODAL,
		"dismiss_on_cancel": config.dismiss_on_cancel,
		"focus_on_open": config.auto_focus,
		"restore_focus_on_close": config.restore_focus_on_close,
		"metadata": config.metadata,
	})

	assert_eq(_ui_utility.get_top_panel(GFUIUtility.Layer.POPUP), panel, "项目 modal 面板应通过 UI 栈打开。")
	assert_true(panel.resolve_action(&"confirm"), "按动作解析应成功。")

	var received_result: GFModalResult = received.result
	var received_payload: Dictionary = GFVariantData.as_dictionary(received_result.payload)
	var received_context: Dictionary = GFVariantData.as_dictionary(received_result.context)
	assert_not_null(received_result, "结果回调应收到 GFModalResult。")
	assert_eq(received_result.status, GFModalResult.STATUS_CONFIRMED, "结果状态应来自动作配置。")
	assert_eq(received_result.action_id, &"confirm", "结果应记录动作 ID。")
	assert_eq(GFVariantData.get_option_int(received_payload, "value"), 3, "结果应保留动作载荷。")
	assert_eq(GFVariantData.get_option_string(received_context, "source"), "test", "结果应保留打开时上下文。")
	assert_null(_ui_utility.get_top_panel(GFUIUtility.Layer.POPUP), "modal 解析后应从栈中关闭。")


func test_request_dismiss_top_resolves_modal_cancel() -> void:
	var config: GFModalConfig = GFModalConfig.new()
	config.dismiss_on_cancel = true
	var received: ModalCallbackState = ModalCallbackState.new()
	var panel: SampleModalPanel = SampleModalPanel.new()
	panel.configure(config)
	var _connect_result_317: Variant = panel.resolved.connect(func(result: GFModalResult) -> void:
		received.status = result.status
		_ui_utility.pop_panel(GFUIUtility.Layer.POPUP)
	)
	_ui_utility.push_panel_instance_with_options(panel, GFUIUtility.Layer.POPUP, {
		"mode": GFUIUtility.PanelMode.MODAL,
		"dismiss_on_cancel": config.dismiss_on_cancel,
	})

	var handled: bool = _ui_utility.request_dismiss_top(GFUIUtility.Layer.POPUP, "cancel")

	assert_true(handled, "可取消 modal 应响应 request_dismiss_top。")
	assert_eq(received.status, GFModalResult.STATUS_CANCELLED, "取消请求应产生 cancelled 结果。")
	assert_null(_ui_utility.get_top_panel(GFUIUtility.Layer.POPUP), "取消后 modal 应关闭。")


func test_keep_focus_inside_top_modal() -> void:
	var outside: Button = Button.new()
	var panel: Control = Control.new()
	var inside: Button = Button.new()
	outside.focus_mode = Control.FOCUS_ALL
	inside.focus_mode = Control.FOCUS_ALL
	add_child(outside)
	panel.add_child(inside)

	_ui_utility.push_panel_instance_with_options(panel, GFUIUtility.Layer.POPUP, {
		"modal": true,
		"focus_on_open": false,
	})
	outside.grab_focus()
	var corrected: bool = _ui_utility.keep_focus_inside_top_modal(GFUIUtility.Layer.POPUP)

	assert_true(corrected, "焦点落在 modal 外部时应能被拉回 modal 内部。")
	assert_eq(get_viewport().gui_get_focus_owner(), inside, "焦点应移动到 modal 内第一个可聚焦控件。")

	outside.queue_free()


func test_modal_restores_focus_captured_before_panel_ready() -> void:
	var outside: Button = Button.new()
	outside.focus_mode = Control.FOCUS_ALL
	add_child(outside)
	outside.grab_focus()
	assert_same(get_viewport().gui_get_focus_owner(), outside)

	var panel: ReadyFocusPanel = ReadyFocusPanel.new()
	_ui_utility.push_panel_instance_with_options(panel, GFUIUtility.Layer.POPUP, {
		"modal": true,
		"focus_on_open": false,
		"restore_focus_on_close": true,
	})
	assert_same(
		get_viewport().gui_get_focus_owner(),
		panel.focus_button,
		"面板 _ready() 应能同步取得焦点。"
	)

	_ui_utility.pop_panel(GFUIUtility.Layer.POPUP, false)
	assert_same(
		get_viewport().gui_get_focus_owner(),
		outside,
		"关闭面板时应恢复其入树前的外部焦点。"
	)
	panel.queue_free()
	outside.queue_free()


func test_replace_layer_instance_clears_old_stack() -> void:
	var panel1: Control = Control.new()
	var panel2: Control = Control.new()
	var replacement: Control = Control.new()

	_ui_utility.push_panel_instance(panel1, GFUIUtility.Layer.POPUP)
	_ui_utility.push_panel_instance(panel2, GFUIUtility.Layer.POPUP)
	_ui_utility.replace_layer_instance(replacement, GFUIUtility.Layer.POPUP)

	assert_eq(_ui_utility.get_stack_count(GFUIUtility.Layer.POPUP), 1, "替换层级后应只保留新面板。")
	assert_eq(_ui_utility.get_top_panel(GFUIUtility.Layer.POPUP), replacement, "替换层级后栈顶应为新面板。")
	assert_null(panel1.get_parent(), "替换层级后旧底层面板应立即脱离 UI 层级。")
	assert_null(panel2.get_parent(), "替换层级后旧顶层面板应立即脱离 UI 层级。")
	assert_eq(replacement.get_parent(), _ui_utility.get_layer_root(GFUIUtility.Layer.POPUP), "替换后层级下应只挂载新面板。")


func test_pop_to_panel_returns_to_existing_panel() -> void:
	var panel1: Control = Control.new()
	var panel2: Control = Control.new()
	var panel3: Control = Control.new()

	_ui_utility.push_panel_instance(panel1, GFUIUtility.Layer.POPUP)
	_ui_utility.push_panel_instance(panel2, GFUIUtility.Layer.POPUP)
	_ui_utility.push_panel_instance(panel3, GFUIUtility.Layer.POPUP)

	var did_pop: bool = _ui_utility.pop_to_panel(panel1, GFUIUtility.Layer.POPUP)

	assert_true(did_pop, "目标面板存在时应成功回退。")
	assert_eq(_ui_utility.get_top_panel(GFUIUtility.Layer.POPUP), panel1, "回退后目标面板应成为栈顶。")
	assert_eq(_ui_utility.get_stack_count(GFUIUtility.Layer.POPUP), 1, "目标面板上方的面板都应被弹出。")


func test_push_panel_instance_rejects_duplicate_instance() -> void:
	var panel: Control = Control.new()

	_ui_utility.push_panel_instance(panel, GFUIUtility.Layer.POPUP)
	_ui_utility.push_panel_instance(panel, GFUIUtility.Layer.POPUP)

	assert_eq(_ui_utility.get_top_panel(GFUIUtility.Layer.POPUP), panel, "重复压入后栈顶仍应是原面板。")
	assert_eq(_panel_stack(GFUIUtility.Layer.POPUP).size(), 1, "同一面板实例不应重复进入栈。")
	assert_push_warning("[GFUIUtility] 面板实例已在 UI 栈中，忽略重复入栈。")


func test_push_panel_instance_reparents_external_node() -> void:
	var external_parent: Node = Node.new()
	add_child(external_parent)
	var panel: Control = Control.new()
	external_parent.add_child(panel)
	watch_signals(_ui_utility)

	_ui_utility.push_panel_instance(panel, GFUIUtility.Layer.POPUP)

	assert_eq(panel.get_parent(), _ui_utility.get_layer_root(GFUIUtility.Layer.POPUP), "已挂载面板应迁移到目标 CanvasLayer。")
	assert_false(external_parent.get_children().has(panel), "迁移后原父节点不应继续持有面板。")
	assert_eq(_ui_utility.get_top_panel(GFUIUtility.Layer.POPUP), panel, "迁移入栈后面板仍应是栈顶。")
	assert_true(_ui_utility.is_panel_open(panel, GFUIUtility.Layer.POPUP), "迁移入栈不应被 tree_exited 误判为关闭。")
	assert_eq(_ui_utility.get_stack_count(GFUIUtility.Layer.POPUP), 1, "迁移入栈后 UI 栈应保留面板。")
	assert_signal_not_emitted(_ui_utility, "panel_closed", "迁移父节点不应发出关闭信号。")

	external_parent.queue_free()


func test_push_panel_instance_applies_config_callback() -> void:
	var panel: Control = Control.new()

	_ui_utility.push_panel_instance(panel, GFUIUtility.Layer.POPUP, func(instance: Node) -> void:
		instance.name = "ConfiguredPanel"
	)

	assert_eq(panel.name, "ConfiguredPanel", "已实例化面板入栈前应执行配置回调。")
	assert_eq(_ui_utility.get_top_panel(GFUIUtility.Layer.POPUP), panel, "配置后的面板应正常入栈。")


func test_external_free_of_top_panel_prunes_stack_and_reveals_under_panel() -> void:
	var panel1: Control = Control.new()
	var panel2: Control = Control.new()

	_ui_utility.push_panel_instance(panel1, GFUIUtility.Layer.POPUP)
	_ui_utility.push_panel_instance(panel2, GFUIUtility.Layer.POPUP)
	assert_false(panel1.visible, "顶层面板存在时，下层面板应隐藏。")

	panel2.queue_free()
	await get_tree().process_frame

	assert_eq(_ui_utility.get_top_panel(GFUIUtility.Layer.POPUP), panel1, "外部释放顶层面板后，栈顶应回到下层面板。")
	assert_true(panel1.visible, "外部释放顶层面板后，下层面板应重新可见。")


func test_stale_freed_panel_reference_is_pruned_without_cast_error() -> void:
	var stale_panel: Control = Control.new()
	var stack: Array = _panel_stack(GFUIUtility.Layer.POPUP)
	stack.append(stale_panel)
	stale_panel.free()

	assert_null(_ui_utility.get_top_panel(GFUIUtility.Layer.POPUP), "已释放面板引用应被清出 UI 栈。")
	assert_eq(stack.size(), 0, "清理后 UI 栈不应保留已释放面板引用。")


func test_config_callback_destroying_panel_restores_hidden_panel() -> void:
	var panel1: Control = Control.new()
	var panel2: Control = Control.new()

	_ui_utility.push_panel_instance(panel1, GFUIUtility.Layer.POPUP)
	var added: bool = _ui_utility._add_panel_instance(
		panel2,
		GFUIUtility.Layer.POPUP,
		func(panel: Node) -> void:
			panel.free()
	)

	assert_false(added, "config_callback 销毁面板时，本次入栈应取消。")
	assert_push_warning("[GFUIUtility] config_callback 销毁了面板实例，本次入栈已取消。")
	assert_eq(_ui_utility.get_top_panel(GFUIUtility.Layer.POPUP), panel1, "取消入栈后栈顶应保持原面板。")
	assert_true(panel1.visible, "取消入栈后原本被隐藏的面板应恢复可见。")


func test_panel_opened_queue_free_rolls_back_options_and_emits_closed_once() -> void:
	var under_panel: Control = Control.new()
	_ui_utility.push_panel_instance(under_panel, GFUIUtility.Layer.POPUP)
	var panel: Control = Control.new()
	var panel_id: int = panel.get_instance_id()
	var closed_panel_ids: Array[int] = []
	var navigation_tops: Array[Node] = []
	var _opened_connection: Error = _ui_utility.panel_opened.connect(
		func(opened_panel: Node, _layer: int) -> void:
			opened_panel.queue_free(),
		CONNECT_ONE_SHOT as Object.ConnectFlags
	) as Error
	var _closed_connection: Error = _ui_utility.panel_closed.connect(
		func(closed_panel: Node, _layer: int) -> void:
			closed_panel_ids.append(closed_panel.get_instance_id())
	) as Error
	var _navigation_connection: Error = _ui_utility.navigation_changed.connect(
		func(_layer: int, top_panel: Node) -> void:
			navigation_tops.append(top_panel)
	) as Error

	var added: bool = _ui_utility._add_panel_instance(
		panel,
		GFUIUtility.Layer.POPUP,
		Callable(),
		{"metadata": {"source": "review_regression"}}
	)

	assert_false(added, "观察者已排队释放的面板不得提交为成功入栈。")
	assert_eq(_ui_utility.get_stack_count(GFUIUtility.Layer.POPUP), 1)
	assert_same(_ui_utility.get_top_panel(GFUIUtility.Layer.POPUP), under_panel)
	assert_false(_ui_utility.is_panel_open(panel), "已排队释放的面板不得被报告为 open。")
	assert_false(_ui_utility._panel_options.has(panel_id), "结构回滚必须清理面板策略快照。")
	assert_eq(closed_panel_ids, [panel_id], "已发出 opened 的面板必须获得唯一配对 closed。")
	assert_eq(navigation_tops, [under_panel], "回滚后应只报告一次最终有效栈顶。")
	await get_tree().process_frame
	assert_eq(closed_panel_ids.size(), 1, "后到 tree_exited 不得重复发出 closed。")
	assert_eq(navigation_tops.size(), 1, "后到 tree_exited 不得重复发出导航变更。")


func test_clear_layer() -> void:
	var p1: Control = Control.new()
	var p2: Control = Control.new()

	_ui_utility.push_panel_instance(p1, GFUIUtility.Layer.TOP)
	_ui_utility.push_panel_instance(p2, GFUIUtility.Layer.TOP)

	_ui_utility.clear_layer(GFUIUtility.Layer.TOP)
	assert_null(_ui_utility.get_top_panel(GFUIUtility.Layer.TOP), "清空层后不应再有顶部面板。")
	assert_null(p1.get_parent(), "清空层级应立即移除旧面板。")
	assert_null(p2.get_parent(), "清空层级应立即移除所有旧面板。")
	assert_eq(_ui_utility.get_layer_root(GFUIUtility.Layer.TOP).get_child_count(), 0, "清空层级后 CanvasLayer 不应继续持有旧面板。")

	await get_tree().process_frame
	assert_false(is_instance_valid(p1), "clear_layer 后原面板应被 queue_free。")
	assert_false(is_instance_valid(p2), "clear_layer 后所有面板都应被释放。")


func test_push_panel_async_ignores_late_callback_after_dispose() -> void:
	_arch = GFArchitecture.new()
	var asset_util: ManualAssetUtility = ManualAssetUtility.new()
	await _arch.register_utility_instance(asset_util)
	await Gf.set_architecture(_arch)

	var scene: PackedScene = _make_control_scene()
	var _disposed_handle: GFUIPanelAsyncOperation = _ui_utility.push_panel_async(
		"res://tests/pending_async_panel.tscn",
		GFUIUtility.Layer.POPUP
	)
	_ui_utility.dispose()

	asset_util.resolve("res://tests/pending_async_panel.tscn", scene)
	await get_tree().process_frame

	assert_null(_ui_utility.get_top_panel(GFUIUtility.Layer.POPUP), "销毁后的异步回调不应再把面板压入栈。")


func test_panel_async_operation_rejects_invalid_terminal_payloads() -> void:
	var operation: GFUIPanelAsyncOperation = GFUIPanelAsyncOperation.new()
	assert_true(operation.configure_for_framework(1, "res://tests/panel.tscn", 3, &"push"))
	assert_false(operation.complete_for_framework(99, null), "未知终态不得完成句柄。")
	assert_false(
		operation.complete_for_framework(GFUIUtility.AsyncPanelLoadStatus.OPENED, null),
		"OPENED 必须携带有效面板。"
	)
	assert_true(operation.is_pending(), "非法终态输入不得污染 pending 句柄。")

	var ignored_panel: Node = Node.new()
	assert_true(
		operation.complete_for_framework(GFUIUtility.AsyncPanelLoadStatus.FAILED, ignored_panel),
		"合法失败终态应完成句柄。"
	)
	assert_null(operation.get_panel(), "失败与取消终态不得保留面板引用。")
	ignored_panel.free()


func test_push_panel_async_reports_pending_load_lifecycle() -> void:
	_arch = GFArchitecture.new()
	var asset_util: ManualAssetUtility = ManualAssetUtility.new()
	await _arch.register_utility_instance(asset_util)
	await Gf.set_architecture(_arch)

	var path: String = "res://tests/pending_async_panel.tscn"
	var started: Array = []
	var finished: Array = []
	var _connect_result_509: Variant = _ui_utility.panel_async_load_started.connect(func(load_path: String, layer: int, operation: StringName) -> void:
		started.append([load_path, layer, operation])
	)
	var _connect_result_512: Variant = _ui_utility.panel_async_load_finished.connect(func(
		load_path: String,
		layer: int,
		operation: StringName,
		status: int,
		panel: Node
	) -> void:
		finished.append([load_path, layer, operation, status, panel])
	)

	var operation_handle: GFUIPanelAsyncOperation = _ui_utility.push_panel_async(
		path,
		GFUIUtility.Layer.POPUP
	)

	assert_not_null(operation_handle, "有效异步请求应返回类型化句柄。")
	assert_true(operation_handle.is_pending(), "资源返回前句柄应保持 pending。")
	assert_false(operation_handle.is_completed(), "pending 句柄不应已有终态。")
	assert_eq(operation_handle.get_serial(), 1, "句柄应冻结 UI 分配的请求序号。")
	assert_eq(operation_handle.get_path(), path, "句柄应冻结场景路径。")
	assert_eq(operation_handle.get_layer(), GFUIUtility.Layer.POPUP, "句柄应冻结目标层级。")
	assert_eq(operation_handle.get_operation(), GFUIPanelAsyncOperation.OPERATION_PUSH)
	assert_eq(operation_handle.get_status(), GFUIPanelAsyncOperation.STATUS_PENDING)
	assert_true(_ui_utility.has_pending_async_panel(GFUIUtility.Layer.POPUP, path), "异步加载期间应暴露 pending 状态。")
	var pending_requests: Array[Dictionary] = _ui_utility.get_pending_async_panel_requests(
		GFUIUtility.Layer.POPUP
	)
	assert_eq(pending_requests.size(), 1, "pending 快照应包含当前请求。")
	assert_same(
		_ui_panel_async_operation(pending_requests[0].get("operation_handle")),
		operation_handle,
		"pending 快照应保留同一类型化请求身份。"
	)
	assert_eq(started, [[path, GFUIUtility.Layer.POPUP, &"push"]], "异步请求开始时应发出开始信号。")

	asset_util.resolve(path, _make_control_scene())
	await get_tree().process_frame

	assert_false(_ui_utility.has_pending_async_panel(GFUIUtility.Layer.POPUP, path), "资源返回后 pending 状态应清理。")
	assert_eq(finished.size(), 1, "异步请求结束时应发出结束信号。")
	var opened_event: Array = _array_item_as_array(finished, 0)
	assert_eq(_array_int(opened_event, 3), GFUIUtility.AsyncPanelLoadStatus.OPENED, "成功入栈应报告 OPENED。")
	assert_not_null(_array_node(opened_event, 4), "成功状态应携带已打开面板。")
	assert_true(operation_handle.is_completed(), "资源返回后句柄应进入终态。")
	assert_eq(operation_handle.get_status(), GFUIUtility.AsyncPanelLoadStatus.OPENED)
	assert_same(operation_handle.get_panel(), _array_node(opened_event, 4))

	_ui_utility.clear_layer(GFUIUtility.Layer.POPUP)
	await get_tree().process_frame
	assert_null(operation_handle.get_panel(), "句柄弱引用不应延长已关闭面板的生命周期。")


func test_push_panel_async_fails_when_panel_opened_listener_frees_panel() -> void:
	_arch = GFArchitecture.new()
	var asset_util: ManualAssetUtility = ManualAssetUtility.new()
	await _arch.register_utility_instance(asset_util)
	await Gf.set_architecture(_arch)

	var path: String = "res://tests/freed_during_panel_opened.tscn"
	var finished: Array = []
	var completed_handles: Array[GFUIPanelAsyncOperation] = []
	var navigation_tops: Array = []
	var _opened_connection: Error = _ui_utility.panel_opened.connect(
		func(panel: Node, _layer: int) -> void:
			panel.free(),
		CONNECT_ONE_SHOT as Object.ConnectFlags
	) as Error
	var _finished_connection: Error = _ui_utility.panel_async_load_finished.connect(func(
		load_path: String,
		layer: int,
		operation: StringName,
		status: int,
		panel: Node
	) -> void:
		finished.append([load_path, layer, operation, status, panel])
	) as Error
	var _navigation_connection: Error = _ui_utility.navigation_changed.connect(
		func(_layer: int, top_panel: Node) -> void:
			navigation_tops.append(top_panel)
	) as Error

	var operation_handle: GFUIPanelAsyncOperation = _ui_utility.push_panel_async(
		path,
		GFUIUtility.Layer.POPUP,
		Callable(),
		func(completed_handle: GFUIPanelAsyncOperation) -> void:
			completed_handles.append(completed_handle)
	)
	asset_util.resolve(path, _make_control_scene())

	assert_true(operation_handle.is_completed(), "监听器释放面板后句柄仍必须进入终态。")
	assert_eq(
		operation_handle.get_status(),
		GFUIUtility.AsyncPanelLoadStatus.FAILED,
		"已被同步释放的面板不能作为 OPENED 结果。"
	)
	assert_null(operation_handle.get_panel(), "失败终态不得保留已释放面板。")
	assert_eq(completed_handles, [operation_handle], "句柄应且仅应发出一次失败终态。")
	assert_false(_ui_utility.has_pending_async_panel(GFUIUtility.Layer.POPUP, path))
	assert_eq(_ui_utility.get_stack_count(GFUIUtility.Layer.POPUP), 0)
	assert_eq(finished.size(), 1, "异步 telemetry 应收到唯一失败终态。")
	var failed_event: Array = _array_item_as_array(finished, 0)
	assert_eq(_array_int(failed_event, 3), GFUIUtility.AsyncPanelLoadStatus.FAILED)
	assert_true(_array_value(failed_event, 4) == null, "失败 telemetry 不得携带无效面板。")
	assert_eq(navigation_tops, [null], "同步释放路径应只报告一次最终空栈导航。")


func test_push_panel_async_sync_fallback_prebinds_callback_before_telemetry() -> void:
	var events: Array[StringName] = []
	var state: Dictionary = {}
	var _finished_connection: Error = _ui_utility.panel_async_load_finished.connect(func(
		_path: String,
		_layer: int,
		_operation: StringName,
		_status: int,
		_panel: Node
	) -> void:
		events.append(&"telemetry")
	) as Error

	var first_handle: GFUIPanelAsyncOperation = _ui_utility.push_panel_async(
		_PANEL_SCENE_PATH,
		GFUIUtility.Layer.POPUP,
		Callable(),
		func(completed_handle: GFUIPanelAsyncOperation) -> void:
			events.append(&"first_handle")
			state["first_callback_handle"] = completed_handle
			state["second_handle"] = _ui_utility.push_panel_async(
				_PANEL_SCENE_PATH,
				GFUIUtility.Layer.POPUP,
				Callable(),
				func(_second_completed_handle: GFUIPanelAsyncOperation) -> void:
					events.append(&"second_handle")
			)
	)
	assert_push_warning("[GFUIUtility] GFAssetUtility 未注册，回退为同步加载。")
	assert_push_warning("[GFUIUtility] GFAssetUtility 未注册，回退为同步加载。")

	var second_handle: GFUIPanelAsyncOperation = _ui_panel_async_operation(
		state.get("second_handle")
	)
	assert_not_null(first_handle, "同步 fallback 也应返回句柄。")
	assert_not_null(second_handle, "终态回调应能立即提交同键新请求。")
	assert_not_same(second_handle, first_handle, "同键重入必须得到独立的新句柄。")
	assert_same(
		_ui_panel_async_operation(state.get("first_callback_handle")),
		first_handle,
		"预绑定回调应收到即将返回的同一句柄。"
	)
	assert_true(first_handle.is_completed())
	assert_true(second_handle.is_completed())
	assert_eq(first_handle.get_status(), GFUIUtility.AsyncPanelLoadStatus.OPENED)
	assert_eq(second_handle.get_status(), GFUIUtility.AsyncPanelLoadStatus.OPENED)
	assert_ne(first_handle.get_panel(), second_handle.get_panel(), "两个句柄不得串用成功面板。")
	assert_eq(
		events,
		[&"first_handle", &"second_handle", &"telemetry", &"telemetry"],
		"句柄回调必须先于各自 telemetry，且嵌套请求应保持独立顺序。"
	)
	assert_eq(_ui_utility.get_stack_count(GFUIUtility.Layer.POPUP), 2)


func test_async_completion_callback_can_reenter_same_key_without_handle_crosstalk() -> void:
	_arch = GFArchitecture.new()
	var asset_util: ManualAssetUtility = ManualAssetUtility.new()
	await _arch.register_utility_instance(asset_util)
	await Gf.set_architecture(_arch)

	var path: String = "res://tests/reentrant_async_panel.tscn"
	var first_completions: Array[GFUIPanelAsyncOperation] = []
	var second_completions: Array[GFUIPanelAsyncOperation] = []
	var state: Dictionary = {}
	var first_handle: GFUIPanelAsyncOperation = _ui_utility.push_panel_async(
		path,
		GFUIUtility.Layer.POPUP,
		Callable(),
		func(completed_handle: GFUIPanelAsyncOperation) -> void:
			first_completions.append(completed_handle)
			state["second_handle"] = _ui_utility.push_panel_async(
				path,
				GFUIUtility.Layer.POPUP,
				Callable(),
				func(second_completed_handle: GFUIPanelAsyncOperation) -> void:
					second_completions.append(second_completed_handle)
			)
	)

	asset_util.resolve(path, _make_control_scene())
	var second_handle: GFUIPanelAsyncOperation = _ui_panel_async_operation(
		state.get("second_handle")
	)
	assert_not_null(second_handle, "首个终态回调应能提交同键新请求。")
	assert_not_same(second_handle, first_handle, "新请求不能复用已完成句柄。")
	assert_true(first_handle.is_completed())
	assert_true(second_handle.is_pending(), "新请求应独立等待第二次资源结果。")
	assert_eq(first_completions, [first_handle])
	assert_true(second_completions.is_empty())

	asset_util.resolve(path, _make_control_scene())
	await get_tree().process_frame

	assert_true(second_handle.is_completed())
	assert_eq(second_completions, [second_handle])
	assert_eq(first_completions.size(), 1, "第二个终态不得回流到首个句柄。")
	assert_ne(first_handle.get_panel(), second_handle.get_panel(), "两个请求必须保留各自面板弱引用。")
	assert_eq(_ui_utility.get_stack_count(GFUIUtility.Layer.POPUP), 2)


func test_request_serial_survives_dispose_reinit_and_rejects_old_callback_collision() -> void:
	_arch = GFArchitecture.new()
	var asset_util: ManualAssetUtility = ManualAssetUtility.new()
	await _arch.register_utility_instance(asset_util)
	await Gf.set_architecture(_arch)

	var path: String = "res://tests/reinitialized_async_panel.tscn"
	var old_handle: GFUIPanelAsyncOperation = _ui_utility.push_panel_async(
		path,
		GFUIUtility.Layer.POPUP
	)
	_ui_utility.dispose()
	assert_true(old_handle.is_completed(), "dispose 应立即终止旧请求。")
	assert_eq(old_handle.get_status(), GFUIUtility.AsyncPanelLoadStatus.CANCELLED)

	_ui_utility.init()
	var new_handle: GFUIPanelAsyncOperation = _ui_utility.push_panel_async(
		path,
		GFUIUtility.Layer.POPUP
	)
	assert_true(new_handle.get_serial() > old_handle.get_serial(), "重新初始化不得复用请求序号。")

	asset_util.resolve_next(path, _make_control_scene())
	assert_true(new_handle.is_pending(), "旧生命周期的迟到回调不得命中新请求身份。")
	assert_null(_ui_utility.get_top_panel(GFUIUtility.Layer.POPUP))

	asset_util.resolve_next(path, _make_control_scene())
	await get_tree().process_frame

	assert_true(new_handle.is_completed())
	assert_eq(new_handle.get_status(), GFUIUtility.AsyncPanelLoadStatus.OPENED)
	assert_same(new_handle.get_panel(), _ui_utility.get_top_panel(GFUIUtility.Layer.POPUP))
	assert_eq(old_handle.get_status(), GFUIUtility.AsyncPanelLoadStatus.CANCELLED)


func test_replace_layer_async_returns_typed_operation_handle() -> void:
	_arch = GFArchitecture.new()
	var asset_util: ManualAssetUtility = ManualAssetUtility.new()
	await _arch.register_utility_instance(asset_util)
	await Gf.set_architecture(_arch)

	var path: String = "res://tests/pending_replace_panel.tscn"
	var operation_handle: GFUIPanelAsyncOperation = _ui_utility.replace_layer_async(
		path,
		GFUIUtility.Layer.TOP
	)
	assert_not_null(operation_handle)
	assert_true(operation_handle.is_pending())
	assert_eq(operation_handle.get_operation(), GFUIPanelAsyncOperation.OPERATION_REPLACE)
	assert_eq(operation_handle.get_path(), path)
	assert_eq(operation_handle.get_layer(), GFUIUtility.Layer.TOP)

	asset_util.resolve(path, _make_control_scene())
	await get_tree().process_frame

	assert_true(operation_handle.is_completed())
	assert_eq(operation_handle.get_status(), GFUIUtility.AsyncPanelLoadStatus.OPENED)
	assert_same(operation_handle.get_panel(), _ui_utility.get_top_panel(GFUIUtility.Layer.TOP))


func test_pending_async_panel_cancel_clears_state_and_reports_finished() -> void:
	_arch = GFArchitecture.new()
	var asset_util: ManualAssetUtility = ManualAssetUtility.new()
	await _arch.register_utility_instance(asset_util)
	await Gf.set_architecture(_arch)

	var path: String = "res://tests/pending_async_panel.tscn"
	var finished: Array = []
	var completed_handles: Array[GFUIPanelAsyncOperation] = []
	var _connect_result_545: Variant = _ui_utility.panel_async_load_finished.connect(func(
		load_path: String,
		layer: int,
		operation: StringName,
		status: int,
		panel: Node
	) -> void:
		finished.append([load_path, layer, operation, status, panel])
	)

	var operation_handle: GFUIPanelAsyncOperation = _ui_utility.push_panel_async(
		path,
		GFUIUtility.Layer.POPUP,
		Callable(),
		func(completed_handle: GFUIPanelAsyncOperation) -> void:
			completed_handles.append(completed_handle)
	)
	_ui_utility.clear_layer(GFUIUtility.Layer.POPUP)

	assert_not_null(operation_handle)
	assert_true(operation_handle.is_completed(), "清层应同步完成对应句柄。")
	assert_eq(operation_handle.get_status(), GFUIUtility.AsyncPanelLoadStatus.CANCELLED)
	assert_null(operation_handle.get_panel(), "取消终态不应携带面板。")
	assert_eq(completed_handles, [operation_handle], "句柄应只发出当前请求的取消终态。")
	assert_false(_ui_utility.has_pending_async_panel(GFUIUtility.Layer.POPUP, path), "清层应立即清理 pending 状态。")
	assert_eq(finished.size(), 1, "取消异步请求应发出结束信号。")
	var cancelled_event: Array = _array_item_as_array(finished, 0)
	assert_eq(_array_int(cancelled_event, 3), GFUIUtility.AsyncPanelLoadStatus.CANCELLED, "清层取消应报告 CANCELLED。")
	assert_true(_array_value(cancelled_event, 4) == null, "取消状态不应携带面板。")

	asset_util.resolve(path, _make_control_scene())
	await get_tree().process_frame

	assert_eq(finished.size(), 1, "迟到资源回调不应重复发出结束信号。")
	assert_eq(completed_handles.size(), 1, "迟到资源回调不应重复完成句柄。")
	assert_eq(operation_handle.get_status(), GFUIUtility.AsyncPanelLoadStatus.CANCELLED)
	assert_null(_ui_utility.get_top_panel(GFUIUtility.Layer.POPUP), "取消后的迟到异步回调不应打开面板。")


func test_push_panel_async_reports_failed_when_resource_is_not_scene() -> void:
	_arch = GFArchitecture.new()
	var asset_util: ManualAssetUtility = ManualAssetUtility.new()
	await _arch.register_utility_instance(asset_util)
	await Gf.set_architecture(_arch)

	var path: String = "res://tests/invalid_async_panel.tscn"
	var finished: Array = []
	var _connect_result_578: Variant = _ui_utility.panel_async_load_finished.connect(func(
		load_path: String,
		layer: int,
		operation: StringName,
		status: int,
		panel: Node
	) -> void:
		finished.append([load_path, layer, operation, status, panel])
	)

	var _failed_handle: GFUIPanelAsyncOperation = _ui_utility.push_panel_async(
		path,
		GFUIUtility.Layer.POPUP
	)
	asset_util.resolve(path, Resource.new())
	await get_tree().process_frame

	assert_false(_ui_utility.has_pending_async_panel(GFUIUtility.Layer.POPUP, path), "加载失败后 pending 状态应清理。")
	assert_eq(finished.size(), 1, "加载失败也应发出结束信号。")
	var failed_event: Array = _array_item_as_array(finished, 0)
	assert_eq(_array_int(failed_event, 3), GFUIUtility.AsyncPanelLoadStatus.FAILED, "非 PackedScene 资源应报告 FAILED。")
	assert_true(_array_value(failed_event, 4) == null, "失败状态不应携带面板。")
	assert_push_error("[GFUIUtility] 无法实例化面板场景：%s" % path)


func test_push_panel_async_ignores_late_callback_after_layer_clear() -> void:
	_arch = GFArchitecture.new()
	var asset_util: ManualAssetUtility = ManualAssetUtility.new()
	await _arch.register_utility_instance(asset_util)
	await Gf.set_architecture(_arch)

	var scene: PackedScene = _make_control_scene()
	var _cleared_handle: GFUIPanelAsyncOperation = _ui_utility.push_panel_async(
		"res://tests/pending_async_panel.tscn",
		GFUIUtility.Layer.POPUP
	)
	_ui_utility.clear_layer(GFUIUtility.Layer.POPUP)

	asset_util.resolve("res://tests/pending_async_panel.tscn", scene)
	await get_tree().process_frame

	assert_null(_ui_utility.get_top_panel(GFUIUtility.Layer.POPUP), "清空层级后的迟到异步回调不应重新压入旧面板。")


func test_push_panel_async_ignores_late_callback_after_pop_cancel() -> void:
	_arch = GFArchitecture.new()
	var asset_util: ManualAssetUtility = ManualAssetUtility.new()
	await _arch.register_utility_instance(asset_util)
	await Gf.set_architecture(_arch)

	var scene: PackedScene = _make_control_scene()
	var _popped_handle: GFUIPanelAsyncOperation = _ui_utility.push_panel_async(
		"res://tests/pending_async_panel.tscn",
		GFUIUtility.Layer.POPUP
	)
	_ui_utility.pop_panel(GFUIUtility.Layer.POPUP)

	asset_util.resolve("res://tests/pending_async_panel.tscn", scene)
	await get_tree().process_frame

	assert_null(_ui_utility.get_top_panel(GFUIUtility.Layer.POPUP), "pop 取消后的迟到异步回调不应重新压入旧面板。")


func test_duplicate_pending_push_panel_async_is_coalesced() -> void:
	_arch = GFArchitecture.new()
	var asset_util: ManualAssetUtility = ManualAssetUtility.new()
	await _arch.register_utility_instance(asset_util)
	await Gf.set_architecture(_arch)

	var scene: PackedScene = _make_control_scene()
	var first_handle: GFUIPanelAsyncOperation = _ui_utility.push_panel_async(
		"res://tests/pending_async_panel.tscn",
		GFUIUtility.Layer.POPUP
	)
	var second_handle: GFUIPanelAsyncOperation = _ui_utility.push_panel_async(
		"res://tests/pending_async_panel.tscn",
		GFUIUtility.Layer.POPUP
	)
	assert_same(second_handle, first_handle, "合流请求应共享同一类型化句柄。")

	asset_util.resolve("res://tests/pending_async_panel.tscn", scene)
	await get_tree().process_frame

	assert_eq(_ui_utility.get_stack_count(GFUIUtility.Layer.POPUP), 1, "同层同路径的重复异步 push 应只创建一个面板。")


func test_later_async_push_cancels_older_replace_intent() -> void:
	_arch = GFArchitecture.new()
	var asset_util: ManualAssetUtility = ManualAssetUtility.new()
	await _arch.register_utility_instance(asset_util)
	await Gf.set_architecture(_arch)

	var replace_path: String = "res://tests/older_replace_panel.tscn"
	var push_path: String = "res://tests/newer_push_panel.tscn"
	var _replace_handle: GFUIPanelAsyncOperation = _ui_utility.replace_layer_async(
		replace_path,
		GFUIUtility.Layer.POPUP
	)
	var _push_handle: GFUIPanelAsyncOperation = _ui_utility.push_panel_async(
		push_path,
		GFUIUtility.Layer.POPUP
	)

	assert_false(
		_ui_utility.has_pending_async_panel(GFUIUtility.Layer.POPUP, replace_path),
		"后发 push 应立即终止同层旧 replace，避免迟到 replace 清空新状态。"
	)
	asset_util.resolve(push_path, _make_control_scene())
	await get_tree().process_frame
	var pushed_panel: Node = _ui_utility.get_top_panel(GFUIUtility.Layer.POPUP)
	assert_not_null(pushed_panel, "后发 push 应正常打开。")

	asset_util.resolve(replace_path, _make_control_scene())
	await get_tree().process_frame

	assert_eq(
		_ui_utility.get_top_panel(GFUIUtility.Layer.POPUP),
		pushed_panel,
		"旧 replace 的迟到回调不得覆盖后发 push。"
	)


func _panel_stack(layer: int) -> Array:
	var stack_value: Variant = _ui_utility._panel_stacks[layer]
	if stack_value is Array:
		var stack: Array = stack_value
		return stack
	return []


func _array_value(values: Array, index: int) -> Variant:
	if index < 0 or index >= values.size():
		return null
	return values[index]


func _array_item_as_array(values: Array, index: int) -> Array:
	return GFVariantData.as_array(_array_value(values, index))


func _array_int(values: Array, index: int) -> int:
	return GFVariantData.to_int(_array_value(values, index))


func _array_node(values: Array, index: int) -> Node:
	var value: Variant = _array_value(values, index)
	if value is Node:
		return value
	return null


func _ui_panel_async_operation(value: Variant) -> GFUIPanelAsyncOperation:
	if value is GFUIPanelAsyncOperation:
		var operation_handle: GFUIPanelAsyncOperation = value
		return operation_handle
	return null


func _make_control_scene() -> PackedScene:
	var control: Control = Control.new()
	var scene: PackedScene = PackedScene.new()
	var _pack_result_658: Variant = scene.pack(control)
	control.free()
	return scene
