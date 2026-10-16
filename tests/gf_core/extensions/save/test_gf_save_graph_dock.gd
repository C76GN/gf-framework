extends GutTest


# --- 常量 ---

const GF_SAVE_GRAPH_DOCK = preload("res://addons/gf/extensions/save/editor/gf_save_graph_dock.gd")


# --- 辅助类 ---

class MethodTrapSaveScope extends GFSaveScope:
	var get_scope_key_called: bool = false
	var can_save_scope_called: bool = false
	var can_load_scope_called: bool = false
	var describe_scope_called: bool = false

	func get_scope_key() -> StringName:
		get_scope_key_called = true
		return &"method_scope"


	func _can_save_scope(_context: Dictionary = {}) -> bool:
		can_save_scope_called = true
		return false


	func _can_load_scope(_context: Dictionary = {}) -> bool:
		can_load_scope_called = true
		return false


	func describe_scope() -> Dictionary:
		describe_scope_called = true
		return { "scope_key": &"method_scope" }


# --- 测试方法 ---

func test_save_graph_dock_uses_compact_empty_state() -> void:
	var dock: Control = _new_save_graph_dock()
	var root: Node = Node.new()

	_set_save_graph_source(dock, root)

	var empty_label: Label = _label_property(dock, &"_empty_label")
	var content_split: HSplitContainer = _split_property(dock, &"_content_split")
	var summary_label: Label = _label_property(dock, &"_summary_label")
	assert_true(empty_label.visible, "没有 GFSaveScope 时应显示空状态。")
	assert_false(content_split.visible, "没有 GFSaveScope 时不应留下空表格和详情面板。")
	assert_ne(
		summary_label.text,
		empty_label.text,
		"空状态标题和说明不应重复。"
	)

	dock.free()
	root.free()


func test_save_graph_dock_refresh_does_not_call_scope_methods() -> void:
	var dock: Control = _new_save_graph_dock()
	var root: Node = Node.new()
	var scope: MethodTrapSaveScope = MethodTrapSaveScope.new()
	scope.name = "TrapScope"
	scope.scope_key = &"export_scope"
	root.add_child(scope)

	_set_save_graph_source(dock, root)
	var report: Dictionary = _last_scope_report(dock)

	assert_eq(
		GFVariantData.get_option_string(report, "scope_key"),
		"export_scope",
		"Save 页面应读取导出的 scope_key。"
	)
	assert_false(scope.get_scope_key_called, "刷新 Save 页面不应调用 Scope 方法，避免 placeholder 报错。")
	assert_false(scope.can_save_scope_called, "刷新 Save 页面不应调用 Scope 保存判断方法。")
	assert_false(scope.can_load_scope_called, "刷新 Save 页面不应调用 Scope 加载判断方法。")
	assert_false(scope.describe_scope_called, "刷新 Save 页面不应调用 Scope 描述方法。")

	dock.free()
	root.free()


func test_save_graph_dock_reports_scope_structure_and_preview_payload() -> void:
	var dock: Control = _new_save_graph_dock()
	var root: Node = Node.new()
	var scope: GFSaveScope = GFSaveScope.new()
	var source: GFSaveSource = GFSaveSource.new()
	scope.name = "SaveScope"
	scope.scope_key = &"root"
	source.name = "StateSource"
	source.source_key = &"state"
	scope.add_child(source)
	root.add_child(scope)

	_set_save_graph_source(dock, root)
	var report: Dictionary = _last_scope_report(dock)

	assert_eq(
		GFVariantData.get_option_int(report, "scope_count"),
		1,
		"Save 页面应统计 Scope 数量。"
	)
	assert_eq(
		GFVariantData.get_option_int(report, "source_count"),
		1,
		"Save 页面应统计 Source 数量。"
	)
	assert_true(
		GFVariantData.get_option_bool(report, "ok"),
		"结构健康的 SaveGraph 应报告 ok。"
	)

	_call_void(dock, &"_on_preview_payload_pressed")
	var payload: Dictionary = _last_payload(dock)
	var sources: Dictionary = GFVariantData.get_option_dictionary(payload, "sources")

	assert_eq(
		GFVariantData.get_option_string(payload, "format"),
		GFSaveGraphUtility.FORMAT_ID,
		"Save 页面应能采集预览 payload。"
	)
	assert_true(
		sources.has("state"),
		"预览 payload 应包含 Source 数据入口。"
	)

	dock.free()
	root.free()


# --- 私有/辅助方法 ---

func _new_save_graph_dock() -> Control:
	var object_instance: Object = _new_object(GF_SAVE_GRAPH_DOCK)
	assert_true(
		object_instance is Control,
		"SaveGraph dock 脚本应实例化为 Control。"
	)
	if object_instance is Control:
		var control: Control = object_instance
		return control
	return null


func _new_object(script_value: Variant) -> Object:
	assert_true(
		script_value is Script,
		"测试脚本资源应可实例化。"
	)
	if script_value is Script:
		var script: Script = script_value
		var instance: Variant = script.call(&"new")
		assert_true(
			instance is Object,
			"测试脚本资源应实例化为 Object。"
		)
		if instance is Object:
			var object_instance: Object = instance
			return object_instance
	return null


func _set_save_graph_source(dock: Object, root: Node) -> void:
	_call_void(
		dock,
		&"set_save_graph_source",
		[root]
	)


func _last_scope_report(dock: Object) -> Dictionary:
	return GFVariantData.as_dictionary(dock.call(&"get_last_scope_report"))


func _last_payload(dock: Object) -> Dictionary:
	return GFVariantData.as_dictionary(dock.call(&"get_last_payload"))


func _call_void(
	target: Object,
	method_name: StringName,
	args: Array = []
) -> void:
	var _call_result: Variant = target.callv(method_name, args)


func _label_property(target: Object, property_name: StringName) -> Label:
	var value: Variant = target.get(property_name)
	assert_true(
		value is Label,
		"测试观察属性应为 Label。"
	)
	if value is Label:
		var label: Label = value
		return label
	return null


func _split_property(target: Object, property_name: StringName) -> HSplitContainer:
	var value: Variant = target.get(property_name)
	assert_true(
		value is HSplitContainer,
		"测试观察属性应为 HSplitContainer。"
	)
	if value is HSplitContainer:
		var split: HSplitContainer = value
		return split
	return null
