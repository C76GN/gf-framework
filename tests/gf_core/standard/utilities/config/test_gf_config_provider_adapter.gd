extends GutTest

const GF_CONFIG_PROVIDER_ADAPTER_SCRIPT = preload("res://addons/gf/standard/utilities/config/gf_config_provider_adapter.gd")


func test_config_provider_adapter_lazily_loads_array_tables() -> void:
	var provider: GF_CONFIG_PROVIDER_ADAPTER_SCRIPT = GF_CONFIG_PROVIDER_ADAPTER_SCRIPT.new()
	var load_count: Array[int] = [0]
	var loader: Callable = func(table_name: StringName, metadata: Dictionary) -> Array[Dictionary]:
		load_count[0] += 1
		assert_eq(table_name, &"items", "loader 应收到表名。")
		assert_eq(GFVariantData.get_option_string(metadata, "source"), "unit", "loader 应收到元数据。")
		return [
			{ "id": 1, "name": "Potion" },
			{ "id": 2, "name": "Elixir" },
		]

	assert_true(provider.register_table_source(&"items", loader, {
		"metadata": { "source": "unit" },
	}), "应能注册懒加载表源。")

	var record: Dictionary = GFVariantData.as_dictionary(provider.get_record(&"items", 2))
	var table_data: Array = GFVariantData.as_array(provider.get_table(&"items"))
	var report: Dictionary = provider.get_load_report(&"items")

	assert_eq(GFVariantData.get_option_string(record, "name"), "Elixir", "数组表应按 id 字段查询记录。")
	assert_eq(table_data.size(), 2, "get_table 应返回表数据。")
	assert_eq(load_count[0], 1, "默认 cache=true 时 loader 应只调用一次。")
	assert_eq(GFVariantData.get_option_int(report, "record_count"), 2, "加载报告应统计记录数。")


func test_config_provider_adapter_supports_dictionary_and_object_tables() -> void:
	var provider: GF_CONFIG_PROVIDER_ADAPTER_SCRIPT = GF_CONFIG_PROVIDER_ADAPTER_SCRIPT.new()
	var dictionary_table: Dictionary = {
		&"hero": { "id": &"hero", "hp": 10 },
	}
	var object_table: GeneratedTable = GeneratedTable.new()

	assert_true(provider.register_table_source(&"dict", dictionary_table), "应能注册字典表。")
	assert_true(provider.register_table_source(&"generated", object_table), "应能注册对象表。")

	var dict_record: Dictionary = GFVariantData.as_dictionary(provider.get_record(&"dict", "hero"))
	var object_record: Dictionary = GFVariantData.as_dictionary(provider.get_record(&"generated", 7))

	assert_eq(GFVariantData.get_option_int(dict_record, "hp"), 10, "字典表应支持 String/StringName 键匹配。")
	assert_eq(GFVariantData.get_option_string(object_record, "name"), "Generated", "对象表应通过 get_record() 查询。")
	assert_eq(GFVariantData.get_option_int(provider.get_load_report(&"generated"), "record_count"), 1, "对象表可通过 get_record_count() 报告记录数。")


func test_config_provider_adapter_replaces_stale_schema_on_source_reregister() -> void:
	var provider: GF_CONFIG_PROVIDER_ADAPTER_SCRIPT = GF_CONFIG_PROVIDER_ADAPTER_SCRIPT.new()
	var schema: GFConfigTableSchema = _make_schema(&"items")
	assert_true(provider.register_table_source(&"items", [{ "id": 1, "name": "Potion" }], {
		"schema": schema,
	}), "带 schema 的表源应注册成功。")
	assert_true(provider.has_schema(&"items"), "注册带 schema 的表源时应同步 schema。")

	assert_true(provider.register_table_source(&"items", [{ "id": 2, "label": "Runtime" }]), "同名表源应能替换为无 schema 表源。")

	assert_true(provider.has_table_source(&"items"), "替换后表源应继续存在。")
	assert_false(provider.has_schema(&"items"), "同名替换为无 schema 表源时旧 schema 不应残留。")


func test_config_provider_adapter_rejects_mismatched_schema_without_clearing_existing_source() -> void:
	var provider: GF_CONFIG_PROVIDER_ADAPTER_SCRIPT = GF_CONFIG_PROVIDER_ADAPTER_SCRIPT.new()
	var original_schema: GFConfigTableSchema = _make_schema(&"items")
	var mismatched_schema: GFConfigTableSchema = _make_schema(&"runtime_items")
	assert_true(provider.register_table_source(&"items", [{ "id": 1, "name": "Potion" }], {
		"schema": original_schema,
	}), "测试应先注册有效表源。")

	assert_false(provider.register_table_source(&"items", [{ "id": 2, "name": "Ether" }], {
		"schema": mismatched_schema,
	}), "schema.table_name 与 table_name 不一致时应拒绝注册。")

	var record: Dictionary = GFVariantData.as_dictionary(provider.get_record(&"items", 1))
	assert_true(provider.has_schema(&"items"), "失败注册不应清掉原 schema。")
	assert_false(provider.has_schema(&"runtime_items"), "失败注册不应留下错名 schema。")
	assert_eq(GFVariantData.get_option_string(record, "name"), "Potion", "失败注册不应替换原表源。")
	assert_push_error("[GFConfigProviderAdapter] register_table_source 失败：schema.table_name 与 table_name 不一致。")


func test_config_provider_adapter_clear_cache_updates_load_report() -> void:
	var provider: GF_CONFIG_PROVIDER_ADAPTER_SCRIPT = GF_CONFIG_PROVIDER_ADAPTER_SCRIPT.new()
	var load_count: Array[int] = [0]
	var loader: Callable = func(_table_name: StringName, _metadata: Dictionary) -> Array[Dictionary]:
		load_count[0] += 1
		return [{ "id": load_count[0] }]
	assert_true(provider.register_table_source(&"items", loader), "测试应能注册懒加载表源。")

	var first_table: Array = GFVariantData.as_array(provider.get_table(&"items"))
	var _clear_cache_result: bool = provider.clear_table_cache(&"items")
	var cleared_report: Dictionary = provider.get_load_report(&"items")
	var second_table: Array = GFVariantData.as_array(provider.get_table(&"items"))

	assert_eq(GFVariantData.get_option_int(GFVariantData.as_dictionary(first_table[0]), "id"), 1, "首次读取应调用 loader。")
	assert_false(GFVariantData.get_option_bool(cleared_report, "cached"), "清除表缓存后报告不应继续标记 cached。")
	assert_eq(GFVariantData.get_option_string(cleared_report, "status"), "registered", "清除表缓存后报告应回到 registered。")
	assert_eq(GFVariantData.get_option_int(GFVariantData.as_dictionary(second_table[0]), "id"), 2, "清除缓存后再次读取应重新加载。")


func test_config_provider_adapter_fails_closed_for_freed_object_source() -> void:
	var provider: GF_CONFIG_PROVIDER_ADAPTER_SCRIPT = GF_CONFIG_PROVIDER_ADAPTER_SCRIPT.new()
	var object_table: DisposableGeneratedTable = DisposableGeneratedTable.new()
	assert_true(provider.register_table_source(&"generated", object_table), "有效对象源应可注册。")
	object_table.free()

	var report: Dictionary = provider.preload_table(&"generated")

	assert_false(GFVariantData.get_option_bool(report, "ok"), "已释放对象源应成为可观察的加载失败。")
	assert_eq(GFVariantData.get_option_string(report, "status"), "failed")


func test_config_provider_adapter_evicts_freed_cached_object() -> void:
	var provider: GF_CONFIG_PROVIDER_ADAPTER_SCRIPT = GF_CONFIG_PROVIDER_ADAPTER_SCRIPT.new()
	var object_table: DisposableGeneratedTable = DisposableGeneratedTable.new()
	assert_true(provider.register_table_source(&"generated", object_table), "有效对象源应可注册。")
	var first_report: Dictionary = provider.preload_table(&"generated")
	assert_true(GFVariantData.get_option_bool(first_report, "ok"), "首次加载对象源应成功。")
	object_table.free()

	var second_report: Dictionary = provider.preload_table(&"generated")

	assert_false(GFVariantData.get_option_bool(second_report, "ok"), "缓存对象被释放后不得继续报告加载成功。")
	assert_eq(GFVariantData.get_option_string(second_report, "status"), "failed")
	assert_false(GFVariantData.get_option_bool(second_report, "cached"), "失效对象必须从缓存中移除。")


func test_config_provider_adapter_rejects_self_recursive_loader() -> void:
	var provider: GF_CONFIG_PROVIDER_ADAPTER_SCRIPT = GF_CONFIG_PROVIDER_ADAPTER_SCRIPT.new()
	var load_count: Array[int] = [0]
	var loader: Callable = func(table_name: StringName, _metadata: Dictionary) -> Array[Dictionary]:
		load_count[0] += 1
		if load_count[0] < 3:
			var _nested_report: Dictionary = provider.preload_table(table_name)
		return [{ "id": 1 }]
	assert_true(provider.register_table_source(&"items", loader), "测试应能注册递归 loader。")

	var report: Dictionary = provider.preload_table(&"items")

	assert_false(GFVariantData.get_option_bool(report, "ok"), "同表递归加载必须 fail-closed。")
	assert_eq(GFVariantData.get_option_string(report, "status"), "failed")
	assert_string_contains(GFVariantData.get_option_string(report, "error"), "items -> items", "报告应给出闭环路径。")
	assert_eq(load_count[0], 1, "检测到活动加载后不应再次调用同一 loader。")
	provider.clear_table_sources()


func test_config_provider_adapter_rejects_cross_table_loader_cycle() -> void:
	var provider: GF_CONFIG_PROVIDER_ADAPTER_SCRIPT = GF_CONFIG_PROVIDER_ADAPTER_SCRIPT.new()
	var load_count: Dictionary = {
		&"a": 0,
		&"b": 0,
	}
	var loader_a: Callable = func(_table_name: StringName, _metadata: Dictionary) -> Array[Dictionary]:
		load_count[&"a"] = GFVariantData.get_option_int(load_count, &"a") + 1
		if GFVariantData.get_option_int(load_count, &"a") < 3:
			var _nested_report: Dictionary = provider.preload_table(&"b")
		return [{ "id": &"a" }]
	var loader_b: Callable = func(_table_name: StringName, _metadata: Dictionary) -> Array[Dictionary]:
		load_count[&"b"] = GFVariantData.get_option_int(load_count, &"b") + 1
		if GFVariantData.get_option_int(load_count, &"b") < 3:
			var _nested_report: Dictionary = provider.preload_table(&"a")
		return [{ "id": &"b" }]
	assert_true(provider.register_table_source(&"a", loader_a), "测试应能注册 A loader。")
	assert_true(provider.register_table_source(&"b", loader_b), "测试应能注册 B loader。")

	var report_a: Dictionary = provider.preload_table(&"a")
	var report_b: Dictionary = provider.get_load_report(&"b")

	assert_false(GFVariantData.get_option_bool(report_a, "ok"), "跨表循环中的起始表必须加载失败。")
	assert_false(GFVariantData.get_option_bool(report_b, "ok"), "跨表循环中的依赖表必须加载失败。")
	assert_string_contains(GFVariantData.get_option_string(report_a, "error"), "a -> b -> a", "报告应给出完整闭环路径。")
	assert_eq(GFVariantData.get_option_int(load_count, &"a"), 1, "A loader 应只进入一次。")
	assert_eq(GFVariantData.get_option_int(load_count, &"b"), 1, "B loader 应只进入一次。")
	provider.clear_table_sources()


func test_config_provider_adapter_clear_removes_standalone_schemas() -> void:
	var provider: GF_CONFIG_PROVIDER_ADAPTER_SCRIPT = GF_CONFIG_PROVIDER_ADAPTER_SCRIPT.new()
	assert_true(provider.register_schema(_make_schema(&"standalone")), "独立 schema 应可注册。")

	provider.clear_table_sources()

	assert_false(provider.has_schema(&"standalone"), "clear_table_sources 的清空契约应覆盖无 source 的独立 schema。")


func _make_schema(table_name: StringName) -> GFConfigTableSchema:
	var schema: GFConfigTableSchema = GFConfigTableSchema.new()
	schema.table_name = table_name
	var id_column: GFConfigTableColumn = GFConfigTableColumn.new()
	id_column.field_name = &"id"
	id_column.value_type = GFConfigTableColumn.ValueType.INT
	schema.columns = [id_column]
	return schema


class GeneratedTable extends RefCounted:

	func get_record(record_id: Variant) -> Dictionary:
		if record_id == 7:
			return { "id": 7, "name": "Generated" }
		return {}


	func get_record_count() -> int:
		return 1


class DisposableGeneratedTable extends Node:

	func get_record(_record_id: Variant) -> Dictionary:
		return {}
