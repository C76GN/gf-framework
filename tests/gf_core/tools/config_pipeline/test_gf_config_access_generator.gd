extends GutTest


# --- 常量 ---

const GF_TRANSIENT_GDSCRIPT_TEST_SUPPORT = preload(
	"res://tests/gf_core/support/gf_transient_gdscript_test_support.gd"
)


# --- 测试用例 ---

func test_build_source_generates_config_accessors() -> void:
	var schema: ConfigSchemaStub = ConfigSchemaStub.new(&"item_data")
	var generator: GFConfigAccessGenerator = GFConfigAccessGenerator.new()

	var source: String = generator.build_source([schema])

	assert_true(source.contains("class_name GFConfigAccess"), "应生成默认访问器类。")
	assert_true(source.contains("const ITEM_DATA: StringName = &\"item_data\""), "应生成表名常量。")
	assert_true(source.contains("static func get_item_data_record(id: Variant, provider: Variant = null) -> Variant:"), "应生成记录读取方法。")
	assert_true(source.contains("return _get_provider_record(provider, ITEM_DATA, id)"), "记录读取方法应委托给 provider helper。")
	assert_true(source.contains("return provider_object.call(\"get_record\", table_name, id)"), "provider helper 应使用安全反射调用。")
	assert_false(source.contains("return resolved_provider.get_record(ITEM_DATA, id)"), "生成访问器不应对 Variant provider 直接调方法。")
	assert_true(source.contains("static func get_item_data_table(provider: Variant = null) -> Variant:"), "应生成整表读取方法。")


func test_generate_with_report_supports_dry_run_without_writing() -> void:
	var schema: ConfigSchemaStub = ConfigSchemaStub.new(&"item_data")
	var generator: GFConfigAccessGenerator = GFConfigAccessGenerator.new()
	var output_path: String = "user://gf_config_access_generator_dry_run_%d.gd" % Time.get_ticks_usec()

	var report: Dictionary = generator.generate_with_report([schema], output_path, "DryRunConfigAccess", "null", {
		"dry_run": true,
	})

	assert_true(GFVariantData.get_option_bool(report, "success"), "dry-run 生成报告应成功。")
	assert_eq(GFVariantData.get_option_string_name(report, "status"), GFGeneratedArtifactReport.STATUS_NEW, "不存在的目标应报告 new。")
	assert_false(GFVariantData.get_option_bool(report, "written"), "dry-run 不应写入访问器文件。")
	assert_true(GFVariantData.get_option_bool(report, "dry_run"), "报告应保留 dry_run 标记。")
	assert_false(FileAccess.file_exists(output_path), "dry-run 不应创建访问器文件。")


func test_build_source_sanitizes_invalid_table_names() -> void:
	var schema: ConfigSchemaStub = ConfigSchemaStub.new(&"123 item-data")
	var generator: GFConfigAccessGenerator = GFConfigAccessGenerator.new()

	var source: String = generator.build_source([schema], "MyConfigAccess", "null")

	assert_true(source.contains("class_name MyConfigAccess"), "应允许自定义访问器类名。")
	assert_true(source.contains("const TABLE_123_ITEM_DATA: StringName = &\"123 item-data\""), "非法标识符字符应转为有效常量名。")
	assert_true(source.contains("static func get_table_123_item_data_record"), "数字开头表名应生成安全方法前缀。")
	assert_true(source.contains("\treturn null"), "应允许自定义 provider_accessor。")


func test_build_source_accepts_dictionary_schemas() -> void:
	var generator: GFConfigAccessGenerator = GFConfigAccessGenerator.new()

	var source: String = generator.build_source([{ "table_name": "enemy_data" }])

	assert_true(source.contains("const ENEMY_DATA: StringName = &\"enemy_data\""), "字典 schema 应可提供表名。")


func test_build_source_reads_schema_properties_without_calling_methods() -> void:
	var schema: MethodTrapConfigSchemaStub = MethodTrapConfigSchemaStub.new(&"item_data")
	var generator: GFConfigAccessGenerator = GFConfigAccessGenerator.new()

	var source: String = generator.build_source([schema])

	assert_true(source.contains("const ITEM_DATA: StringName = &\"item_data\""), "对象 schema 应通过导出属性提供表名。")
	assert_false(schema.get_table_key_called, "编辑器生成器不应调用 schema 方法，避免 placeholder 报错。")


func test_build_source_accepts_object_table_key_property() -> void:
	var schema: TableKeyConfigSchemaStub = TableKeyConfigSchemaStub.new(&"enemy_data")
	var generator: GFConfigAccessGenerator = GFConfigAccessGenerator.new()

	var source: String = generator.build_source([schema])

	assert_true(source.contains("const ENEMY_DATA: StringName = &\"enemy_data\""), "对象 schema 应支持 table_key 属性。")


func test_build_source_supports_gdscript_generation_options() -> void:
	var schema: ConfigSchemaStub = ConfigSchemaStub.new(&"item_data")
	schema.metadata = { "comment": "道具配置表。" }
	var generator: GFConfigAccessGenerator = GFConfigAccessGenerator.new()

	var source: String = generator.build_source([schema], "MyConfigAccess", "null", {
		"method_name_style": "camel",
		"constant_prefix": "cfg",
		"record_method_pattern": "fetch_{table}",
		"table_method_pattern": "all_{table}",
	})

	assert_true(source.contains("const CFG_ITEM_DATA: StringName = &\"item_data\""), "常量前缀应按选项生成。")
	assert_true(source.contains("## 道具配置表。"), "schema metadata 注释应写入生成源码。")
	assert_true(source.contains("static func fetch_itemData(id: Variant, provider: Variant = null) -> Variant:"), "记录方法应按 GDScript 命名选项生成。")
	assert_true(source.contains("static func all_itemData(provider: Variant = null) -> Variant:"), "整表方法应按自定义模板生成。")


func test_build_source_can_generate_typed_record_wrappers() -> void:
	var schema: ConfigSchemaStub = ConfigSchemaStub.new(&"item_data")
	schema.columns = [
		ConfigColumnStub.new(&"id", GFConfigTableColumn.ValueType.INT),
		ConfigColumnStub.new(&"name", GFConfigTableColumn.ValueType.STRING),
		ConfigColumnStub.new(&"power", GFConfigTableColumn.ValueType.FLOAT),
	]
	var generator: GFConfigAccessGenerator = GFConfigAccessGenerator.new()

	var source: String = generator.build_source([schema], "GFConfigAccess", "null", {
		"include_typed_records": true,
	})

	assert_true(source.contains("class GFConfigRecordAccessBase:"), "启用 typed records 时应生成记录访问基类。")
	assert_true(source.contains("class ItemDataRecord:"), "应按表名生成记录包装类。")
	assert_true(source.contains("static func get_item_data_typed_record(id: Variant, provider: Variant = null) -> ItemDataRecord:"), "应生成 typed record 读取方法。")
	assert_true(source.contains("return ItemDataRecord.from_variant(_get_provider_record(provider, ITEM_DATA, id))"), "typed record 方法应复用 provider 读取结果。")
	assert_true(source.contains("func get_id() -> int:"), "INT 字段应生成 int getter。")
	assert_true(source.contains("return get_int(&\"id\", 0)"), "INT getter 应使用类型收窄 helper。")
	assert_true(source.contains("func get_name() -> String:"), "STRING 字段应生成 String getter。")
	assert_true(source.contains("return get_string(&\"name\", \"\")"), "STRING getter 应使用文本 helper。")
	assert_true(source.contains("func get_power() -> float:"), "FLOAT 字段应生成 float getter。")

	_assert_generated_source_compiles(source, "GFConfigAccess", "typed record 生成源码去掉全局类注册行后应能编译。")


func test_build_source_accepts_dictionary_columns_for_typed_record_wrappers() -> void:
	var generator: GFConfigAccessGenerator = GFConfigAccessGenerator.new()

	var source: String = generator.build_source([{
		"table_name": "enemy_data",
		"columns": [
			{ "field_name": "spawn_point", "value_type": "Vector2" },
			{ "name": "tags", "type": "array" },
		],
	}], "EnemyConfigAccess", "null", {
		"include_typed_records": true,
		"typed_record_class_suffix": "Row",
		"typed_record_method_pattern": "typed_{table}",
	})

	assert_true(source.contains("class EnemyDataRow:"), "字典 schema 应支持自定义记录包装类后缀。")
	assert_true(source.contains("static func typed_enemy_data(id: Variant, provider: Variant = null) -> EnemyDataRow:"), "typed record 方法应支持自定义模板。")
	assert_true(source.contains("func get_spawn_point() -> Vector2:"), "字符串类型声明应映射 Vector2 getter。")
	assert_true(source.contains("return get_vector2(&\"spawn_point\", Vector2.ZERO)"), "Vector2 getter 应使用向量 helper。")
	assert_true(source.contains("func get_tags() -> Array:"), "字典列名别名 name/type 应被识别。")

	_assert_generated_source_compiles(source, "EnemyConfigAccess", "字典 schema typed record 生成源码应能编译。")


func test_build_source_maps_column_value_types_to_typed_getters() -> void:
	var generator: GFConfigAccessGenerator = GFConfigAccessGenerator.new()

	var source: String = generator.build_source([{
		"table_name": "typed_values",
		"columns": [
			{ "field_name": "any_value", "value_type": "any" },
			{ "field_name": "enabled", "value_type": "bool" },
			{ "field_name": "count", "value_type": "int" },
			{ "field_name": "ratio", "value_type": "float" },
			{ "field_name": "title", "value_type": "string" },
			{ "field_name": "key", "value_type": "string_name" },
			{ "field_name": "position", "value_type": "vector2" },
			{ "field_name": "cell", "value_type": "vector2i" },
			{ "field_name": "tint", "value_type": "color" },
			{ "field_name": "payload", "value_type": "dictionary" },
			{ "field_name": "tags", "value_type": "array" },
		],
	}], "TypedValuesConfigAccess", "null", {
		"include_typed_records": true,
	})

	assert_true(source.contains("func get_any_value() -> Variant:"), "ANY 字段应保留 Variant getter。")
	assert_true(source.contains("return get_value(&\"any_value\", null)"), "ANY getter 应直接读取原始值。")
	assert_true(source.contains("func get_enabled() -> bool:"), "BOOL 字段应生成 bool getter。")
	assert_true(source.contains("return get_bool(&\"enabled\", false)"), "BOOL getter 应使用 bool helper。")
	assert_true(source.contains("func get_count() -> int:"), "INT 字段应生成 int getter。")
	assert_true(source.contains("func get_ratio() -> float:"), "FLOAT 字段应生成 float getter。")
	assert_true(source.contains("func get_title() -> String:"), "STRING 字段应生成 String getter。")
	assert_true(source.contains("func get_key() -> StringName:"), "STRING_NAME 字段应生成 StringName getter。")
	assert_true(source.contains("func get_position() -> Vector2:"), "VECTOR2 字段应生成 Vector2 getter。")
	assert_true(source.contains("func get_cell() -> Vector2i:"), "VECTOR2I 字段应生成 Vector2i getter。")
	assert_true(source.contains("func get_tint() -> Color:"), "COLOR 字段应生成 Color getter。")
	assert_true(source.contains("func get_payload() -> Dictionary:"), "DICTIONARY 字段应生成 Dictionary getter。")
	assert_true(source.contains("return get_dictionary(&\"payload\", {})"), "DICTIONARY getter 应返回字典副本 helper。")
	assert_true(source.contains("func get_tags() -> Array:"), "ARRAY 字段应生成 Array getter。")
	assert_true(source.contains("return get_array(&\"tags\", [])"), "ARRAY getter 应返回数组副本 helper。")

	_assert_generated_source_compiles(source, "TypedValuesConfigAccess", "基础列类型映射生成源码应能编译。")


func test_build_source_deduplicates_dirty_generated_identifiers() -> void:
	var generator: GFConfigAccessGenerator = GFConfigAccessGenerator.new()

	var source: String = generator.build_source([
		{
			"table_name": "class",
			"columns": [
				{ "field_name": "class", "value_type": "string" },
				{ "field_name": "value", "value_type": "int" },
				{ "field_name": "1st value", "value_type": "float" },
			],
		},
		{
			"table_name": "class!",
			"columns": [
				{ "field_name": "class", "value_type": "bool" },
			],
		},
	], "123 config access", "null", {
		"include_typed_records": true,
		"record_method_pattern": "{table}",
		"table_method_pattern": "{table}",
		"typed_record_method_pattern": "{table}",
	})

	assert_true(source.contains("class_name Table123ConfigAccess"), "非法访问器 class_name 应规范化为有效类名。")
	assert_true(source.contains("const CLASS: StringName = &\"class\""), "重复基础常量名应保留首个稳定名称。")
	assert_true(source.contains("const CLASS_2: StringName = &\"class!\""), "重复基础常量名应自动追加后缀。")
	assert_true(source.contains("class ClassRecord:"), "首个重复记录类名应保留稳定名称。")
	assert_true(source.contains("class ClassRecord_2:"), "重复记录类名应自动追加后缀。")
	assert_true(source.contains("static func method_class(id: Variant, provider: Variant = null) -> Variant:"), "保留字方法名应自动增加安全前缀。")
	assert_true(source.contains("static func method_class_2(provider: Variant = null) -> Variant:"), "同表 record/table 方法冲突应自动去重。")
	assert_true(source.contains("static func method_class_3(id: Variant, provider: Variant = null) -> ClassRecord:"), "typed record 方法冲突应继续自动去重。")
	assert_true(source.contains("func get_class_2() -> String:"), "字段 getter 不应覆盖 Object.get_class。")
	assert_true(source.contains("func get_value_2() -> int:"), "字段 getter 不应覆盖 typed record 基类 get_value。")
	assert_true(source.contains("func get_table_1st_value() -> float:"), "数字开头字段名应生成安全 getter。")

	_assert_generated_source_compiles(source, "Table123ConfigAccess", "脏表名和字段名生成源码应能编译。")


# --- 私有/辅助方法 ---

func _assert_generated_source_compiles(source: String, access_class_name: String, message: String) -> void:
	var report: Dictionary = GF_TRANSIENT_GDSCRIPT_TEST_SUPPORT.compile_and_release(
		source.replace("class_name %s\n" % access_class_name, "")
	)
	assert_eq(GFVariantData.get_option_int(report, "compile_error"), OK, message)
	assert_eq(GFVariantData.get_option_array(report, "cleanup_errors"), [], "动态编译测试必须释放生成脚本的内部类图。")
	assert_eq(GFVariantData.get_option_string(report, "configuration_error"), "", "动态编译测试必须使用匿名内建 GDScript 根。")


# --- 内部类 ---

class ConfigSchemaStub:
	var table_name: StringName = &""
	var metadata: Dictionary = {}
	var columns: Array = []

	func _init(p_table_name: StringName) -> void:
		table_name = p_table_name

	func get_table_key() -> StringName:
		return table_name


class MethodTrapConfigSchemaStub:
	var table_name: StringName = &""
	var metadata: Dictionary = {}
	var get_table_key_called: bool = false

	func _init(p_table_name: StringName) -> void:
		table_name = p_table_name

	func get_table_key() -> StringName:
		get_table_key_called = true
		return &"method_table"


class TableKeyConfigSchemaStub:
	var table_key: StringName = &""
	var metadata: Dictionary = {}

	func _init(p_table_key: StringName) -> void:
		table_key = p_table_key


class ConfigColumnStub:
	var field_name: StringName = &""
	var value_type: int = 0

	func _init(p_field_name: StringName, p_value_type: int) -> void:
		field_name = p_field_name
		value_type = p_value_type
