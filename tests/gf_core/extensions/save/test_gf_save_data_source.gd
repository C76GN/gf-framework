## 测试 GFSaveDataSource 的通用对象数据源适配。
extends GutTest


# --- 常量 ---



# --- 辅助类 ---

class PayloadResource extends Resource:
	var value: int = 0
	var apply_count: int = 0

	func to_dict() -> Dictionary:
		return {
			"value": value,
		}

	func from_dict(data: Dictionary) -> void:
		value = GFVariantData.get_option_int(data, "value")
		apply_count += 1


class PayloadHolder extends Node:
	@export var payload: Resource = null


class ObjectPayloadHolder extends Node:
	var payload_object: Object = null


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

## 验证直接 Resource 数据对象可通过 SaveGraph 采集并恢复。
func test_direct_resource_roundtrips_through_save_graph() -> void:
	var model: PayloadResource = PayloadResource.new()
	model.value = 7
	var source: GFSaveDataSource = _make_data_source(&"model")
	source.data = model
	_scope.add_child(source)

	var payload: Dictionary = _utility.gather_scope(_scope)
	model.value = 1
	var result: Dictionary = _utility.apply_scope(_scope, payload)

	assert_true(GFVariantData.get_option_bool(result, "ok"), "Resource 数据源应可成功应用。")
	assert_eq(GFVariantData.get_option_int(_get_source_data(payload, "model"), "value"), 7, "采集载荷应来自数据对象。")
	assert_eq(model.value, 7, "应用后 Resource 状态应恢复。")
	assert_eq(model.apply_count, 1, "数据对象应用方法应被调用一次。")


## 验证目标节点属性上的数据对象可作为 Source provider。
func test_target_property_provider_roundtrips_through_save_graph() -> void:
	var model: PayloadResource = PayloadResource.new()
	model.value = 42
	var holder: PayloadHolder = PayloadHolder.new()
	holder.name = "Holder"
	holder.payload = model
	_scope.add_child(holder)

	var source: GFSaveDataSource = _make_data_source(&"holder_model")
	source.target_node_path = NodePath("../Holder")
	source.provider_property = &"payload"
	_scope.add_child(source)

	var payload: Dictionary = _utility.gather_scope(_scope)
	model.value = 0
	var result: Dictionary = _utility.apply_scope(_scope, payload)

	assert_true(GFVariantData.get_option_bool(result, "ok"), "目标属性数据源应可成功应用。")
	assert_eq(GFVariantData.get_option_int(_get_source_data(payload, "holder_model"), "value"), 42, "采集载荷应来自目标属性。")
	assert_eq(model.value, 42, "应用后目标属性对象状态应恢复。")


## 验证描述信息能报告缺失 provider，且不执行项目采集方法。
func test_describe_source_reports_missing_provider() -> void:
	var source: GFSaveDataSource = _make_data_source(&"missing_provider")
	source.target_node_path = NodePath("../Missing")
	_scope.add_child(source)

	var descriptor: Dictionary = source.describe_source(_scope)
	var data_provider: Dictionary = GFVariantData.get_option_dictionary(descriptor, "data_provider")

	assert_eq(GFVariantData.get_option_string(descriptor, "kind"), "data", "DataSource 描述应声明数据源类型。")
	assert_false(GFVariantData.get_option_bool(data_provider, "valid"), "缺失 provider 时诊断应为无效。")
	assert_eq(GFVariantData.get_option_string(data_provider, "reason"), "missing_target", "诊断应指出目标节点缺失。")


## 验证采集协议缺失时写入流程错误，便于调试面板或测试捕获。
func test_missing_gather_method_records_pipeline_error() -> void:
	var source: GFSaveDataSource = _make_data_source(&"bad_model")
	source.data = Resource.new()
	source.gather_method = &"missing_to_dict"
	_scope.add_child(source)
	var pipeline_context: GFSavePipelineContext = _utility.create_pipeline_context(&"gather", _scope)

	var _gather_scope_result_118: Variant = _utility.gather_scope(_scope, {
		"pipeline_context": pipeline_context,
	})

	assert_gt(pipeline_context.errors.size(), 0, "缺失采集方法应写入流程错误。")
	assert_true(
		String(pipeline_context.errors[0]).contains("gather method"),
		"流程错误应说明缺失采集方法。"
	)


func test_freed_property_provider_is_rejected_without_calling_protocol_methods() -> void:
	var provider: Node = Node.new()
	var holder: ObjectPayloadHolder = ObjectPayloadHolder.new()
	holder.name = "Holder"
	holder.payload_object = provider
	_scope.add_child(holder)
	provider.free()

	var source: GFSaveDataSource = _make_data_source(&"freed_provider")
	source.target_node_path = NodePath("../Holder")
	source.provider_property = &"payload_object"
	_scope.add_child(source)
	var pipeline_context: GFSavePipelineContext = _utility.create_pipeline_context(&"gather", _scope)

	var payload: Variant = source._gather_save_data({
		"pipeline_context": pipeline_context,
	})
	var descriptor: Dictionary = source.describe_data_provider()

	assert_true(GFVariantData.as_dictionary(payload).is_empty(), "已释放 provider 不应产生有效载荷。")
	assert_eq(GFVariantData.get_option_string(descriptor, "reason"), "invalid_property_object", "诊断应明确属性对象已失效。")
	assert_gt(pipeline_context.errors.size(), 0, "已释放 provider 应记录流程错误。")


## 验证应用载荷必须是 Dictionary。
func test_apply_rejects_non_dictionary_payload() -> void:
	var source: GFSaveDataSource = _make_data_source(&"model")
	source.data = PayloadResource.new()

	var result: Dictionary = source._apply_save_data("bad")

	assert_false(GFVariantData.get_option_bool(result, "ok"), "非 Dictionary 载荷不应被应用。")
	assert_true(GFVariantData.get_option_string(result, "error").contains("Dictionary"), "错误应指出载荷类型要求。")
	source.free()


# --- 私有/辅助方法 ---

func _make_data_source(source_key: StringName) -> GFSaveDataSource:
	var source: GFSaveDataSource = GFSaveDataSource.new()
	source.name = String(source_key)
	source.source_key = source_key
	return source


func _get_source_data(payload: Dictionary, source_key: String) -> Dictionary:
	var sources: Dictionary = GFVariantData.get_option_dictionary(payload, "sources")
	var source_payload: Dictionary = GFVariantData.get_option_dictionary(sources, source_key)
	return GFVariantData.get_option_dictionary(source_payload, "data")
