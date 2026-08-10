## 测试 GFConfigProvider 基类的默认行为。
extends GutTest


# --- 私有变量 ---

var _temporary_paths: Array[String] = []


# --- Godot 生命周期方法 ---

func before_each() -> void:
	_temporary_paths.clear()


func after_each() -> void:
	for path: String in _temporary_paths:
		var absolute_path: String = ProjectSettings.globalize_path(path)
		if FileAccess.file_exists(absolute_path):
			var _remove_file_result: Error = DirAccess.remove_absolute(absolute_path)
	_temporary_paths.clear()


# --- 测试 ---

## 验证调用基类的 get_record 会报错并返回 null。
func test_get_record_default() -> void:
	var provider: GFConfigProvider = GFConfigProvider.new()
	var result: Variant = provider.get_record(&"ItemTable", 1)
	assert_true(_is_null(result), "基类 get_record 默认应返回 null")
	assert_push_error("[GFConfigProvider] 子类必须实现 get_record() 方法。")


## 验证调用基类的 get_table 会报错并返回 null。
func test_get_table_default() -> void:
	var provider: GFConfigProvider = GFConfigProvider.new()
	var result: Variant = provider.get_table(&"ItemTable")
	assert_true(_is_null(result), "基类 get_table 默认应返回 null")
	assert_push_error("[GFConfigProvider] 子类必须实现 get_table() 方法。")


func test_config_table_resource_indexes_records_and_returns_copies() -> void:
	var table: GFConfigTableResource = _make_item_table_resource()

	var first_record: Dictionary = GFVariantData.as_dictionary(table.get_record(1))
	first_record["name"] = "Changed"
	var original_record: Dictionary = GFVariantData.as_dictionary(table.get_record(1))
	var indexed_count: int = table.rebuild_index()
	var records_by_id: Dictionary = table.get_records_by_id()
	var indexed_record: Dictionary = GFVariantData.as_dictionary(GFVariantData.get_option_value(records_by_id, 1))
	indexed_record["name"] = "Changed Again"
	var original_indexed_record: Dictionary = GFVariantData.as_dictionary(table.get_record(1))

	assert_eq(table.get_table_key(), &"items", "表资源应使用显式 table_name。")
	assert_eq(table.get_id_field(), &"id", "表资源应使用 schema 的 id_field。")
	assert_eq(GFVariantData.get_option_string(original_record, "name"), "Potion", "get_record 默认应返回记录副本。")
	assert_eq(indexed_count, 2, "rebuild_index 应按记录 ID 建立索引。")
	assert_true(table.records_by_id.has(1), "索引应保留原始 ID 类型。")
	assert_true(table.has_record(2), "has_record 应可命中已索引记录。")
	assert_eq(GFVariantData.get_option_string(original_indexed_record, "name"), "Potion", "get_records_by_id 默认应返回记录副本。")


func test_config_table_resource_queries_schema_indexes() -> void:
	var table: GFConfigTableResource = _make_item_table_resource()
	table.schema.indexes.append(_make_name_index())
	table.records.append({ "id": 3, "name": "Potion", "power": 5.0 })

	var index_key: String = table.make_index_key(&"name", { "name": "Potion" })
	var fallback_records: Array[Dictionary] = table.get_index_records(&"name", index_key)
	var indexed_count: int = table.rebuild_indexes()
	var cached_records: Array[Dictionary] = table.get_index_records(&"name", index_key)
	cached_records[0]["name"] = "Changed"
	var original_record: Dictionary = GFVariantData.as_dictionary(table.get_index_record(&"name", index_key))

	assert_false(index_key.is_empty(), "表资源应能按 schema 索引声明生成查询键。")
	assert_eq(fallback_records.size(), 2, "未缓存索引时应能按 schema 临时查询。")
	assert_eq(indexed_count, 1, "rebuild_indexes 应按 schema.indexes 构建命名索引缓存。")
	assert_eq(table.get_index_ids(), PackedStringArray(["name"]), "表资源应返回可查询索引 ID。")
	assert_true(table.has_index_key(&"name", index_key), "命名索引应能检查键是否存在。")
	assert_eq(cached_records.size(), 2, "缓存索引应返回同一组命中记录。")
	assert_eq(GFVariantData.get_option_string(original_record, "name"), "Potion", "索引查询结果默认应返回记录副本。")


func test_config_table_resource_queries_current_records_after_index_cache_becomes_stale() -> void:
	var table: GFConfigTableResource = _make_item_table_resource()
	table.schema.indexes.append(_make_name_index())
	var _id_index_count: int = table.rebuild_index()
	var _named_index_count: int = table.rebuild_indexes()

	table.records = [
		{ "id": 3, "name": "New", "power": 9.0 },
	]
	var old_record: Variant = table.get_record(1)
	var new_record: Dictionary = GFVariantData.as_dictionary(table.get_record(3))
	var old_index_key: String = table.make_index_key(&"name", { "name": "Potion" })
	var new_index_key: String = table.make_index_key(&"name", { "name": "New" })

	assert_true(_is_null(old_record), "records 变更后 get_record 不应返回旧 records_by_id 缓存。")
	assert_eq(GFVariantData.get_option_string(new_record, "name"), "New", "records 变更后 get_record 应读取当前记录。")
	assert_eq(table.get_index_records(&"name", old_index_key).size(), 0, "records 变更后命名索引查询不应返回旧缓存。")
	assert_eq(table.get_index_records(&"name", new_index_key).size(), 1, "records 变更后命名索引查询应读取当前记录。")


func test_config_table_resource_uses_schema_table_name_when_table_name_empty() -> void:
	var table: GFConfigTableResource = _make_item_table_resource()
	table.table_name = &""

	assert_eq(table.get_table_key(), &"items", "table_name 为空时应回退到 schema.table_name。")


func test_resource_config_provider_reads_table_resources() -> void:
	var table: GFConfigTableResource = _make_item_table_resource()
	var provider: GFResourceConfigProvider = GFResourceConfigProvider.new()

	assert_true(provider.register_table(table), "有效表资源应注册成功。")

	var record: Dictionary = GFVariantData.as_dictionary(provider.get_record(&"items", 2))
	var table_data: Array = GFVariantData.as_array(provider.get_table(&"items"))
	var table_resources: Array[GFConfigTableResource] = provider.get_table_resources()
	var report: Dictionary = provider.validate_table(&"items")

	assert_eq(GFVariantData.get_option_string(record, "name"), "Ether", "Provider 应按表名和 ID 读取记录。")
	assert_eq(table_data.size(), 2, "Provider 应返回整表记录副本。")
	assert_eq(table_resources.size(), 1, "Provider 应能返回已注册表资源副本。")
	assert_true(provider.has_schema(&"items"), "注册带 schema 的表资源时应同步注册 schema。")
	assert_true(GFVariantData.get_option_bool(report, "ok"), "Provider 应复用 schema 校验表资源数据。")
	assert_eq(provider.get_table_ids(), PackedStringArray(["items"]), "Provider 应返回排序后的表名。")


func test_resource_config_provider_queries_table_indexes() -> void:
	var table: GFConfigTableResource = _make_item_table_resource()
	table.schema.indexes.append(_make_name_index())
	table.records.append({ "id": 3, "name": "Potion", "power": 5.0 })
	assert_eq(table.rebuild_indexes(), 1, "测试表资源应先构建命名索引。")
	var provider: GFResourceConfigProvider = GFResourceConfigProvider.new()
	assert_true(provider.register_table(table), "有效表资源应注册成功。")

	var index_key: String = provider.make_index_key(&"items", &"name", { "name": "Potion" })
	var records: Array[Dictionary] = provider.get_index_records(&"items", &"name", index_key)
	var first_record: Dictionary = GFVariantData.as_dictionary(provider.get_index_record(&"items", &"name", index_key))

	assert_false(index_key.is_empty(), "Provider 应能委托表资源构建索引键。")
	assert_true(provider.has_index_key(&"items", &"name", index_key), "Provider 应能检查命名索引键。")
	assert_eq(records.size(), 2, "Provider 应能通过命名索引返回多条记录。")
	assert_eq(GFVariantData.get_option_int(first_record, "id"), 1, "Provider 应能通过命名索引返回第一条记录。")


func test_resource_config_provider_returns_copies() -> void:
	var table: GFConfigTableResource = _make_item_table_resource()
	var provider: GFResourceConfigProvider = GFResourceConfigProvider.new()
	assert_true(provider.register_table(table), "有效表资源应注册成功。")

	var record: Dictionary = GFVariantData.as_dictionary(provider.get_record(&"items", 1))
	record["name"] = "Changed"
	var table_data: Array = GFVariantData.as_array(provider.get_table(&"items"))
	var first_row: Dictionary = GFVariantData.as_dictionary(table_data[0])
	first_row["name"] = "Changed Again"
	var original_record: Dictionary = GFVariantData.as_dictionary(provider.get_record(&"items", 1))

	assert_eq(GFVariantData.get_option_string(original_record, "name"), "Potion", "Provider 查询结果不应暴露内部记录引用。")


func test_resource_config_provider_rejects_empty_table_key() -> void:
	var provider: GFResourceConfigProvider = GFResourceConfigProvider.new()
	var table: GFConfigTableResource = GFConfigTableResource.new()

	assert_false(provider.register_table(table), "空表名资源不应注册成功。")
	assert_push_error("[GFResourceConfigProvider] register_table 失败：table_resource 为空或 table_name 为空。")


func test_resource_config_provider_rejects_schema_table_name_mismatch() -> void:
	var provider: GFResourceConfigProvider = GFResourceConfigProvider.new()
	var table: GFConfigTableResource = _make_item_table_resource()
	table.table_name = &"items_runtime"

	assert_false(provider.register_table(table), "表名与 schema 表名不一致时不应注册成功。")
	assert_false(provider.has_table(&"items_runtime"), "注册失败不应留下表缓存。")
	assert_false(provider.has_schema(&"items"), "注册失败不应留下 schema 缓存。")
	assert_push_error("[GFResourceConfigProvider] register_table 失败：table_name 与 schema.table_name 不一致。")


func test_resource_config_provider_register_table_replaces_schema() -> void:
	var provider: GFResourceConfigProvider = GFResourceConfigProvider.new()
	assert_true(provider.register_table(_make_item_table_resource()), "有效表资源应注册成功。")
	assert_true(provider.has_schema(&"items"), "注册带 schema 的表资源时应同步 schema。")

	var table_without_schema: GFConfigTableResource = GFConfigTableResource.new()
	table_without_schema.table_name = &"items"
	table_without_schema.records = [{ "id": 2, "name": "Ether" }]

	assert_true(provider.register_table(table_without_schema), "同名表资源应能替换注册。")
	assert_true(provider.has_table(&"items"), "替换后同名表仍应存在。")
	assert_false(provider.has_schema(&"items"), "同名替换为无 schema 表时旧 schema 不应残留。")


func test_resource_config_provider_rebuild_clears_stale_schemas() -> void:
	var provider: GFResourceConfigProvider = GFResourceConfigProvider.new()
	assert_true(provider.register_table(_make_item_table_resource()), "有效表资源应注册成功。")

	var owner_table: GFConfigTableResource = _make_owner_table_resource(1)
	var registered_count: int = provider.set_table_resources([owner_table])

	assert_eq(registered_count, 1, "替换表资源应返回成功注册数量。")
	assert_false(provider.has_table(&"items"), "替换表资源后旧表不应继续存在。")
	assert_false(provider.has_schema(&"items"), "替换表资源后旧 schema 不应残留。")
	assert_true(provider.has_table(&"owners"), "替换后的表应进入 Provider。")
	assert_true(provider.has_schema(&"owners"), "替换后的表 schema 应进入 Provider。")


func test_resource_config_provider_set_tables_is_documented_best_effort_replacement() -> void:
	var provider: GFResourceConfigProvider = GFResourceConfigProvider.new()
	assert_true(provider.register_table(_make_item_table_resource()), "测试应先注册 last-good 旧表。")
	var valid_owner_table: GFConfigTableResource = _make_owner_table_resource(1)
	var invalid_table: GFConfigTableResource = GFConfigTableResource.new()

	var registered_count: int = provider.set_table_resources([valid_owner_table, invalid_table])

	assert_eq(registered_count, 1, "返回数量应暴露被接受的新表数量。")
	assert_false(provider.has_table(&"items"), "best-effort set 会先清掉旧表，不承诺 last-good rollback。")
	assert_true(provider.has_table(&"owners"), "有效候选应保留在部分新状态中。")
	assert_eq(provider.get_table_ids(), PackedStringArray(["owners"]), "无效候选不应留下匿名 registry 项。")
	assert_push_error("[GFResourceConfigProvider] register_table 失败：table_resource 为空或 table_name 为空。")


func test_resource_config_provider_rebuild_table_registry_refreshes_mutated_table_keys() -> void:
	var provider: GFResourceConfigProvider = GFResourceConfigProvider.new()
	assert_true(provider.register_table(_make_item_table_resource()), "有效表资源应注册成功。")
	var table: GFConfigTableResource = provider.get_table_resource(&"items", false)
	table.table_name = &"owners"
	table.schema = _make_owner_table_resource(1).schema
	table.records = [{ "id": 1, "item_id": 1 }]

	var registered_count: int = provider.rebuild_table_registry()

	assert_eq(registered_count, 1, "重建 registry 应返回刷新后的表数量。")
	assert_false(provider.has_table(&"items"), "重建后旧表名不应继续存在。")
	assert_false(provider.has_schema(&"items"), "重建后旧 schema 不应继续存在。")
	assert_true(provider.has_table(&"owners"), "重建后新表名应进入 Provider。")
	assert_true(provider.has_schema(&"owners"), "重建后新 schema 应进入 Provider。")


func test_resource_config_provider_refreshes_mutated_table_identity_on_lookup() -> void:
	var provider: GFResourceConfigProvider = GFResourceConfigProvider.new()
	assert_true(provider.register_table(_make_item_table_resource()), "有效表资源应注册成功。")
	var table: GFConfigTableResource = provider.get_table_resource(&"items", false)
	table.table_name = &"owners"
	table.schema = _make_owner_table_resource(1).schema
	table.records = [{"id": 1, "item_id": 1}]

	assert_false(provider.has_table(&"items"), "资源身份变化后旧缓存键不得继续返回该表。")
	assert_true(provider.has_table(&"owners"), "lookup 应同步刷新资源当前身份，无需调用方手动重建。")
	assert_false(provider.has_schema(&"items"), "身份刷新应同步移除旧 schema。")
	assert_true(provider.has_schema(&"owners"), "身份刷新应同步注册新 schema。")


func test_config_table_resource_can_round_trip_as_tres() -> void:
	var table: GFConfigTableResource = _make_item_table_resource()
	table.schema.indexes.append(_make_name_index())
	assert_eq(table.rebuild_index(), 2, "保存前应能构建索引。")
	assert_eq(table.rebuild_indexes(), 1, "保存前应能构建命名索引。")
	var path: String = _track_path("user://gf_config_table_resource_%d.tres" % Time.get_ticks_usec())

	assert_eq(ResourceSaver.save(table, path), OK, "测试表资源应能保存为 .tres。")
	var loaded_resource: Resource = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
	var loaded_table: GFConfigTableResource = _variant_to_table_resource(loaded_resource)
	var index_key: String = loaded_table.make_index_key(&"name", { "name": "Potion" }) if loaded_table != null else ""

	assert_not_null(loaded_table, "保存后的 .tres 应能按 GFConfigTableResource 加载。")
	assert_eq(GFVariantData.get_option_string(GFVariantData.as_dictionary(loaded_table.get_record(1)), "name"), "Potion", "加载后的表资源应保留索引和记录。")
	assert_true(loaded_table.has_index_key(&"name", index_key), "加载后的表资源应保留命名索引。")


func test_config_database_resource_registers_tables_and_queries_records() -> void:
	var database: GFConfigDatabaseResource = _make_config_database_resource()

	var table: GFConfigTableResource = database.get_table_resource(&"items")
	var record: Dictionary = GFVariantData.as_dictionary(table.get_record(1)) if table != null else {}
	record["name"] = "Changed"
	var original_table: GFConfigTableResource = database.get_table_resource(&"items")
	var original_record: Dictionary = GFVariantData.as_dictionary(original_table.get_record(1)) if original_table != null else {}
	var tables_by_name: Dictionary = database.get_tables_by_name()
	var schemas: Array[GFConfigTableSchema] = database.get_schemas()
	var table_resources: Array[GFConfigTableResource] = database.get_table_resources()
	var database_copy: GFConfigDatabaseResource = database.duplicate_database()
	var copied_table: GFConfigTableResource = database_copy.get_table_resource(&"items", false)
	copied_table.records[0]["name"] = "Copied"
	var source_table: GFConfigTableResource = database.get_table_resource(&"items", false)
	var source_record: Dictionary = GFVariantData.as_dictionary(source_table.get_record(1))

	assert_eq(database.get_database_key(), &"main", "数据库资源应保留稳定 ID。")
	assert_eq(database.get_table_ids(), PackedStringArray(["items"]), "数据库资源应返回排序后的表名。")
	assert_true(database.has_table(&"items"), "数据库资源应能检查表是否存在。")
	assert_eq(GFVariantData.get_option_string(original_record, "name"), "Potion", "数据库表资源查询默认应返回副本。")
	assert_true(tables_by_name.has(&"items"), "数据库资源应能导出表名到表数据的字典。")
	assert_eq(schemas.size(), 1, "数据库资源应能导出 schema 列表。")
	assert_eq(table_resources.size(), 1, "数据库资源应能导出表资源列表。")
	assert_eq(GFVariantData.get_option_string(source_record, "name"), "Potion", "duplicate_database 应返回独立表资源副本。")


func test_config_database_resource_validates_cross_table_references() -> void:
	var database: GFConfigDatabaseResource = _make_config_database_resource()
	var owner_table: GFConfigTableResource = _make_owner_table_resource(1)
	assert_true(database.register_table(owner_table), "数据库资源应能注册引用来源表。")

	var valid_report: Dictionary = database.validate_database()
	owner_table.records = [
		{ "id": 1, "item_id": 999 },
	]
	var invalid_report: Dictionary = database.validate_database()

	assert_true(GFVariantData.get_option_bool(valid_report, "ok"), "有效跨表引用应通过数据库校验。")
	assert_false(GFVariantData.get_option_bool(invalid_report, "ok"), "缺失引用目标应导致数据库校验失败。")
	assert_true(
		_has_issue_kind(GFVariantData.get_option_array(invalid_report, "issues"), "missing_reference"),
		"数据库校验报告应包含缺失引用问题。"
	)


func test_config_database_resource_reports_schema_table_name_mismatch() -> void:
	var database: GFConfigDatabaseResource = _make_config_database_resource()
	var table: GFConfigTableResource = database.get_table_resource(&"items", false)
	table.table_name = &"runtime_items"

	var report: Dictionary = database.validate_database()

	assert_false(GFVariantData.get_option_bool(report, "ok"), "表名与 schema 表名不一致时数据库校验应失败。")
	assert_true(
		_has_issue_kind(GFVariantData.get_option_array(report, "issues"), "schema_table_name_mismatch"),
		"数据库校验应报告表名与 schema 表名不一致。"
	)


func test_config_database_resource_reports_schema_definition_errors() -> void:
	var database: GFConfigDatabaseResource = _make_config_database_resource()
	var table: GFConfigTableResource = database.get_table_resource(&"items", false)
	var duplicate_column: GFConfigTableColumn = GFConfigTableColumn.new()
	duplicate_column.field_name = &"name"
	duplicate_column.value_type = GFConfigTableColumn.ValueType.STRING
	table.schema.columns.append(duplicate_column)

	var report: Dictionary = database.validate_database()

	assert_false(GFVariantData.get_option_bool(report, "ok"), "数据库校验应包含 schema definition 错误。")
	assert_true(
		_has_issue_kind(GFVariantData.get_option_array(report, "issues"), "duplicate_column_field"),
		"数据库校验应报告重复字段声明。"
	)


func test_resource_config_provider_creates_from_database() -> void:
	var database: GFConfigDatabaseResource = _make_config_database_resource()
	var provider: GFResourceConfigProvider = GFResourceConfigProvider.from_database(database, true)

	var record: Dictionary = GFVariantData.as_dictionary(provider.get_record(&"items", 2))
	var key: String = provider.make_index_key(&"items", &"name", { "name": "Ether" })

	assert_true(provider.has_table(&"items"), "Provider 应能从数据库资源注册表。")
	assert_true(provider.has_schema(&"items"), "Provider 从数据库资源注册表时应同步 schema。")
	assert_eq(GFVariantData.get_option_string(record, "name"), "Ether", "Provider 应能读取数据库资源中的记录。")
	assert_true(provider.has_index_key(&"items", &"name", key), "Provider 应能读取数据库资源中的命名索引。")


func test_config_database_resource_can_round_trip_as_tres() -> void:
	var database: GFConfigDatabaseResource = _make_config_database_resource()
	var path: String = _track_path("user://gf_config_database_resource_%d.tres" % Time.get_ticks_usec())

	assert_eq(ResourceSaver.save(database, path), OK, "测试数据库资源应能保存为 .tres。")
	var loaded_resource: Resource = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
	var loaded_database: GFConfigDatabaseResource = _variant_to_database_resource(loaded_resource)
	var provider: GFResourceConfigProvider = GFResourceConfigProvider.from_database(loaded_database) if loaded_database != null else null

	assert_not_null(loaded_database, "保存后的 .tres 应能按 GFConfigDatabaseResource 加载。")
	assert_eq(loaded_database.get_table_ids(), PackedStringArray(["items"]), "加载后的数据库资源应保留表列表。")
	assert_not_null(provider, "加载后的数据库资源应能创建 Provider。")
	assert_true(provider.has_table(&"items"), "加载后的数据库资源创建的 Provider 应包含表。")
	assert_eq(GFVariantData.get_option_string(GFVariantData.as_dictionary(provider.get_record(&"items", 1)), "name"), "Potion", "加载后的数据库资源应能通过 Provider 读取记录。")


# --- 私有/辅助方法 ---

func _is_null(value: Variant) -> bool:
	return value == null


func _variant_to_database_resource(value: Variant) -> GFConfigDatabaseResource:
	if value is GFConfigDatabaseResource:
		var database: GFConfigDatabaseResource = value
		return database
	return null


func _variant_to_table_resource(value: Variant) -> GFConfigTableResource:
	if value is GFConfigTableResource:
		var table: GFConfigTableResource = value
		return table
	return null


func _make_item_table_resource() -> GFConfigTableResource:
	var table: GFConfigTableResource = GFConfigTableResource.new()
	table.table_name = &"items"
	table.schema = _make_item_schema()
	table.records = [
		{ "id": 1, "name": "Potion", "power": 2.0 },
		{ "id": 2, "name": "Ether", "power": 3.0 },
	]
	table.metadata = { "source": "test" }
	return table


func _make_config_database_resource() -> GFConfigDatabaseResource:
	var table: GFConfigTableResource = _make_item_table_resource()
	table.schema.indexes.append(_make_name_index())
	var _id_index_count: int = table.rebuild_index()
	var _named_index_count: int = table.rebuild_indexes()

	var database: GFConfigDatabaseResource = GFConfigDatabaseResource.new()
	database.database_id = &"main"
	database.version = "test"
	database.metadata = { "source": "test" }
	assert_true(database.register_table(table), "测试数据库应能注册有效表资源。")
	return database


func _make_owner_table_resource(item_id: int) -> GFConfigTableResource:
	var id_column: GFConfigTableColumn = GFConfigTableColumn.new()
	id_column.field_name = &"id"
	id_column.value_type = GFConfigTableColumn.ValueType.INT
	id_column.required = true
	id_column.allow_null = false

	var item_id_column: GFConfigTableColumn = GFConfigTableColumn.new()
	item_id_column.field_name = &"item_id"
	item_id_column.value_type = GFConfigTableColumn.ValueType.INT
	item_id_column.required = true
	item_id_column.allow_null = false

	var reference: GFConfigTableReference = GFConfigTableReference.new()
	reference.reference_id = &"owner_item"
	reference.source_fields = PackedStringArray(["item_id"])
	reference.target_table_name = &"items"
	reference.target_fields = PackedStringArray(["id"])
	reference.required = true

	var schema: GFConfigTableSchema = GFConfigTableSchema.new()
	schema.table_name = &"owners"
	schema.id_field = &"id"
	schema.require_unique_id = true
	schema.columns = [id_column, item_id_column]
	schema.references.append(reference)

	var table: GFConfigTableResource = GFConfigTableResource.new()
	table.table_name = &"owners"
	table.schema = schema
	table.records = [
		{ "id": 1, "item_id": item_id },
	]
	return table


func _make_item_schema() -> GFConfigTableSchema:
	var id_column: GFConfigTableColumn = GFConfigTableColumn.new()
	id_column.field_name = &"id"
	id_column.value_type = GFConfigTableColumn.ValueType.INT
	id_column.required = true
	id_column.allow_null = false

	var name_column: GFConfigTableColumn = GFConfigTableColumn.new()
	name_column.field_name = &"name"
	name_column.value_type = GFConfigTableColumn.ValueType.STRING
	name_column.required = true
	name_column.allow_null = false

	var power_column: GFConfigTableColumn = GFConfigTableColumn.new()
	power_column.field_name = &"power"
	power_column.value_type = GFConfigTableColumn.ValueType.FLOAT
	power_column.required = true
	power_column.allow_null = false

	var schema: GFConfigTableSchema = GFConfigTableSchema.new()
	schema.table_name = &"items"
	schema.id_field = &"id"
	schema.require_unique_id = true
	schema.columns = [id_column, name_column, power_column]
	return schema


func _make_name_index() -> GFConfigTableIndexDefinition:
	var index: GFConfigTableIndexDefinition = GFConfigTableIndexDefinition.new()
	index.index_id = &"name"
	index.field_names = PackedStringArray(["name"])
	return index


func _has_issue_kind(issues: Array, kind: String) -> bool:
	for issue_value: Variant in issues:
		if issue_value is Dictionary:
			var issue: Dictionary = issue_value
			if GFVariantData.get_option_string(issue, "kind") == kind:
				return true
	return false


func _track_path(path: String) -> String:
	_temporary_paths.append(path)
	return path
