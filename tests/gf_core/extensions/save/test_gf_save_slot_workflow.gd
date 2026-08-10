## 测试 GFSaveSlotWorkflow 的槽位标识、元数据/卡片构建与存储摘要索引。
extends GutTest


var _storage: GFStorageUtility


func before_each() -> void:
	_storage = GFStorageUtility.new()
	_storage.save_dir_name = "test_workflow_slot_build"
	_storage.init()


func after_each() -> void:
	if _storage != null:
		for file_name: String in _storage.list_files("", "", true):
			var _delete_result: Error = _storage.delete_file(file_name)
		_storage.dispose()
		_storage = null


func test_get_slot_id_for_index_replaces_template() -> void:
	var wf: GFSaveSlotWorkflow = GFSaveSlotWorkflow.new()
	assert_eq(wf.active_slot_index, 0)
	wf.slot_id_template = "save_{index}_data"
	assert_eq(wf.get_slot_id_for_index(3), &"save_3_data")


func test_slot_id_override_and_clear() -> void:
	var wf: GFSaveSlotWorkflow = GFSaveSlotWorkflow.new()
	wf.set_slot_id_override(2, &"cloud_a")
	assert_eq(wf.get_slot_id_for_index(2), &"cloud_a")
	wf.set_slot_id_override(2, &"")
	assert_eq(wf.get_slot_id_for_index(2), &"slot_2")
	wf.set_slot_id_override(1, &"x")
	wf.clear_slot_id_overrides()
	assert_eq(wf.get_slot_id_for_index(1), &"slot_1")


func test_slot_id_override_rejects_negative_index() -> void:
	var wf: GFSaveSlotWorkflow = GFSaveSlotWorkflow.new()

	wf.set_slot_id_override(-1, &"invalid")

	assert_eq(wf.get_slot_id_for_index(-1), &"slot_-1", "负索引不得写入 override 状态。")
	assert_push_error("[GFSaveSlotWorkflow] set_slot_id_override 失败：index 必须大于等于 0。")


func test_select_slot_index_clamps_negative() -> void:
	var wf: GFSaveSlotWorkflow = GFSaveSlotWorkflow.new()
	var _select_slot_index_result_41: Variant = wf.select_slot_index(-3)
	assert_eq(wf.active_slot_index, 0)


func test_build_slot_metadata_injects_slot_role() -> void:
	var wf: GFSaveSlotWorkflow = GFSaveSlotWorkflow.new()
	var clock: GFManualClock = GFManualClock.new(0, 1700000005000)
	assert_true(wf.set_clock(clock), "槽位工作流应接受墙上时钟。")
	wf.slot_role = &"manual"
	var meta: GFSaveSlotMetadata = wf.build_slot_metadata(1, "标题", { "k": 1 })
	assert_eq(meta.slot_id, &"slot_1")
	assert_eq(meta.display_name, "标题")
	assert_eq(GFVariantData.get_option_int(meta.custom_metadata, "k"), 1)
	assert_eq(GFVariantData.get_option_string_name(meta.custom_metadata, "slot_role"), &"manual")
	assert_eq(meta.created_at_unix, 1700000005, "元数据应使用注入的 Unix 秒时间。")
	assert_eq(meta.updated_at_unix, 1700000005, "创建与更新时间应来自同一采样。")


func test_build_empty_card_marks_active_slot() -> void:
	var wf: GFSaveSlotWorkflow = GFSaveSlotWorkflow.new()
	wf.active_slot_index = 2
	var card: GFSaveSlotCard = wf.build_empty_card(2)
	assert_true(card.is_empty)
	assert_true(card.is_active)
	assert_eq(card.slot_index, 2)


func test_empty_display_name_template_is_opt_in() -> void:
	var wf: GFSaveSlotWorkflow = GFSaveSlotWorkflow.new()
	var default_card: GFSaveSlotCard = wf.build_empty_card(2)
	var default_metadata: GFSaveSlotMetadata = wf.build_slot_metadata(2)

	assert_eq(wf.get_empty_display_name_for_index(2), "")
	assert_eq(default_card.display_name, "")
	assert_eq(default_metadata.display_name, "")

	wf.empty_display_name_template = "Slot {index}"
	assert_eq(wf.get_empty_display_name_for_index(2), "Slot 2")
	assert_eq(wf.build_empty_card(2).display_name, "Slot 2")


func test_build_card_for_index_empty_summary_returns_empty_card() -> void:
	var wf: GFSaveSlotWorkflow = GFSaveSlotWorkflow.new()
	var card: GFSaveSlotCard = wf.build_card_for_index(1, {})
	assert_true(card.is_empty)


func test_build_cards_for_indices_matches_summary_by_index() -> void:
	var wf: GFSaveSlotWorkflow = GFSaveSlotWorkflow.new()
	var summaries: Array = [
		{ "slot_index": 1, "metadata": { "display_name": "A" }, "is_compatible": true },
	]
	var cards: Array[GFSaveSlotCard] = wf.build_cards_for_indices([1, 2], summaries)
	assert_eq(cards.size(), 2)
	assert_false(cards[0].is_empty)
	assert_eq(cards[0].display_name, "A")
	assert_true(cards[1].is_empty)


func test_save_slot_storage_adapter_round_trips_slots_and_cards() -> void:
	var clock: GFManualClock = GFManualClock.new(0, 1700000010000)
	var adapter: GFSaveSlotStorageAdapter = GFSaveSlotStorageAdapter.new().setup(_storage, clock)
	var wf: GFSaveSlotWorkflow = GFSaveSlotWorkflow.new()
	wf.empty_display_name_template = "Slot {index}"

	var save_error: Error = adapter.save_slot(2, _make_slot_document({ "hp": 10 }), {
		"slot_id": &"manual_2",
		"display_name": "手动二",
	})
	var read_result: GFSaveDocumentReadResult = adapter.load_slot(2)
	var data: Dictionary = _get_slot_payload(read_result)
	var metadata: Dictionary = adapter.load_slot_metadata(2)
	var summaries: Array[Dictionary] = adapter.list_slots()
	var cards: Array[GFSaveSlotCard] = wf.build_cards_from_slot_store(adapter, [2, 3])

	assert_eq(save_error, OK, "slot adapter 应通过 storage 事务保存数据和元数据。")
	assert_true(read_result.is_successful(), read_result.get_error())
	assert_true(adapter.has_slot(2), "保存后槽位应存在。")
	assert_eq(GFVariantData.get_option_int(data, "hp"), 10, "slot adapter 应能读取数据。")
	assert_eq(GFVariantData.get_option_string_name(metadata, "slot_id"), &"manual_2", "slot adapter 应保留逻辑 slot_id。")
	assert_eq(GFVariantData.get_option_string_name(metadata, "schema_id"), &"test.save", "metadata schema 应以文档为权威来源。")
	assert_eq(GFVariantData.get_option_int(metadata, "schema_version"), 1)
	assert_eq(GFVariantData.get_option_int(metadata, "updated_at_unix"), 1700000010, "缺省更新时间应使用适配器时钟。")
	assert_eq(summaries.size(), 1, "slot adapter 应枚举完整槽位。")
	assert_eq(GFVariantData.get_option_int(summaries[0], "slot_index"), 2, "slot summary 应包含槽位索引。")
	assert_false(cards[0].is_empty, "已有槽位应构建为非空卡片。")
	assert_eq(cards[0].display_name, "手动二", "卡片应读取元数据显示名。")
	assert_true(cards[1].is_empty, "缺失槽位应构建为空卡片。")


func test_save_slot_storage_adapter_supports_custom_file_templates() -> void:
	var adapter: GFSaveSlotStorageAdapter = GFSaveSlotStorageAdapter.new().setup(_storage)
	adapter.data_file_template = "campaign/{index}/data.json"
	adapter.metadata_file_template = "campaign/{index}/meta.json"

	var save_error: Error = adapter.save_slot(4, _make_slot_document({ "xp": 12 }), { "display_name": "Campaign" })
	var summaries: Array[Dictionary] = adapter.list_slots()

	assert_eq(save_error, OK, "slot adapter 应支持项目自定义文件模板。")
	assert_eq(GFVariantData.get_option_int(_get_slot_payload(adapter.load_slot(4)), "xp"), 12, "自定义模板槽位数据应可读取。")
	assert_eq(summaries.size(), 1, "自定义模板槽位应可枚举。")
	assert_eq(GFVariantData.get_option_string(GFVariantData.get_option_dictionary(summaries[0], "metadata"), "display_name"), "Campaign", "自定义模板槽位元数据应可读取。")
	var delete_error: Error = adapter.delete_slot(4)
	assert_eq(delete_error, OK, "自定义模板槽位应可删除。")


func test_save_slot_storage_adapter_rejects_template_without_index_marker() -> void:
	var adapter: GFSaveSlotStorageAdapter = GFSaveSlotStorageAdapter.new().setup(_storage)
	adapter.data_file_template = "shared_data.sav"

	var save_error: Error = adapter.save_slot(1, _make_slot_document({"hp": 10}))

	assert_eq(save_error, ERR_INVALID_PARAMETER, "不含 index 的模板会让多个槽位覆盖同一文件，必须拒绝。")
	assert_push_error("[GFSaveSlotStorageAdapter] save_slot 失败：data_file_template 必须包含 {index}。")


func test_save_slot_storage_adapter_rejects_data_metadata_path_collision() -> void:
	var adapter: GFSaveSlotStorageAdapter = GFSaveSlotStorageAdapter.new().setup(_storage)
	adapter.data_file_template = "slot_{index}.sav"
	adapter.metadata_file_template = "slot_{index}.sav"

	var save_error: Error = adapter.save_slot(1, _make_slot_document({"hp": 10}))

	assert_eq(save_error, ERR_INVALID_PARAMETER, "data 与 metadata 解析到同一路径时必须拒绝保存。")
	assert_push_error("[GFSaveSlotStorageAdapter] save_slot 失败：数据与元数据模板解析到同一存储目标")


func test_save_slot_storage_adapter_rejects_canonical_target_alias_collision() -> void:
	var adapter: GFSaveSlotStorageAdapter = GFSaveSlotStorageAdapter.new().setup(_storage)
	adapter.data_file_template = "slot_{index}.sav"
	adapter.metadata_file_template = "./slot_{index}.sav"

	var save_error: Error = adapter.save_slot(7, _make_slot_document({"hp": 10}))

	assert_eq(save_error, ERR_INVALID_PARAMETER, "语法不同但指向同一最终文件的模板必须在写入前拒绝。")
	assert_false(FileAccess.file_exists(_storage.get_storage_directory_path("").path_join("slot_7.sav")), "碰撞校验失败时不得写入任一存储目标。")
	assert_push_error("[GFSaveSlotStorageAdapter] save_slot 失败：数据与元数据模板解析到同一存储目标")


func test_save_slot_storage_adapter_excludes_corrupt_metadata_from_summaries() -> void:
	var adapter: GFSaveSlotStorageAdapter = GFSaveSlotStorageAdapter.new().setup(_storage)
	assert_eq(adapter.save_slot(5, _make_slot_document({"hp": 10}), {"display_name": "Healthy"}), OK)
	var metadata_path: String = _storage.get_storage_directory_path("").path_join(adapter.get_metadata_file_name(5))
	var file: FileAccess = FileAccess.open(metadata_path, FileAccess.WRITE)
	assert_not_null(file, "测试应能覆盖 metadata 文件。")
	if file != null:
		assert_true(file.store_string("{ malformed"), "测试应能写入损坏 metadata。")
		file.close()

	var summaries: Array[Dictionary] = adapter.list_slots()

	assert_eq(summaries.size(), 0, "无法解码的 metadata 不得伪装成健康非空槽位。")
	assert_push_error("[GFStorageUtility] 读取数据失败")


func test_save_slot_storage_adapter_reports_partial_delete_as_failure() -> void:
	var adapter: GFSaveSlotStorageAdapter = GFSaveSlotStorageAdapter.new().setup(_storage)
	assert_eq(_storage.save_data(adapter.get_data_file_name(6), {"hp": 10}), OK)

	var delete_error: Error = adapter.delete_slot(6)

	assert_eq(delete_error, ERR_FILE_NOT_FOUND, "缺少 metadata 的半槽位不能报告完整删除成功。")
	assert_false(FileAccess.file_exists(_storage.get_storage_directory_path("").path_join(adapter.get_data_file_name(6))))


func test_save_slot_storage_adapter_rejects_unsafe_persisted_values() -> void:
	var adapter: GFSaveSlotStorageAdapter = GFSaveSlotStorageAdapter.new().setup(_storage)
	var unsafe_object: RefCounted = RefCounted.new()
	var object_document: GFSaveDocument = _make_slot_document({ "hp": 10 }, {
		"unsafe": unsafe_object,
	})
	var finite_document: GFSaveDocument = _make_slot_document({ "hp": 10 }, {
		"unsafe": INF,
	})

	var object_error: Error = adapter.save_slot(7, object_document)
	var finite_error: Error = adapter.save_slot(7, finite_document)

	assert_eq(object_error, ERR_INVALID_DATA, "Object 不得在持久化边界被静默转换为 null。")
	assert_eq(finite_error, ERR_INVALID_DATA, "非有限数不得进入稳定持久化载荷。")
	assert_false(adapter.has_slot(7), "preflight 失败不得留下半写入槽位。")
	assert_push_error("[GFSaveSlotStorageAdapter] save_slot 失败：document 无效。")
	assert_push_error("[GFSaveSlotStorageAdapter] save_slot 失败：document 无效。")


func test_save_slot_storage_adapter_rejects_conflicting_metadata_schema() -> void:
	var adapter: GFSaveSlotStorageAdapter = GFSaveSlotStorageAdapter.new().setup(_storage)
	var document: GFSaveDocument = _make_slot_document({ "hp": 10 })

	var save_error: Error = adapter.save_slot(8, document, {
		"schema_id": &"other.save",
		"schema_version": 1,
	})

	assert_eq(save_error, ERR_INVALID_DATA)
	assert_false(adapter.has_slot(8))
	assert_push_error("[GFSaveSlotStorageAdapter] save_slot 失败：metadata schema 与 document 不一致。")


func test_save_slot_storage_adapter_requires_and_applies_section_migration() -> void:
	var adapter: GFSaveSlotStorageAdapter = GFSaveSlotStorageAdapter.new().setup(_storage)
	var source_document: GFSaveDocument = _make_slot_document({ "hp": 10 })
	assert_eq(adapter.save_slot(9, source_document), OK)
	var target_schema: GFSaveDocumentSchema = GFSaveDocumentSchema.new().configure(
		&"test.save",
		1,
		{ &"game": 2 },
		{ "required_sections": PackedStringArray(["game"]) }
	)

	var missing_migration_result: GFSaveDocumentReadResult = adapter.load_slot(
		9,
		target_schema
	)
	var registry: GFSaveMigrationRegistry = GFSaveMigrationRegistry.new()
	assert_true(registry.register_step(SlotPayloadMigration.new()))
	var migrated_result: GFSaveDocumentReadResult = adapter.load_slot(
		9,
		target_schema,
		registry
	)
	var stored_again: GFSaveDocumentReadResult = adapter.load_slot(9)

	assert_false(missing_migration_result.is_successful(), "旧分区缺少 Registry 时必须失败。")
	assert_true(missing_migration_result.get_error().contains("migrat"))
	assert_true(migrated_result.is_successful(), migrated_result.get_error())
	assert_true(migrated_result.was_migrated())
	assert_eq(GFVariantData.get_option_int(_get_slot_payload(migrated_result), "hit_points"), 10)
	assert_eq(GFVariantData.get_option_int(_get_slot_payload(stored_again), "hp"), 10, "读取迁移不得隐式回写槽位文件。")
	assert_false(_get_slot_payload(stored_again).has("hit_points"))


func test_save_slot_read_entries_reject_invalid_integrity() -> void:
	var storage: IntegrityMarkingStorage = IntegrityMarkingStorage.new()
	storage.save_dir_name = "test_workflow_slot_integrity"
	storage.init()
	var adapter: GFSaveSlotStorageAdapter = GFSaveSlotStorageAdapter.new().setup(storage)
	assert_eq(
		adapter.save_slot(3, _make_slot_document({ "hp": 10 }), { "display_name": "Unsafe" }),
		OK
	)
	storage.mark_reads_invalid = true

	var document_result: GFSaveDocumentReadResult = adapter.load_slot(3)
	var metadata: Dictionary = adapter.load_slot_metadata(3)
	var summaries: Array[Dictionary] = adapter.list_slots()

	assert_false(document_result.is_successful())
	assert_eq(document_result.get_error_code(), ERR_FILE_CORRUPT)
	assert_true(metadata.is_empty(), "明确 INVALID 的 metadata 不得进入 UI 摘要。")
	assert_true(summaries.is_empty(), "list_slots 不得展示完整性失败的槽位。")
	storage.mark_reads_invalid = false
	assert_eq(adapter.delete_slot(3), OK)
	storage.dispose()


func test_save_slot_workflow_preflights_custom_script_base_type() -> void:
	WrongMetadataResource.init_count = 0
	WrongCardResource.init_count = 0
	var wf: GFSaveSlotWorkflow = GFSaveSlotWorkflow.new()
	wf.metadata_script = WrongMetadataResource
	wf.card_script = WrongCardResource

	var metadata: GFSaveSlotMetadata = wf.build_slot_metadata(1)
	var card: GFSaveSlotCard = wf.build_empty_card(1)

	assert_not_null(metadata, "错误 metadata_script 应回退到框架默认类型。")
	assert_not_null(card, "错误 card_script 应回退到框架默认类型。")
	assert_eq(WrongMetadataResource.init_count, 0, "错误 metadata script 不得先构造再做后验型别检查。")
	assert_eq(WrongCardResource.init_count, 0, "错误 card script 不得先构造再做后验型别检查。")
	assert_push_error("[GFSaveSlotWorkflow] metadata_script 必须继承 GFSaveSlotMetadata 且可实例化。")
	assert_push_error("[GFSaveSlotWorkflow] card_script 必须继承 GFSaveSlotCard 且可实例化。")


func test_parse_slot_index_from_custom_template_id() -> void:
	var wf: GFSaveSlotWorkflow = GFSaveSlotWorkflow.new()
	wf.slot_id_template = "save_{index}_data"
	var summaries: Array = [{ "slot_id": "save_4_data", "metadata": {}, "is_compatible": true }]
	var cards: Array[GFSaveSlotCard] = wf.build_cards_for_indices([4], summaries)
	assert_false(cards[0].is_empty)


func test_save_slot_sync_bridge_syncs_adapter_files() -> void:
	var adapter: GFSaveSlotStorageAdapter = GFSaveSlotStorageAdapter.new()
	adapter.data_file_template = "slots/{index}/data.json"
	adapter.metadata_file_template = "slots/{index}/meta.json"
	var local: MemoryStorageBackend = MemoryStorageBackend.new()
	var remote: MemoryStorageBackend = MemoryStorageBackend.new()
	local.set_record(adapter.get_data_file_name(2), { "hp": 10 }, { "timestamp_unix": 100 })
	local.set_record(adapter.get_metadata_file_name(2), { "display_name": "Slot 2" }, { "timestamp_unix": 100 })
	var bridge: GFSaveSlotSyncBridge = GFSaveSlotSyncBridge.new()

	var result: Dictionary = bridge.sync_slot(2, adapter, local, remote)
	var remote_data: Dictionary = GFVariantData.get_option_dictionary(remote.load_data(adapter.get_data_file_name(2)), "data")
	var remote_metadata: Dictionary = GFVariantData.get_option_dictionary(remote.load_data(adapter.get_metadata_file_name(2)), "data")
	var file_names: PackedStringArray = GFVariantData.get_option_packed_string_array(result, "file_names")

	assert_true(GFVariantData.get_option_bool(result, "ok"), "槽位同步桥应同步所选槽位文件。")
	assert_eq(GFVariantData.get_option_int(remote_data, "hp"), 10, "数据文件应复制到远端。")
	assert_eq(GFVariantData.get_option_string(remote_metadata, "display_name"), "Slot 2", "元数据文件应复制到远端。")
	assert_eq(file_names, PackedStringArray(["slots/2/data.json", "slots/2/meta.json"]), "同步结果应暴露参与同步的文件。")


func test_save_slot_sync_bridge_rejects_invalid_or_colliding_adapter_templates() -> void:
	var cases: Array[Dictionary] = [
		{
			"data": "shared.sav",
			"metadata": "slot_{index}_meta.sav",
		},
		{
			"data": "slot_{index}.sav",
			"metadata": "slot_{index}.sav",
		},
		{
			"data": "slot_{index}.sav",
			"metadata": "./slot_{index}.sav",
		},
	]
	for case: Dictionary in cases:
		var adapter: GFSaveSlotStorageAdapter = GFSaveSlotStorageAdapter.new()
		adapter.data_file_template = GFVariantData.get_option_string(case, "data")
		adapter.metadata_file_template = GFVariantData.get_option_string(case, "metadata")
		var local: MemoryStorageBackend = MemoryStorageBackend.new()
		var remote: MemoryStorageBackend = MemoryStorageBackend.new()
		var bridge: GFSaveSlotSyncBridge = GFSaveSlotSyncBridge.new()

		var result: Dictionary = bridge.sync_slot(2, adapter, local, remote)

		assert_false(GFVariantData.get_option_bool(result, "ok"))
		assert_true(GFVariantData.get_option_packed_string_array(result, "file_names").is_empty())
		assert_eq(local.operation_count, 0, "模板 preflight 失败前不得访问本地 backend。")
		assert_eq(remote.operation_count, 0, "模板 preflight 失败前不得访问远端 backend。")


# --- 私有/辅助方法 ---

func _make_slot_document(
	payload: Dictionary,
	metadata: Dictionary = {}
) -> GFSaveDocument:
	var section: GFSaveSection = GFSaveSection.new().configure(
		&"game",
		1,
		payload
	)
	var sections: Array[GFSaveSection] = [section]
	return GFSaveDocument.new().configure(
		&"test.save",
		1,
		sections,
		metadata
	)


func _get_slot_payload(read_result: GFSaveDocumentReadResult) -> Dictionary:
	if read_result == null or not read_result.is_successful():
		return {}
	var document: GFSaveDocument = read_result.get_document()
	if document == null:
		return {}
	var section: GFSaveSection = document.get_section(&"game")
	if section == null:
		return {}
	var payload_value: Variant = section.get_payload()
	if payload_value is Dictionary:
		var payload: Dictionary = payload_value
		return payload
	return {}


# --- 辅助类型 ---

class MemoryStorageBackend:
	extends GFStorageBackend

	var records: Dictionary = {}
	var operation_count: int = 0

	func set_record(file_name: String, data: Dictionary, metadata: Dictionary = {}) -> void:
		records[file_name] = {
			"data": data.duplicate(true),
			"metadata": metadata.duplicate(true),
		}

	func _save_data(file_name: String, data: Dictionary, metadata: Dictionary) -> Error:
		operation_count += 1
		set_record(file_name, data, metadata)
		return OK

	func _load_data(file_name: String) -> Dictionary:
		operation_count += 1
		if not records.has(file_name):
			return {
				"ok": false,
				"data": {},
				"metadata": {},
				"error": "missing",
			}
		var record: Dictionary = GFVariantData.get_option_dictionary(records, file_name)
		return {
			"ok": true,
			"data": GFVariantData.get_option_dictionary(record, "data"),
			"metadata": GFVariantData.get_option_dictionary(record, "metadata"),
			"error": "",
		}

	func _get_capabilities() -> Dictionary:
		return {
			"read": true,
			"write": true,
			"delete": false,
			"list": false,
			"sync": true,
		}


class IntegrityMarkingStorage extends GFStorageUtility:
	var mark_reads_invalid: bool = false

	func load_data(file_name: String) -> GFStorageReadResult:
		var result: GFStorageReadResult = super.load_data(file_name)
		if mark_reads_invalid and result.ok:
			result.integrity_status = GFStorageReadResult.IntegrityStatus.INVALID
		return result


class WrongMetadataResource extends Resource:
	static var init_count: int = 0

	func _init() -> void:
		init_count += 1


class WrongCardResource extends Resource:
	static var init_count: int = 0

	func _init() -> void:
		init_count += 1


class SlotPayloadMigration extends GFSaveMigrationStep:
	func _init() -> void:
		step_id = &"slot_game_1_to_2"
		schema_id = &"test.save"
		section_id = &"game"
		from_version = 1
		to_version = 2

	func _migrate_section(
		section: GFSaveSection,
		_context: Dictionary = {}
	) -> GFSaveSection:
		var payload_value: Variant = section.get_payload()
		if not payload_value is Dictionary:
			return null
		var payload: Dictionary = GFVariantData.as_dictionary(payload_value)
		payload["hit_points"] = GFVariantData.get_option_int(payload, "hp")
		var _erased: bool = payload.erase("hp")
		return GFSaveSection.new().configure(
			section.get_section_id(),
			section.get_schema_version(),
			payload,
			section.get_metadata()
		)
