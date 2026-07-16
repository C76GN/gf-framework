## 测试 GFSaveGraphUtility 的通用 Scope/Source 编排。
extends GutTest


# --- 常量 ---



# --- 辅助类 ---

class MetadataPipelineStep extends GFSavePipelineStep:
	func _after_gather_scope(_scope: GFSaveScope, payload: Dictionary, _context: Dictionary = {}) -> Variant:
		payload["pipeline_marker"] = "applied"
		return payload


class PlainEntityFactory extends GFSaveEntityFactory:
	var created_entity: Node = null

	func _init() -> void:
		type_key = &"plain_entity"

	func _create_entity(_descriptor: Dictionary, _context: Dictionary = {}) -> Node:
		created_entity = Node.new()
		created_entity.name = "PlainEntity"
		return created_entity


class FailingCreatedSource extends GFSaveSource:
	func _apply_save_data(
		_data: Variant,
		_context: Dictionary = {},
		_serializer_registry: GFNodeSerializerRegistry = null
	) -> Dictionary:
		return make_result(false, "created_failed")


class FailingSourceFactory extends GFSaveEntityFactory:
	var created_source: FailingCreatedSource = null
	var create_count: int = 0

	func _init() -> void:
		type_key = &"failing_source"

	func _create_entity(descriptor: Dictionary, _context: Dictionary = {}) -> Node:
		create_count += 1
		created_source = FailingCreatedSource.new()
		created_source.name = GFVariantData.get_option_string(descriptor, "source_key", "created_source")
		created_source.source_key = GFVariantData.get_option_string_name(descriptor, "source_key", &"created_source")
		return created_source


class DeletingAfterCreateFactory extends GFSaveEntityFactory:
	var created_source: GFSaveSource = null

	func _init() -> void:
		type_key = &"deleting_source"

	func _create_entity(descriptor: Dictionary, _context: Dictionary = {}) -> Node:
		created_source = GFSaveSource.new()
		created_source.name = GFVariantData.get_option_string(descriptor, "source_key", "deleted_source")
		created_source.source_key = GFVariantData.get_option_string_name(descriptor, "source_key", &"deleted_source")
		return created_source

	func _after_entity_created(entity: Node, _descriptor: Dictionary, _context: Dictionary = {}) -> void:
		var parent: Node = entity.get_parent()
		if parent != null:
			parent.remove_child(entity)
		entity.free()


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


class MethodTrapSaveSource extends GFSaveSource:
	var get_source_key_called: bool = false
	var get_target_node_called: bool = false
	var can_save_source_called: bool = false
	var can_load_source_called: bool = false

	func get_source_key() -> StringName:
		get_source_key_called = true
		return &"method_source"

	func get_target_node() -> Node:
		get_target_node_called = true
		return null

	func _can_save_source(_context: Dictionary = {}) -> bool:
		can_save_source_called = true
		return false

	func _can_load_source(_context: Dictionary = {}) -> bool:
		can_load_source_called = true
		return false


class NodeReferencePropertyNode extends Node:
	var node_value: Node = null


	func _get_property_list() -> Array[Dictionary]:
		return [{
			"name": "node_value",
			"type": TYPE_OBJECT,
			"class_name": "Node",
			"usage": PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_STORAGE,
		}]


	func _get(property: StringName) -> Variant:
		if property == &"node_value":
			return node_value
		return null


	func _set(property: StringName, value: Variant) -> bool:
		if property == &"node_value":
			if value != null and not value is Node:
				return false
			node_value = null
			if value is Node:
				node_value = value
			return true
		return false


class RecordingApplySource extends GFSaveSource:
	var order: Array[String] = []

	func _init(p_source_key: StringName, p_order: Array[String]) -> void:
		name = String(p_source_key)
		source_key = p_source_key
		order = p_order

	func _apply_save_data(
		_data: Variant,
		_context: Dictionary = {},
		_serializer_registry: GFNodeSerializerRegistry = null
	) -> Dictionary:
		order.append(String(source_key))
		return make_result(true)


class RecordingTransactionParticipant extends GFSaveTransactionParticipant:
	var order: Array[String] = []
	var prepare_ok: bool = true
	var commit_ok: bool = true
	var rollback_ok: bool = true

	func _init(p_participant_id: StringName = &"external", p_order: Array[String] = []) -> void:
		participant_id = p_participant_id
		order = p_order

	func _prepare_transaction(_context: Dictionary = {}) -> Dictionary:
		order.append("prepare:%s" % String(participant_id))
		var errors: Array[String] = []
		if not prepare_ok:
			errors.append("prepare_failed")
		return make_result(prepare_ok, errors)

	func _commit_transaction(_context: Dictionary = {}) -> Dictionary:
		order.append("commit:%s" % String(participant_id))
		var errors: Array[String] = []
		if not commit_ok:
			errors.append("commit_failed")
		return make_result(commit_ok, errors)

	func _rollback_transaction(_context: Dictionary = {}) -> Dictionary:
		order.append("rollback:%s" % String(participant_id))
		var errors: Array[String] = []
		if not rollback_ok:
			errors.append("rollback_failed")
		return make_result(rollback_ok, errors)


class TransactionParticipantSource extends GFSaveSource:
	var participant: GFSaveTransactionParticipant = null

	func _init(p_source_key: StringName = &"", p_participant: GFSaveTransactionParticipant = null) -> void:
		name = String(p_source_key)
		source_key = p_source_key
		participant = p_participant

	func _apply_save_data(
		_data: Variant,
		context: Dictionary = {},
		_serializer_registry: GFNodeSerializerRegistry = null
	) -> Dictionary:
		var pipeline_context_variant: Variant = GFVariantData.get_option_value(context, "pipeline_context")
		if participant != null and pipeline_context_variant is GFSavePipelineContext:
			var pipeline_context: GFSavePipelineContext = pipeline_context_variant
			pipeline_context.register_transaction_participant(participant)
		return make_result(true)


class RecordingAfterLoadScope extends GFSaveScope:
	var order: Array[String] = []

	func _init(p_scope_key: StringName, p_order: Array[String]) -> void:
		name = String(p_scope_key)
		scope_key = p_scope_key
		order = p_order

	func _after_load(_payload: Dictionary, _context: Dictionary = {}) -> void:
		order.append("after_scope:%s" % String(scope_key))


class RecordingAfterLoadSource extends GFSaveSource:
	var order: Array[String] = []
	var participant: GFSaveTransactionParticipant = null

	func _init(
		p_source_key: StringName,
		p_order: Array[String],
		p_participant: GFSaveTransactionParticipant = null
	) -> void:
		name = String(p_source_key)
		source_key = p_source_key
		order = p_order
		participant = p_participant

	func _apply_save_data(
		_data: Variant,
		context: Dictionary = {},
		_serializer_registry: GFNodeSerializerRegistry = null
	) -> Dictionary:
		order.append("apply:%s" % String(source_key))
		var pipeline_context_variant: Variant = GFVariantData.get_option_value(context, "pipeline_context")
		if participant != null and pipeline_context_variant is GFSavePipelineContext:
			var pipeline_context: GFSavePipelineContext = pipeline_context_variant
			pipeline_context.register_transaction_participant(participant)
		return make_result(true)

	func _after_load(_data: Variant, _context: Dictionary = {}) -> void:
		order.append("after_source:%s" % String(source_key))


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

func test_save_scope_rejects_unsafe_values_at_persisted_boundary() -> void:
	var architecture: GFArchitecture = GFArchitecture.new()
	var storage: GFStorageUtility = GFStorageUtility.new()
	storage.save_dir_name = "test_save_graph_persisted_preflight"
	storage.init()
	var registered_storage: bool = await architecture.register_utility(GFStorageUtility, storage)
	assert_true(registered_storage, "测试架构应能注册 storage。")
	_utility.inject_dependencies(architecture)
	var unsafe_object: RefCounted = RefCounted.new()

	var save_error: Error = _utility.save_scope("unsafe_graph.sav", _scope, {"unsafe": unsafe_object})

	assert_eq(save_error, ERR_INVALID_DATA, "Save Graph 的持久化入口不得把 Object 静默转换为 null。")
	assert_false(FileAccess.file_exists(storage.get_storage_directory_path("").path_join("unsafe_graph.sav")))
	assert_push_error("[GFSaveGraphUtility] save_scope 失败：payload")
	var _delete_result: Error = storage.delete_file("unsafe_graph.sav")
	_utility.release_dependencies()
	architecture.dispose()


## 验证默认 Transform2D 序列化器可采集并恢复节点状态。
func test_gather_and_apply_transform_2d_source() -> void:
	var target: Node2D = Node2D.new()
	target.name = "Target"
	target.position = Vector2(12.0, -3.0)
	target.rotation = 0.75
	target.scale = Vector2(2.0, 3.0)
	_scope.add_child(target)

	var source: GFSaveSource = _make_source(&"target_state", NodePath("../Target"))
	_scope.add_child(source)

	var payload: Dictionary = _utility.gather_scope(_scope)
	target.position = Vector2.ZERO
	target.rotation = 0.0
	target.scale = Vector2.ONE

	var result: Dictionary = _utility.apply_scope(_scope, payload)

	assert_true(GFVariantData.get_option_bool(result, "ok"), "应用存档图应成功。")
	assert_eq(target.position, Vector2(12.0, -3.0), "Transform2D position 应被恢复。")
	assert_almost_eq(target.rotation, 0.75, 0.001, "Transform2D rotation 应被恢复。")
	assert_eq(target.scale, Vector2(2.0, 3.0), "Transform2D scale 应被恢复。")


func test_apply_scope_rejects_corrupted_transform_payload_before_mutating() -> void:
	var target: Node2D = Node2D.new()
	target.name = "Target"
	target.position = Vector2(1.0, 2.0)
	_scope.add_child(target)
	_scope.add_child(_make_source(&"target_state", NodePath("../Target")))
	var payload: Dictionary = {
		"format": GFSaveGraphUtility.FORMAT_ID,
		"format_version": GFSaveGraphUtility.FORMAT_VERSION,
		"scope": _scope.describe_scope(),
		"sources": {
			"target_state": {
				"descriptor": {},
				"data": {
					"serializers": [{
						"id": &"gf.transform_2d",
						"data": {
							"position": "corrupted",
						},
					}],
				},
			},
		},
		"scopes": {},
	}

	var result: Dictionary = _utility.apply_scope(_scope, payload)

	assert_false(GFVariantData.get_option_bool(result, "ok"), "损坏的默认 serializer 载荷不应被静默应用。")
	assert_eq(target.position, Vector2(1.0, 2.0), "应用失败时不应把坏载荷写入节点。")


func test_persist_properties_source_restores_node_reference_with_scope_root() -> void:
	var target: Node = Node.new()
	target.name = "Target"
	_scope.add_child(target)
	var holder: NodeReferencePropertyNode = NodeReferencePropertyNode.new()
	holder.name = "Holder"
	holder.node_value = target
	_scope.add_child(holder)
	var source: GFPersistPropertiesSource = GFPersistPropertiesSource.new()
	source.name = "HolderSource"
	source.source_key = &"holder"
	source.target_node_path = NodePath("../Holder")
	source.properties = PackedStringArray(["node_value"])
	_scope.add_child(source)

	var payload: Dictionary = _utility.gather_scope(_scope)
	holder.node_value = null
	var result: Dictionary = _utility.apply_scope(_scope, payload)

	assert_true(GFVariantData.get_option_bool(result, "ok"), "SaveGraph 应为属性序列化器提供当前 Scope 作为引用 root。")
	assert_same(holder.node_value, target, "Node 属性应按当前 Scope 下的 NodePath 恢复。")


## 验证子 Scope 会独立写入嵌套载荷。
func test_nested_scope_is_gathered_separately() -> void:
	var child_scope: GFSaveScope = GFSaveScope.new()
	child_scope.name = "ChildScope"
	child_scope.scope_key = &"child"
	_scope.add_child(child_scope)

	var target: Node2D = Node2D.new()
	target.name = "ChildTarget"
	target.position = Vector2(5.0, 6.0)
	child_scope.add_child(target)
	child_scope.add_child(_make_source(&"child_state", NodePath("../ChildTarget")))

	var payload: Dictionary = _utility.gather_scope(_scope)

	var scopes_payload: Dictionary = GFVariantData.get_option_dictionary(payload, "scopes")
	var child_payload: Dictionary = GFVariantData.get_option_dictionary(scopes_payload, "child")
	var child_sources: Dictionary = GFVariantData.get_option_dictionary(child_payload, "sources")
	assert_true(scopes_payload.has("child"), "子 Scope 应写入 scopes 字典。")
	assert_true(child_sources.has("child_state"), "子 Scope 内的 Source 应写入子载荷。")


## 验证默认 UI 序列化器可采集并恢复 Control/Range 通用状态。
func test_default_ui_serializers_restore_control_and_range_state() -> void:
	var slider: HSlider = HSlider.new()
	slider.name = "Slider"
	slider.value = 42.0
	slider.min_value = 0.0
	slider.max_value = 100.0
	slider.visible = false
	slider.offset_left = 12.0
	_scope.add_child(slider)

	var source: GFSaveSource = _make_source(&"slider_state", NodePath("../Slider"))
	_scope.add_child(source)

	var payload: Dictionary = _utility.gather_scope(_scope)
	slider.value = 0.0
	slider.visible = true
	slider.offset_left = 0.0

	var result: Dictionary = _utility.apply_scope(_scope, payload)

	assert_true(GFVariantData.get_option_bool(result, "ok"), "应用 UI 存档图应成功。")
	assert_almost_eq(slider.value, 42.0, 0.001, "Range value 应恢复。")
	assert_false(slider.visible, "CanvasItem visible 应恢复。")
	assert_almost_eq(slider.offset_left, 12.0, 0.001, "Control offset 应恢复。")


## 验证默认 Timer 序列化器可恢复计时器通用状态。
func test_default_timer_serializer_restores_timer_state() -> void:
	var timer: Timer = Timer.new()
	timer.name = "Timer"
	timer.wait_time = 2.5
	timer.one_shot = true
	timer.autostart = false
	timer.paused = true
	_scope.add_child(timer)

	var source: GFSaveSource = _make_source(&"timer_state", NodePath("../Timer"))
	_scope.add_child(source)

	var payload: Dictionary = _utility.gather_scope(_scope)
	timer.wait_time = 1.0
	timer.one_shot = false
	timer.paused = false

	var result: Dictionary = _utility.apply_scope(_scope, payload)

	assert_true(GFVariantData.get_option_bool(result, "ok"), "应用 Timer 存档图应成功。")
	assert_almost_eq(timer.wait_time, 2.5, 0.001, "Timer wait_time 应恢复。")
	assert_true(timer.one_shot, "Timer one_shot 应恢复。")
	assert_true(timer.paused, "Timer paused 应恢复。")


## 验证默认 AudioStreamPlayer 序列化器可恢复播放参数。
func test_default_audio_stream_player_serializer_restores_audio_state() -> void:
	var player: AudioStreamPlayer = AudioStreamPlayer.new()
	player.name = "Audio"
	player.stream = AudioStreamGenerator.new()
	player.volume_db = -12.0
	player.pitch_scale = 1.25
	_scope.add_child(player)
	player.play()
	player.stream_paused = true

	var source: GFSaveSource = _make_source(&"audio_state", NodePath("../Audio"))
	_scope.add_child(source)

	var payload: Dictionary = _utility.gather_scope(_scope)
	player.volume_db = 0.0
	player.pitch_scale = 1.0
	player.stream_paused = false

	var result: Dictionary = _utility.apply_scope(_scope, payload)

	assert_true(GFVariantData.get_option_bool(result, "ok"), "应用 AudioStreamPlayer 存档图应成功。")
	assert_almost_eq(player.volume_db, -12.0, 0.001, "Audio volume_db 应恢复。")
	assert_almost_eq(player.pitch_scale, 1.25, 0.001, "Audio pitch_scale 应恢复。")
	assert_true(player.stream_paused, "Audio stream_paused 应恢复。")


## 验证存档 pipeline 可在采集后追加通用载荷。
func test_pipeline_step_can_modify_gathered_payload() -> void:
	_utility.add_pipeline_step(MetadataPipelineStep.new())

	var payload: Dictionary = _utility.gather_scope(_scope)

	assert_eq(GFVariantData.get_option_string(payload, "pipeline_marker"), "applied", "pipeline step 应能修改采集载荷。")


## 验证存档流程可按需输出通用 trace。
func test_gather_scope_can_include_pipeline_trace() -> void:
	var payload: Dictionary = _utility.gather_scope(_scope, { "include_pipeline_trace": true })
	var trace: Dictionary = GFVariantData.get_option_dictionary(payload, "pipeline_trace")

	assert_false(trace.is_empty(), "启用 include_pipeline_trace 时应写入流程 trace。")
	assert_eq(GFVariantData.get_option_string_name(trace, "operation"), &"gather", "trace 应记录 gather 操作。")
	assert_gt(GFVariantData.get_option_int(trace, "event_count"), 0, "trace 应包含流程事件。")
	assert_true(_has_trace_stage(trace, &"gather_scope_finished"), "trace 应记录 Scope 完成阶段。")


func test_pipeline_trace_export_is_json_safe() -> void:
	var pipeline_context: GFSavePipelineContext = _utility.create_pipeline_context(&"gather", _scope, {
		"owner": self,
	})
	pipeline_context.add_warning("debug", {
		"owner": self,
	})

	var trace: Dictionary = pipeline_context.to_dict(true)
	var trace_json: String = JSON.stringify(trace)
	var shared_owner: Dictionary = GFVariantData.get_option_dictionary(
		GFVariantData.get_option_dictionary(trace, "shared"),
		"owner"
	)
	var first_event: Dictionary = GFVariantData.as_dictionary(GFVariantData.get_option_array(trace, "events")[0])
	var event_owner: Dictionary = GFVariantData.get_option_dictionary(
		GFVariantData.get_option_dictionary(first_event, "payload"),
		"owner"
	)

	assert_false(trace_json.is_empty(), "pipeline trace 应可直接 JSON.stringify。")
	assert_true(shared_owner.has("__gf_report_value__"), "shared 中的 Object 应被转为报告 marker。")
	assert_true(event_owner.has("__gf_report_value__"), "event payload 中的 Object 应被转为报告 marker。")


## 验证调用方也可以显式传入流程上下文并在外部读取。
func test_pipeline_context_can_be_shared_by_caller() -> void:
	var pipeline_context: GFSavePipelineContext = _utility.create_pipeline_context(&"gather", _scope, { "source": "test" })

	var _gather_scope_result_295: Variant = _utility.gather_scope(_scope, { "pipeline_context": pipeline_context })

	assert_eq(pipeline_context.operation, &"gather", "外部上下文应保留操作类型。")
	assert_eq(GFVariantData.get_option_string(pipeline_context.shared, "source"), "test", "外部上下文应保留共享数据。")
	assert_gt(pipeline_context.events.size(), 0, "外部上下文应收集流程事件。")


## 验证通用槽位工作流能构建元数据和卡片。
func test_save_slot_workflow_builds_metadata_and_card() -> void:
	var workflow: GFSaveSlotWorkflow = GFSaveSlotWorkflow.new()
	workflow.active_slot_index = 2
	workflow.slot_role = &"manual"

	var metadata: GFSaveSlotMetadata = workflow.build_active_metadata("", { "score": 10 })
	var summary: Dictionary = {
		"slot_id": 2,
		"metadata": metadata.to_dict(true),
		"modified_time": 123,
	}
	var card: GFSaveSlotCard = workflow.build_card_for_index(2, summary)

	assert_eq(metadata.slot_id, &"slot_2", "槽位元数据应按模板生成逻辑标识。")
	assert_eq(metadata.display_name, "", "槽位元数据默认不应生成 UI 展示名。")
	assert_eq(GFVariantData.get_option_int(metadata.custom_metadata, "score"), 10, "槽位元数据应保留项目自定义字段。")
	assert_eq(GFVariantData.get_option_string_name(metadata.custom_metadata, "slot_role"), &"manual", "槽位角色应写入自定义元数据。")
	assert_false(card.is_empty, "已有摘要应生成非空卡片。")
	assert_true(card.is_active, "当前槽位卡片应标记为 active。")


## 验证槽位工作流可从逻辑 slot_id 反推索引。
func test_save_slot_workflow_indexes_string_slot_ids() -> void:
	var workflow: GFSaveSlotWorkflow = GFSaveSlotWorkflow.new()
	var metadata: GFSaveSlotMetadata = workflow.build_slot_metadata(3, "Slot 3")
	var summaries: Array = [{
		"slot_id": metadata.slot_id,
		"metadata": metadata.to_dict(true),
		"modified_time": 123,
	}]

	var cards: Array[GFSaveSlotCard] = workflow.build_cards_for_indices([3], summaries)
	var auto_cards: Array[GFSaveSlotCard] = workflow.build_cards_for_indices([], summaries)

	assert_eq(cards.size(), 1, "显式索引应能命中字符串 slot_id 摘要。")
	assert_false(cards[0].is_empty, "字符串 slot_id 摘要不应被误判为空槽。")
	assert_eq(cards[0].slot_index, 3, "字符串 slot_id 摘要应正确写入卡片整数索引。")
	assert_eq(auto_cards.size(), 0, "空索引入口不应隐式推导槽位；应由显式 slot store 入口负责枚举。")


## 验证 Scope 诊断会报告同作用域重复 Source key。
func test_inspect_scope_reports_duplicate_source_keys() -> void:
	var target_a: Node2D = Node2D.new()
	target_a.name = "TargetA"
	_scope.add_child(target_a)
	var target_b: Node2D = Node2D.new()
	target_b.name = "TargetB"
	_scope.add_child(target_b)
	_scope.add_child(_make_source(&"state", NodePath("../TargetA")))
	_scope.add_child(_make_source(&"state", NodePath("../TargetB")))

	var report: Dictionary = _utility.inspect_scope(_scope)

	assert_false(GFVariantData.get_option_bool(report, "ok"), "重复 Source key 应使诊断报告失败。")
	assert_false(GFVariantData.get_option_bool(report, "healthy"), "存在错误时健康状态应失败。")
	assert_gt(GFVariantData.get_option_int(report, "error_count"), 0, "健康报告应统计错误数量。")
	assert_false(GFVariantData.get_option_string(report, "next_action").is_empty(), "健康报告应提供下一步建议。")
	assert_true(_has_issue(report, "duplicate_source_key"), "诊断报告应包含 duplicate_source_key。")


## 验证 Scope 健康报告会给出摘要与无操作建议。
func test_scope_health_report_includes_summary_for_valid_scope() -> void:
	var report: Dictionary = _utility.build_scope_health_report(_scope)

	assert_true(GFVariantData.get_option_bool(report, "ok"), "有效 Scope 应通过检查。")
	assert_true(GFVariantData.get_option_bool(report, "healthy"), "无警告和错误时应为健康。")
	assert_eq(GFVariantData.get_option_int(report, "error_count"), 0, "有效 Scope 不应有错误。")
	assert_eq(GFVariantData.get_option_int(report, "warning_count"), 0, "有效 Scope 不应有警告。")
	assert_eq(GFVariantData.get_option_string(report, "next_action"), "No action required.", "健康报告无需后续动作。")
	assert_true(GFVariantData.get_option_string(report, "summary").contains("healthy"), "健康报告应包含摘要。")


func test_inspect_scope_reads_exports_without_calling_save_methods() -> void:
	var scope: MethodTrapSaveScope = MethodTrapSaveScope.new()
	scope.name = "TrapScope"
	scope.scope_key = &"export_scope"
	scope.load_enabled = false
	var source: MethodTrapSaveSource = MethodTrapSaveSource.new()
	source.name = "TrapSource"
	source.source_key = &"export_source"
	source.save_enabled = false
	scope.add_child(source)

	var report: Dictionary = _utility.inspect_scope(scope)
	var scopes: Array = GFVariantData.get_option_array(report, "scopes")
	var sources: Array = GFVariantData.get_option_array(report, "sources")
	var scope_entry: Dictionary = GFVariantData.as_dictionary(scopes[0])
	var source_entry: Dictionary = GFVariantData.as_dictionary(sources[0])

	assert_eq(GFVariantData.get_option_string(report, "scope_key"), "export_scope", "诊断应读取导出的 scope_key。")
	assert_eq(GFVariantData.get_option_string(scope_entry, "key"), "export_scope", "Scope 条目应使用导出标识。")
	assert_false(GFVariantData.get_option_bool(scope_entry, "can_load", true), "Scope 条目应读取导出的 load_enabled。")
	assert_eq(GFVariantData.get_option_string(source_entry, "key"), "export_source", "Source 条目应使用导出标识。")
	assert_false(GFVariantData.get_option_bool(source_entry, "can_save", true), "Source 条目应读取导出的 save_enabled。")
	assert_false(scope.get_scope_key_called, "编辑器诊断不应调用 Scope 方法，避免 placeholder 报错。")
	assert_false(scope.can_save_scope_called, "编辑器诊断不应调用 Scope 保存判断方法。")
	assert_false(scope.can_load_scope_called, "编辑器诊断不应调用 Scope 加载判断方法。")
	assert_false(scope.describe_scope_called, "编辑器诊断不应调用 Scope 描述方法。")
	assert_false(source.get_source_key_called, "编辑器诊断不应调用 Source 方法，避免 placeholder 报错。")
	assert_false(source.get_target_node_called, "编辑器诊断不应调用 Source 目标方法。")
	assert_false(source.can_save_source_called, "编辑器诊断不应调用 Source 保存判断方法。")
	assert_false(source.can_load_source_called, "编辑器诊断不应调用 Source 加载判断方法。")

	scope.free()


func test_payload_validation_reads_exports_without_calling_save_methods() -> void:
	var scope: MethodTrapSaveScope = MethodTrapSaveScope.new()
	scope.name = "TrapScope"
	scope.scope_key = &"export_scope"
	var source: MethodTrapSaveSource = MethodTrapSaveSource.new()
	source.name = "TrapSource"
	source.source_key = &"export_source"
	scope.add_child(source)
	var payload: Dictionary = {
		"format": GFSaveGraphUtility.FORMAT_ID,
		"format_version": GFSaveGraphUtility.FORMAT_VERSION,
		"scope": {
			"scope_key": "export_scope",
		},
		"sources": {
			"export_source": {
				"descriptor": {},
				"data": {},
			},
		},
		"scopes": {},
	}

	var pipeline_context: GFSavePipelineContext = _utility.create_pipeline_context(&"validate", scope)
	var report: Dictionary = _utility.validate_payload_for_scope(scope, payload, true)

	assert_eq(pipeline_context.root_scope_key, &"export_scope", "PipelineContext 应读取导出的 scope_key。")
	assert_true(GFVariantData.get_option_bool(report, "ok"), "载荷校验应能通过导出属性匹配 Source。")
	assert_eq(GFVariantData.get_option_string(report, "scope_key"), "export_scope", "载荷校验应读取导出的 scope_key。")
	assert_eq(GFVariantData.get_option_int(report, "checked_source_count"), 1, "载荷校验应检查导出的 Source key。")
	assert_false(scope.get_scope_key_called, "载荷校验不应调用 Scope 方法。")
	assert_false(scope.can_save_scope_called, "载荷校验不应调用 Scope 保存判断方法。")
	assert_false(scope.can_load_scope_called, "载荷校验不应调用 Scope 加载判断方法。")
	assert_false(scope.describe_scope_called, "载荷校验不应调用 Scope 描述方法。")
	assert_false(source.get_source_key_called, "载荷校验不应调用 Source 方法。")
	assert_false(source.get_target_node_called, "载荷校验不应调用 Source 目标方法。")
	assert_false(source.can_save_source_called, "载荷校验不应调用 Source 保存判断方法。")
	assert_false(source.can_load_source_called, "载荷校验不应调用 Source 加载判断方法。")

	scope.free()


func test_payload_validation_rejects_invalid_source_data_without_mutation() -> void:
	var payload: Dictionary = {
		"format": GFSaveGraphUtility.FORMAT_ID,
		"format_version": GFSaveGraphUtility.FORMAT_VERSION,
		"scope": _scope.describe_scope(),
		"sources": {
			"state": {
				"descriptor": {},
				"data": "bad",
			},
		},
		"scopes": {},
	}
	_scope.add_child(_make_source(&"state", NodePath("")))

	var report: Dictionary = _utility.validate_payload_for_scope(_scope, payload, true)
	var issue_counts: Dictionary = GFVariantData.get_option_dictionary(report, "issue_counts_by_kind")

	assert_false(GFVariantData.get_option_bool(report, "ok"), "坏 source data 应在 validate 阶段被拒绝。")
	assert_eq(GFVariantData.get_option_int(issue_counts, "invalid_source_data"), 1, "validate 报告应明确 invalid_source_data。")


func test_payload_validation_rejects_scope_descriptor_mismatch() -> void:
	var payload: Dictionary = {
		"format": GFSaveGraphUtility.FORMAT_ID,
		"format_version": GFSaveGraphUtility.FORMAT_VERSION,
		"scope": {
			"scope_key": "other_scope",
		},
		"sources": {},
		"scopes": {},
	}

	var report: Dictionary = _utility.validate_payload_for_scope(_scope, payload, true)
	var issue_counts: Dictionary = GFVariantData.get_option_dictionary(report, "issue_counts_by_kind")

	assert_false(GFVariantData.get_option_bool(report, "ok"), "scope descriptor 不匹配应在 validate 阶段被拒绝。")
	assert_eq(GFVariantData.get_option_int(issue_counts, "scope_key_mismatch"), 1, "validate 报告应明确 scope_key_mismatch。")


## 验证采集重复 Source key 会失败，避免产生无法回放的 key#2 载荷。
func test_gather_scope_rejects_duplicate_source_keys() -> void:
	var target_a: Node2D = Node2D.new()
	target_a.name = "TargetA"
	_scope.add_child(target_a)
	var target_b: Node2D = Node2D.new()
	target_b.name = "TargetB"
	_scope.add_child(target_b)
	_scope.add_child(_make_source(&"state", NodePath("../TargetA")))
	_scope.add_child(_make_source(&"state", NodePath("../TargetB")))

	var payload: Dictionary = _utility.gather_scope(_scope)

	assert_true(payload.is_empty(), "重复 Source key 不应生成存档载荷。")
	assert_push_error("[GFSaveGraphUtility] gather_scope 失败：同一 Scope 内存在重复 Source key：state")


## 验证子 Scope 采集失败会传播到父 Scope，而不是被当作空子树跳过。
func test_gather_scope_rejects_child_scope_failures() -> void:
	var child_scope: GFSaveScope = GFSaveScope.new()
	child_scope.name = "ChildScope"
	child_scope.scope_key = &"child"
	_scope.add_child(child_scope)

	var target_a: Node2D = Node2D.new()
	target_a.name = "TargetA"
	child_scope.add_child(target_a)
	var target_b: Node2D = Node2D.new()
	target_b.name = "TargetB"
	child_scope.add_child(target_b)
	child_scope.add_child(_make_source(&"state", NodePath("../TargetA")))
	child_scope.add_child(_make_source(&"state", NodePath("../TargetB")))
	var pipeline_context: GFSavePipelineContext = _utility.create_pipeline_context(&"gather", _scope)

	var payload: Dictionary = _utility.gather_scope(_scope, { "pipeline_context": pipeline_context })

	assert_true(payload.is_empty(), "子 Scope 采集失败时，父 Scope 不应生成部分载荷。")
	assert_gt(pipeline_context.errors.size(), 0, "采集失败应写入 pipeline_context.errors。")
	assert_push_error("[GFSaveGraphUtility] gather_scope 失败：同一 Scope 内存在重复 Source key：state")
	assert_push_error("[GFSaveGraphUtility] gather_scope 失败：子 Scope 采集失败：child")


## 验证空载荷应用会显式失败。
func test_apply_scope_rejects_empty_payload() -> void:
	var result: Dictionary = _utility.apply_scope(_scope, {})

	assert_false(GFVariantData.get_option_bool(result, "ok"), "空载荷不应被视为成功应用。")
	assert_true(GFVariantData.get_option_array(result, "errors").has("Save payload is empty."), "空载荷应返回明确错误。")


func test_apply_scope_rejects_invalid_sources_payload() -> void:
	var payload: Dictionary = {
		"format": GFSaveGraphUtility.FORMAT_ID,
		"format_version": GFSaveGraphUtility.FORMAT_VERSION,
		"scope": {},
		"sources": [],
		"scopes": {},
	}

	var result: Dictionary = _utility.apply_scope(_scope, payload)

	assert_false(GFVariantData.get_option_bool(result, "ok"), "sources 非 Dictionary 时不应继续应用。")
	assert_true(GFVariantData.get_option_array(result, "errors").has("Invalid save payload: sources must be a Dictionary."), "结构错误应写入 apply result。")


func test_apply_scope_clears_created_entities_context_after_invalid_payload() -> void:
	var pipeline_context: GFSavePipelineContext = _utility.create_pipeline_context(&"apply", _scope)
	var context: Dictionary = { "pipeline_context": pipeline_context }
	var payload: Dictionary = {
		"format": GFSaveGraphUtility.FORMAT_ID,
		"format_version": GFSaveGraphUtility.FORMAT_VERSION,
		"scope": {},
		"sources": [],
		"scopes": {},
	}

	var result: Dictionary = _utility.apply_scope(_scope, payload, context)

	assert_false(GFVariantData.get_option_bool(result, "ok"), "结构错误应让 apply_scope 返回失败。")
	assert_false(context.has("_gf_save_graph_created_entities"), "结构错误早退后不应残留本次事务创建实体上下文。")


func test_apply_scope_rejects_invalid_child_payload() -> void:
	var child_scope: GFSaveScope = GFSaveScope.new()
	child_scope.name = "ChildScope"
	child_scope.scope_key = &"child"
	_scope.add_child(child_scope)
	var payload: Dictionary = {
		"format": GFSaveGraphUtility.FORMAT_ID,
		"format_version": GFSaveGraphUtility.FORMAT_VERSION,
		"scope": {},
		"sources": {},
		"scopes": {
			"child": [],
		},
	}

	var result: Dictionary = _utility.apply_scope(_scope, payload)

	assert_false(GFVariantData.get_option_bool(result, "ok"), "子 Scope 载荷非 Dictionary 时不应被当作成功。")
	assert_true(GFVariantData.get_option_array(result, "errors").has("Invalid child scope payload: child"), "坏子载荷应写入明确错误。")


func test_apply_scope_rejects_future_format_before_mutating_sources() -> void:
	var target: Node2D = Node2D.new()
	target.name = "Target"
	_scope.add_child(target)
	_scope.add_child(_make_source(&"target_state", NodePath("../Target")))
	var payload: Dictionary = {
		"format": GFSaveGraphUtility.FORMAT_ID,
		"format_version": GFSaveGraphUtility.FORMAT_VERSION + 1,
		"scope": {},
		"sources": {
			"target_state": {
				"descriptor": {},
				"data": {
					"serializers": [{
						"id": &"gf.transform_2d",
						"data": {
							"position": Vector2(9.0, 3.0),
							"rotation": 0.0,
							"scale": Vector2.ONE,
						},
					}],
				},
			},
		},
		"scopes": {},
	}

	var result: Dictionary = _utility.apply_scope(_scope, payload)

	assert_false(GFVariantData.get_option_bool(result, "ok"), "未来格式版本不应被应用。")
	assert_eq(target.position, Vector2.ZERO, "格式门禁失败应发生在 Source 变更之前。")
	assert_true(GFVariantData.to_text(GFVariantData.get_option_array(result, "errors")).contains("future format"), "错误应指出未来格式版本。")


func test_apply_scope_rejects_duplicate_source_keys_before_mutating_sources() -> void:
	var target_a: Node2D = Node2D.new()
	target_a.name = "TargetA"
	_scope.add_child(target_a)
	var target_b: Node2D = Node2D.new()
	target_b.name = "TargetB"
	_scope.add_child(target_b)
	_scope.add_child(_make_source(&"target_state", NodePath("../TargetA")))
	_scope.add_child(_make_source(&"target_state", NodePath("../TargetB")))
	var payload: Dictionary = {
		"format": GFSaveGraphUtility.FORMAT_ID,
		"format_version": GFSaveGraphUtility.FORMAT_VERSION,
		"scope": {},
		"sources": {
			"target_state": {
				"descriptor": {},
				"data": {
					"serializers": [{
						"id": &"gf.transform_2d",
						"data": {
							"position": Vector2(5.0, 0.0),
							"rotation": 0.0,
							"scale": Vector2.ONE,
						},
					}],
				},
			},
		},
		"scopes": {},
	}

	var result: Dictionary = _utility.apply_scope(_scope, payload)

	assert_false(GFVariantData.get_option_bool(result, "ok"), "重复 Source key 不应继续应用。")
	assert_eq(target_a.position, Vector2.ZERO, "重复 key 失败不应改变第一个目标。")
	assert_eq(target_b.position, Vector2.ZERO, "重复 key 失败不应改变第二个目标。")
	assert_true(GFVariantData.to_text(GFVariantData.get_option_array(result, "errors")).contains("Duplicate source key"), "错误应指出重复 Source key。")


func test_apply_scope_orders_same_phase_sources_by_stable_key() -> void:
	var order: Array[String] = []
	_scope.add_child(RecordingApplySource.new(&"b_state", order))
	_scope.add_child(RecordingApplySource.new(&"a_state", order))
	var payload: Dictionary = {
		"format": GFSaveGraphUtility.FORMAT_ID,
		"format_version": GFSaveGraphUtility.FORMAT_VERSION,
		"scope": {},
		"sources": {
			"b_state": {
				"descriptor": {},
				"phase": GFSaveScope.Phase.NORMAL,
				"data": {},
			},
			"a_state": {
				"descriptor": {},
				"phase": GFSaveScope.Phase.NORMAL,
				"data": {},
			},
		},
		"scopes": {},
	}

	var result: Dictionary = _utility.apply_scope(_scope, payload)

	assert_true(GFVariantData.get_option_bool(result, "ok"), "合法 Source 应用应成功。")
	assert_eq(order, ["a_state", "b_state"], "同 phase Source 应按 key 稳定排序，避免 Dictionary 插入顺序影响结果。")


func test_apply_scope_commits_registered_transaction_participants() -> void:
	var order: Array[String] = []
	var participant: RecordingTransactionParticipant = RecordingTransactionParticipant.new(&"external", order)
	_scope.add_child(TransactionParticipantSource.new(&"external_state", participant))
	var payload: Dictionary = {
		"format": GFSaveGraphUtility.FORMAT_ID,
		"format_version": GFSaveGraphUtility.FORMAT_VERSION,
		"scope": {},
		"sources": {
			"external_state": {
				"descriptor": {},
				"data": {},
			},
		},
		"scopes": {},
	}

	var result: Dictionary = _utility.apply_scope(_scope, payload)
	var expected_order: Array[String] = ["prepare:external", "commit:external"]

	assert_true(GFVariantData.get_option_bool(result, "ok"), "事务参与者 prepare/commit 成功时 apply_scope 应成功。")
	assert_eq(order, expected_order, "事务参与者应在 Source 成功后按 prepare/commit 顺序执行。")


func test_apply_scope_rolls_back_registered_transaction_participants_on_prepare_failure() -> void:
	var order: Array[String] = []
	var participant: RecordingTransactionParticipant = RecordingTransactionParticipant.new(&"external", order)
	participant.prepare_ok = false
	_scope.add_child(TransactionParticipantSource.new(&"external_state", participant))
	var payload: Dictionary = {
		"format": GFSaveGraphUtility.FORMAT_ID,
		"format_version": GFSaveGraphUtility.FORMAT_VERSION,
		"scope": {},
		"sources": {
			"external_state": {
				"descriptor": {},
				"data": {},
			},
		},
		"scopes": {},
	}

	var result: Dictionary = _utility.apply_scope(_scope, payload)
	var errors: Array = GFVariantData.get_option_array(result, "errors")
	var expected_order: Array[String] = ["prepare:external", "rollback:external"]

	assert_false(GFVariantData.get_option_bool(result, "ok"), "事务参与者 prepare 失败时 apply_scope 应失败。")
	assert_eq(order, expected_order, "prepare 失败应触发统一 rollback。")
	assert_true(GFVariantData.to_text(errors).contains("prepare_failed"), "结果错误应包含事务参与者失败原因。")


func test_nested_after_load_callbacks_run_only_after_outer_commit_in_post_order() -> void:
	var order: Array[String] = []
	var participant: RecordingTransactionParticipant = RecordingTransactionParticipant.new(&"external", order)
	var root_source: RecordingAfterLoadSource = RecordingAfterLoadSource.new(&"root_state", order)
	_scope.add_child(root_source)
	var child_scope: RecordingAfterLoadScope = RecordingAfterLoadScope.new(&"child", order)
	_scope.add_child(child_scope)
	child_scope.add_child(RecordingAfterLoadSource.new(&"child_state", order, participant))
	var payload: Dictionary = {
		"format": GFSaveGraphUtility.FORMAT_ID,
		"format_version": GFSaveGraphUtility.FORMAT_VERSION,
		"scope": {},
		"sources": {
			"root_state": { "descriptor": {}, "data": {} },
		},
		"scopes": {
			"child": {
				"format": GFSaveGraphUtility.FORMAT_ID,
				"format_version": GFSaveGraphUtility.FORMAT_VERSION,
				"scope": {},
				"sources": {
					"child_state": { "descriptor": {}, "data": {} },
				},
				"scopes": {},
			},
		},
	}

	var result: Dictionary = _utility.apply_scope(_scope, payload)
	var expected_order: Array[String] = [
		"apply:root_state",
		"apply:child_state",
		"prepare:external",
		"commit:external",
		"after_source:child_state",
		"after_scope:child",
		"after_source:root_state",
	]

	assert_true(GFVariantData.get_option_bool(result, "ok"), "嵌套事务成功时 apply_scope 应成功。")
	assert_eq(order, expected_order, "after_load 应在最外层 commit 后按 scope 后序稳定派发。")


func test_nested_after_load_callbacks_are_discarded_when_outer_commit_fails() -> void:
	var order: Array[String] = []
	var participant: RecordingTransactionParticipant = RecordingTransactionParticipant.new(&"external", order)
	participant.commit_ok = false
	var child_scope: RecordingAfterLoadScope = RecordingAfterLoadScope.new(&"child", order)
	_scope.add_child(child_scope)
	child_scope.add_child(RecordingAfterLoadSource.new(&"child_state", order, participant))
	var payload: Dictionary = {
		"format": GFSaveGraphUtility.FORMAT_ID,
		"format_version": GFSaveGraphUtility.FORMAT_VERSION,
		"scope": {},
		"sources": {},
		"scopes": {
			"child": {
				"format": GFSaveGraphUtility.FORMAT_ID,
				"format_version": GFSaveGraphUtility.FORMAT_VERSION,
				"scope": {},
				"sources": {
					"child_state": { "descriptor": {}, "data": {} },
				},
				"scopes": {},
			},
		},
	}

	var result: Dictionary = _utility.apply_scope(_scope, payload)
	var expected_order: Array[String] = [
		"apply:child_state",
		"prepare:external",
		"commit:external",
		"rollback:external",
		"apply:child_state",
	]

	assert_false(GFVariantData.get_option_bool(result, "ok"), "最外层 commit 失败时 apply_scope 应失败。")
	assert_eq(order, expected_order, "commit 失败应先回滚 participant，再恢复 Source 快照。")
	assert_false(GFVariantData.to_text(order).contains("after_"), "commit 失败不得派发任何 after_load。")


func test_queued_child_after_load_is_discarded_when_later_sibling_fails() -> void:
	var order: Array[String] = []
	var first_scope: RecordingAfterLoadScope = RecordingAfterLoadScope.new(&"a_child", order)
	_scope.add_child(first_scope)
	first_scope.add_child(RecordingAfterLoadSource.new(&"state", order))
	var failing_scope: GFSaveScope = GFSaveScope.new()
	failing_scope.name = "BChild"
	failing_scope.scope_key = &"b_child"
	_scope.add_child(failing_scope)
	var failing_source: FailingCreatedSource = FailingCreatedSource.new()
	failing_source.name = "State"
	failing_source.source_key = &"state"
	failing_scope.add_child(failing_source)
	var payload: Dictionary = {
		"format": GFSaveGraphUtility.FORMAT_ID,
		"format_version": GFSaveGraphUtility.FORMAT_VERSION,
		"scope": {},
		"sources": {},
		"scopes": {
			"a_child": {
				"format": GFSaveGraphUtility.FORMAT_ID,
				"format_version": GFSaveGraphUtility.FORMAT_VERSION,
				"scope": {},
				"sources": { "state": { "descriptor": {}, "data": {} } },
				"scopes": {},
			},
			"b_child": {
				"format": GFSaveGraphUtility.FORMAT_ID,
				"format_version": GFSaveGraphUtility.FORMAT_VERSION,
				"scope": {},
				"sources": { "state": { "descriptor": {}, "data": {} } },
				"scopes": {},
			},
		},
	}

	var result: Dictionary = _utility.apply_scope(_scope, payload)

	assert_false(GFVariantData.get_option_bool(result, "ok"), "后续兄弟 scope 失败时外层事务应失败。")
	assert_eq(order, ["apply:state", "apply:state"], "失败时应恢复较早成功子 scope 的 Source 快照。")
	assert_false(GFVariantData.to_text(order).contains("after_"), "较早成功子 scope 的 after_load 队列必须随外层失败一起丢弃。")


func test_apply_scope_rejects_invalid_serializer_data() -> void:
	var target: Node2D = Node2D.new()
	target.name = "Target"
	_scope.add_child(target)
	_scope.add_child(_make_source(&"target_state", NodePath("../Target")))
	var payload: Dictionary = {
		"format": GFSaveGraphUtility.FORMAT_ID,
		"format_version": GFSaveGraphUtility.FORMAT_VERSION,
		"scope": {},
		"sources": {
			"target_state": {
				"descriptor": {},
				"data": {
					"serializers": [{
						"id": &"gf.transform_2d",
						"data": [],
					}],
				},
			},
		},
		"scopes": {},
	}

	var result: Dictionary = _utility.apply_scope(_scope, payload)
	var errors: Array = GFVariantData.get_option_array(result, "errors")

	assert_false(GFVariantData.get_option_bool(result, "ok"), "Serializer data 非 Dictionary 时应返回失败。")
	assert_eq(errors.size(), 1, "错误应汇总到 source 级结果。")
	assert_true(GFVariantData.to_text(errors[0]).contains("Serializer data must be a Dictionary: gf.transform_2d"), "Serializer 错误应指出具体片段。")


func test_apply_scope_rejects_non_dictionary_source_data() -> void:
	var target: Node2D = Node2D.new()
	target.name = "Target"
	_scope.add_child(target)
	_scope.add_child(_make_source(&"target_state", NodePath("../Target")))
	var payload: Dictionary = {
		"format": GFSaveGraphUtility.FORMAT_ID,
		"format_version": GFSaveGraphUtility.FORMAT_VERSION,
		"scope": {},
		"sources": {
			"target_state": {
				"descriptor": {},
				"data": [],
			},
		},
		"scopes": {},
	}

	var result: Dictionary = _utility.apply_scope(_scope, payload)
	var errors: Array = GFVariantData.get_option_array(result, "errors")

	assert_false(GFVariantData.get_option_bool(result, "ok"), "Source data 非 Dictionary 时不应被视为成功。")
	assert_true(GFVariantData.to_text(errors[0]).contains("Invalid source data payload"), "Source 错误应指出数据结构问题。")


func test_apply_scope_transaction_rolls_back_existing_source_state_on_later_failure() -> void:
	var target_a: Node2D = Node2D.new()
	target_a.name = "TargetA"
	_scope.add_child(target_a)
	var target_b: Node2D = Node2D.new()
	target_b.name = "TargetB"
	_scope.add_child(target_b)
	_scope.add_child(_make_source(&"a_state", NodePath("../TargetA")))
	_scope.add_child(_make_source(&"b_state", NodePath("../TargetB")))
	var payload: Dictionary = {
		"format": GFSaveGraphUtility.FORMAT_ID,
		"format_version": GFSaveGraphUtility.FORMAT_VERSION,
		"scope": {},
		"sources": {
			"a_state": {
				"descriptor": {},
				"data": {
					"serializers": [{
						"id": &"gf.transform_2d",
						"data": {
							"position": Vector2(8.0, 1.0),
							"rotation": 0.0,
							"scale": Vector2.ONE,
						},
					}],
				},
			},
			"b_state": {
				"descriptor": {},
				"data": {
					"serializers": [{
						"id": &"gf.transform_2d",
						"data": [],
					}],
				},
			},
		},
		"scopes": {},
	}

	var result: Dictionary = _utility.apply_scope(_scope, payload, {}, true)

	assert_false(GFVariantData.get_option_bool(result, "ok"), "后续 Source 失败应让事务整体失败。")
	assert_eq(target_a.position, Vector2.ZERO, "事务失败应回滚已应用的已有 Source 状态。")
	assert_eq(target_b.position, Vector2.ZERO, "失败 Source 也不应留下部分状态。")


func test_property_serializer_rejects_type_mismatch_before_setting() -> void:
	var node: Node2D = Node2D.new()
	var serializer: GFNodePropertySerializer = GFNodePropertySerializer.new()
	serializer.properties = PackedStringArray(["position"])

	var result: Dictionary = serializer.apply(node, { "position": "bad-position" })

	assert_false(GFVariantData.get_option_bool(result, "ok"), "属性类型不匹配时不应写入节点。")
	assert_eq(node.position, Vector2.ZERO, "失败应用不应改变原属性值。")
	assert_true(GFVariantData.get_option_string(result, "error").contains("Property type mismatch: position"), "错误应指出具体属性。")

	node.free()


## 验证载荷校验会报告当前 Scope 中不存在的 Source。
func test_validate_payload_for_scope_reports_missing_source() -> void:
	var payload: Dictionary = {
		"format": GFSaveGraphUtility.FORMAT_ID,
		"format_version": GFSaveGraphUtility.FORMAT_VERSION,
		"scope": {},
		"sources": {
			"missing": {
				"descriptor": {},
				"data": {},
			},
		},
		"scopes": {},
	}

	var report: Dictionary = _utility.validate_payload_for_scope(_scope, payload, true)

	assert_false(GFVariantData.get_option_bool(report, "ok"), "strict 校验下缺失 Source 应失败。")
	assert_gt(GFVariantData.get_option_int(report, "error_count"), 0, "载荷健康报告应统计错误数量。")
	assert_false(GFVariantData.get_option_string(report, "next_action").is_empty(), "载荷健康报告应提供下一步建议。")
	assert_true(_has_issue(report, "missing_source"), "诊断报告应包含 missing_source。")


func test_validate_payload_for_scope_handles_non_string_payload_keys() -> void:
	var sources: Dictionary = {}
	sources[42] = {
		"descriptor": {},
		"data": {},
	}
	var payload: Dictionary = {
		"format": GFSaveGraphUtility.FORMAT_ID,
		"format_version": GFSaveGraphUtility.FORMAT_VERSION,
		"scope": {},
		"sources": sources,
		"scopes": {},
	}

	var report: Dictionary = _utility.validate_payload_for_scope(_scope, payload, true)

	assert_false(GFVariantData.get_option_bool(report, "ok"), "非字符串载荷 key 应被安全字符串化后进入诊断。")
	assert_true(_has_issue(report, "missing_source"), "诊断报告应包含 missing_source。")


func test_apply_scope_frees_factory_entity_without_save_source() -> void:
	_scope.restore_policy = GFSaveScope.RestorePolicy.ALLOW_FACTORIES
	var factory: PlainEntityFactory = PlainEntityFactory.new()
	_utility.register_entity_factory(factory)
	var payload: Dictionary = _make_factory_payload("plain", &"plain_entity", {})

	var result: Dictionary = _utility.apply_scope(_scope, payload, {}, true)

	assert_false(GFVariantData.get_option_bool(result, "ok"), "工厂创建的实体不包含 GFSaveSource 时应视为缺失 Source。")
	assert_false(is_instance_valid(factory.created_entity), "无法归属到 Source 的工厂实体应立即释放，避免场景残留。")


func test_apply_scope_rolls_back_factory_created_sources_on_failure() -> void:
	_scope.restore_policy = GFSaveScope.RestorePolicy.ALLOW_FACTORIES
	var factory: FailingSourceFactory = FailingSourceFactory.new()
	_utility.register_entity_factory(factory)
	var payload: Dictionary = _make_factory_payload("spawned", &"failing_source", {})

	var result: Dictionary = _utility.apply_scope(_scope, payload, {}, true)

	assert_false(GFVariantData.get_option_bool(result, "ok"), "事务化应用中，工厂创建 Source 应用失败时整体失败。")
	assert_eq(factory.create_count, 1, "测试工厂应创建 Source 实体。")
	assert_false(is_instance_valid(factory.created_source), "事务失败后应回滚并释放本次创建的 Source。")


func test_apply_scope_rejects_factory_source_deleted_by_after_hook() -> void:
	_scope.restore_policy = GFSaveScope.RestorePolicy.ALLOW_FACTORIES
	var factory: DeletingAfterCreateFactory = DeletingAfterCreateFactory.new()
	_utility.register_entity_factory(factory)
	var payload: Dictionary = _make_factory_payload("deleted", &"deleting_source", {})

	var result: Dictionary = _utility.apply_scope(_scope, payload, {}, true)

	assert_false(GFVariantData.get_option_bool(result, "ok"), "after_entity_created 删除 Source 后应视为缺失 Source。")
	assert_false(is_instance_valid(factory.created_source), "测试工厂应已释放创建出的 Source。")


# --- 私有/辅助方法 ---

func _make_source(source_key: StringName, target_path: NodePath) -> GFSaveSource:
	var source: GFSaveSource = GFSaveSource.new()
	source.name = String(source_key)
	source.source_key = source_key
	source.target_node_path = target_path
	source.use_registry_serializers = true
	return source


func _make_factory_payload(source_key: String, type_key: StringName, data: Dictionary) -> Dictionary:
	return {
		"format": GFSaveGraphUtility.FORMAT_ID,
		"format_version": GFSaveGraphUtility.FORMAT_VERSION,
		"scope": {},
		"sources": {
			source_key: {
				"descriptor": {
					"source_key": source_key,
					"type_key": type_key,
				},
				"data": data,
			},
		},
		"scopes": {},
	}


func _has_issue(report: Dictionary, kind: String) -> bool:
	for issue_variant: Variant in GFVariantData.get_option_array(report, "issues"):
		var issue: Dictionary = GFVariantData.as_dictionary(issue_variant)
		if GFVariantData.get_option_string(issue, "kind") == kind:
			return true
	return false


func _has_trace_stage(trace: Dictionary, stage: StringName) -> bool:
	for event_variant: Variant in GFVariantData.get_option_array(trace, "events"):
		var event: Dictionary = GFVariantData.as_dictionary(event_variant)
		if GFVariantData.get_option_string_name(event, "stage") == stage:
			return true
	return false
