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


func test_persist_properties_source_rejects_malformed_serializer_items() -> void:
	var target: Node2D = Node2D.new()
	var source: GFPersistPropertiesSource = GFPersistPropertiesSource.new()
	target.add_child(source)
	_scope.add_child(target)
	source.properties = PackedStringArray(["position"])

	var result: Dictionary = source._apply_save_data({"serializers": ["malformed"]})
	var errors: Array = GFVariantData.get_option_array(result, "errors")

	assert_false(GFVariantData.get_option_bool(result, "ok", true), "属性 serializer 路径不得吞掉畸形项。")
	assert_eq(errors.size(), 1)
	if not errors.is_empty():
		assert_string_contains(GFVariantData.to_text(errors[0]), "index 0")


func test_persist_properties_source_rejects_cross_origin_serializer_id_conflicts() -> void:
	var target: Node = Node.new()
	target.name = "Target"
	_scope.add_child(target)
	var source: GFPersistPropertiesSource = GFPersistPropertiesSource.new()
	source.name = "State"
	source.source_key = &"state"
	source.use_registry_serializers = true
	var local_serializer: GFNodeSerializer = GFNodeSerializer.new()
	local_serializer.serializer_id = &"project.same"
	var registry_serializer: GFNodeSerializer = GFNodeSerializer.new()
	registry_serializer.serializer_id = &"project.same"
	source.serializers = [local_serializer]
	target.add_child(source)
	_utility.serializer_registry.register_serializer(registry_serializer)
	var pipeline_context: GFSavePipelineContext = _utility.create_pipeline_context(
		&"gather",
		_scope
	)

	var payload: Dictionary = _utility.gather_scope(_scope, {
		"pipeline_context": pipeline_context,
	})
	var apply_result: Dictionary = source._apply_save_data({
		"serializers": [{
			"id": &"project.same",
			"data": {},
		}],
	}, {}, _utility.serializer_registry)

	assert_true(payload.is_empty(), "冲突 serializer plan 不得生成可落盘 Source payload。")
	assert_gt(pipeline_context.errors.size(), 0)
	assert_true(GFVariantData.to_text(pipeline_context.errors).contains("project.same"))
	assert_false(GFVariantData.get_option_bool(apply_result, "ok"))
	assert_true(
		GFVariantData.to_text(GFVariantData.get_option_array(apply_result, "errors")).contains(
			"project.same"
		),
		"apply 必须在选择 codec 前拒绝同 ID 冲突。"
	)


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
