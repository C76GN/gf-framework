## 测试 GFPersistPropertiesSource 的属性白名单存档入口。
extends GutTest


# --- 常量 ---



# --- 私有变量 ---

var _utility: GFSaveGraphUtility
var _scope: GFSaveScope


# --- Godot 生命周期方法 ---

func before_each() -> void:
	_utility = GFSaveGraphUtility.new()
	_scope = GFSaveScope.new()
	_scope.name = "RootScope"
	_scope.scope_key = &"root"
	get_tree().root.add_child(_scope)


func after_each() -> void:
	if is_instance_valid(_scope):
		_scope.queue_free()
	_scope = null
	_utility = null
	await get_tree().process_frame


# --- 测试方法 ---

func test_persist_properties_source_restores_parent_properties() -> void:
	var target: Node2D = Node2D.new()
	target.name = "Target"
	target.position = Vector2(12.0, 34.0)
	target.rotation = 0.5
	_scope.add_child(target)

	var source: GFPersistPropertiesSource = GFPersistPropertiesSource.new()
	source.name = "State"
	source.source_key = &"target_state"
	source.properties = PackedStringArray(["position", "rotation"])
	target.add_child(source)

	var payload: Dictionary = _utility.gather_scope(_scope)
	target.position = Vector2.ZERO
	target.rotation = 0.0
	var result: Dictionary = _utility.apply_scope(_scope, payload)

	assert_true(GFVariantData.get_option_bool(result, "ok"), "属性持久化 Source 应能通过 SaveGraph 应用。")
	assert_eq(target.position, Vector2(12.0, 34.0), "白名单中的 Vector2 属性应恢复。")
	assert_almost_eq(target.rotation, 0.5, 0.001, "白名单中的 float 属性应恢复。")


func test_persist_properties_source_keeps_extra_serializers_composable() -> void:
	var target: Node2D = Node2D.new()
	target.name = "Target"
	target.position = Vector2(2.0, 3.0)
	target.scale = Vector2(4.0, 5.0)
	_scope.add_child(target)

	var source: GFPersistPropertiesSource = GFPersistPropertiesSource.new()
	source.name = "State"
	source.source_key = &"target_state"
	source.properties = PackedStringArray(["position"])
	source.use_registry_serializers = true
	target.add_child(source)

	var payload: Dictionary = _utility.gather_scope(_scope)
	target.position = Vector2.ZERO
	target.scale = Vector2.ONE
	var result: Dictionary = _utility.apply_scope(_scope, payload)

	assert_true(GFVariantData.get_option_bool(result, "ok"), "属性 Source 应能继续组合注册表默认序列化器。")
	assert_eq(target.position, Vector2(2.0, 3.0), "属性白名单片段应恢复 position。")
	assert_eq(target.scale, Vector2(4.0, 5.0), "注册表 Transform2D 序列化器应恢复 scale。")


func test_persist_properties_source_restores_allowed_resource_reference() -> void:
	var resource_path: String = "user://gf_persist_properties_resource.tres"
	var resource: Resource = Resource.new()
	resource.resource_name = "PersistPropertiesResource"
	assert_eq(ResourceSaver.save(resource, resource_path), OK, "测试资源应能保存到 user://。")

	var target: ResourcePropertyNode = ResourcePropertyNode.new()
	target.name = "Target"
	target.resource_value = ResourceLoader.load(resource_path, "", ResourceLoader.CACHE_MODE_IGNORE)
	_scope.add_child(target)

	var source: GFPersistPropertiesSource = GFPersistPropertiesSource.new()
	source.name = "State"
	source.source_key = &"target_state"
	source.properties = PackedStringArray(["resource_value"])
	source.allowed_resource_patterns = PackedStringArray([resource_path])
	target.add_child(source)

	var payload: Dictionary = _utility.gather_scope(_scope)
	target.resource_value = null
	var result: Dictionary = _utility.apply_scope(_scope, payload)

	assert_true(GFVariantData.get_option_bool(result, "ok"), "属性 Source 应能透传 Resource 路径策略。")
	assert_not_null(target.resource_value, "允许路径内的 Resource 属性应恢复。")
	assert_eq(target.resource_value.resource_path, resource_path, "Resource 属性应按保存路径恢复。")

	var absolute_path: String = ProjectSettings.globalize_path(resource_path)
	if FileAccess.file_exists(resource_path):
		var _remove_absolute_result_102: Variant = DirAccess.remove_absolute(absolute_path)


# --- 内部类 ---

class ResourcePropertyNode extends Node:
	var resource_value: Resource = null


	func _get_property_list() -> Array[Dictionary]:
		return [{
			"name": "resource_value",
			"type": TYPE_OBJECT,
			"class_name": "Resource",
			"usage": PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_STORAGE,
		}]


	func _get(property: StringName) -> Variant:
		if property == &"resource_value":
			return resource_value
		return null


	func _set(property: StringName, value: Variant) -> bool:
		if property == &"resource_value":
			if value != null and not value is Resource:
				return false
			resource_value = null
			if value is Resource:
				resource_value = value
			return true
		return false
