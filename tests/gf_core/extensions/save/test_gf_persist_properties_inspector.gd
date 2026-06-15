## 测试 GFPersistPropertiesSource 的编辑器属性白名单 Inspector。
extends GutTest


# --- 常量 ---

const GF_PERSIST_PROPERTIES_INSPECTOR_PLUGIN = preload("res://addons/gf/extensions/save/editor/gf_persist_properties_inspector_plugin.gd")
const GF_PERSIST_PROPERTIES_EDITOR_PROPERTY = preload("res://addons/gf/extensions/save/editor/gf_persist_properties_editor_property.gd")


# --- 辅助类 ---

class PropertyTarget extends Node:
	@export var health: int = 10
	@export var title: String = "unit"
	@warning_ignore("unused_private_class_variable")
	@export var _private_state: int = 1
	var runtime_only: int = 5


# --- 测试方法 ---

func test_persist_properties_inspector_only_handles_persist_source() -> void:
	var source: GFPersistPropertiesSource = GFPersistPropertiesSource.new()
	var node: Node = Node.new()

	assert_true(
		GF_PERSIST_PROPERTIES_INSPECTOR_PLUGIN.can_handle_object(source),
		"属性白名单 Inspector 应处理 GFPersistPropertiesSource。"
	)
	assert_false(
		GF_PERSIST_PROPERTIES_INSPECTOR_PLUGIN.can_handle_object(node),
		"属性白名单 Inspector 不应处理普通节点。"
	)

	source.free()
	node.free()


func test_property_picker_collects_editable_storable_target_properties() -> void:
	var target: PropertyTarget = PropertyTarget.new()
	var names: PackedStringArray = GF_PERSIST_PROPERTIES_EDITOR_PROPERTY.collect_storable_property_names(target)

	assert_true(names.has("health"), "属性选择器应包含导出的可存储属性。")
	assert_true(names.has("title"), "属性选择器应包含多个导出的可存储属性。")
	assert_false(names.has("runtime_only"), "未导出运行时字段不应出现在属性选择器中。")
	assert_false(names.has("_private_state"), "私有命名的导出字段不应默认进入属性选择器。")
	assert_false(names.has("script"), "脚本引用不应作为可持久化属性候选。")

	target.free()
