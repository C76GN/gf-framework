## GFConfigSnapshot: 已验收配置集合的独立查询快照。
##
## 捕获时隔离表、schema 和集合，查询返回副本；增量候选复用未改变的内部表。
## Resource 字段保留共享资产身份，不承诺资产内部状态不可变。自定义校验规则
## 仍属于受信任代码；快照只保证通过公开入口不能改写已捕获的配置集合。
## [br]
## @api public
## [br]
## @category value_object
## [br]
## @since unreleased
class_name GFConfigSnapshot
extends RefCounted


# --- 私有变量 ---

## 仅由捕获入口写入的表资源；不向外借出这些实例。
## [br]
## @api private
var _tables: Dictionary = {}

## 项目提供的配置集合身份。
## [br]
## @api private
var _database_id: StringName = &""

## 项目提供的内容版本，不以版本字符串大小判断新旧。
## [br]
## @api private
var _version: String = ""

## 完整校验成功后才设为可发布，直接 new 的对象不可发布。
## [br]
## @api private
var _ready: bool = false

## 未变表复用内容摘要；空摘要表示含不可规范编码的内容。
## [br]
## @api private
var _table_digests: Dictionary = {}

## 已捕获的纯数据摘要报告，不把 Resource 身份当作资产内容证明。
## [br]
## @api private
var _digest_report: Dictionary = {}


# --- 公共方法 ---

## 捕获完整或增量候选，校验失败不返回部分快照。
##
## database.tables 是本次新增/替换集合；提供 base_snapshot 时，其余表复用旧快照。
## 引用校验覆盖合并后的集合，移除仍被引用的表会失败。输入缓存索引不被信任。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param database: 本次候选的作者数据。
## [br]
## @param options: 增量来源、移除项和工作预算。
## [br]
## @schema options: Dictionary，可包含 base_snapshot: GFConfigSnapshot、removed_tables: PackedStringArray、work_budget: GFConfigWorkBudget 或 work_limits: Dictionary。
## [br]
## @return 包含完整候选或失败原因的结果。
## [br]
## @schema return: Dictionary，含 ok: bool、snapshot: GFConfigSnapshot 或 null、error_kind: StringName、validation_report: Dictionary、work_report: Dictionary。
static func capture(database: GFConfigDatabaseResource, options: Dictionary = {}) -> Dictionary:
	var budget: GFConfigWorkBudget = GFConfigWorkBudget.from_options(options)
	if database == null or not budget.is_ok():
		return _failure(
			&"invalid_candidate",
			{},
			budget
		)
	var base_value: Variant = options.get("base_snapshot")
	if base_value != null and not base_value is GFConfigSnapshot:
		return _failure(
			&"invalid_base_snapshot",
			{},
			budget
		)
	var snapshot: GFConfigSnapshot = GFConfigSnapshot.new()
	if base_value is GFConfigSnapshot:
		var base: GFConfigSnapshot = base_value
		if not base.is_ready() or base.get_database_id() != database.database_id:
			return _failure(
				&"invalid_base_snapshot",
				{},
				budget
			)
		snapshot._tables = base._tables.duplicate()
		snapshot._table_digests = base._table_digests.duplicate()
	snapshot._database_id = database.database_id
	snapshot._version = database.version
	var removed_value: Variant = options.get(
		"removed_tables",
		PackedStringArray()
	)
	if not removed_value is PackedStringArray:
		return _failure(
			&"invalid_removed_tables",
			{},
			budget
		)
	var removed_tables: PackedStringArray = removed_value
	if not budget.admit_value(removed_tables, "snapshot.removed_tables"):
		return _failure(
			&"work_budget_exceeded",
			{},
			budget
		)
	for table_name: String in removed_tables:
		var _removed: bool = snapshot._tables.erase(StringName(table_name))
		var _removed_digest: bool = snapshot._table_digests.erase(StringName(table_name))
	var candidates: Array[GFConfigTableResource] = database.tables.duplicate()
	var changed: Dictionary = {}
	var reports: GFConfigValidationReport = GFConfigValidationReport.new()
	var validation: Dictionary = reports.make_report()
	for source: GFConfigTableResource in candidates:
		if not budget.consume_work(1, "snapshot.table"):
			return _failure(
				&"work_budget_exceeded",
				{},
				budget
			)
		if source == null or source.get_table_key() == &"":
			return _failure(
				&"invalid_table",
				{},
				budget
			)
		var table_key: StringName = source.get_table_key()
		if changed.has(table_key) or removed_tables.has(String(table_key)):
			return _failure(
				&"duplicate_table",
				{},
				budget
			)
		if source.schema != null and source.schema.get_table_key() != table_key:
			return _failure(
				&"schema_table_mismatch",
				{},
				budget
			)
		if not budget.admit_value(source.records, "snapshot.records") or not budget.admit_value(source.metadata, "snapshot.metadata"):
			return _failure(
				&"invalid_table_payload",
				{},
				budget
			)
		var table: GFConfigTableResource = GFConfigTableResource.new()
		table.table_name = table_key
		table.records = source.get_records(true)
		table.metadata = source.metadata.duplicate(true)
		if source.schema != null:
			table.schema = source.schema.duplicate_schema({ "work_budget": budget })
			if table.schema == null:
				return _failure(
					&"invalid_schema",
					{},
					budget
				)
			var validation_schema: GFConfigTableSchema = table.schema.duplicate_schema({ "work_budget": budget })
			if validation_schema == null:
				return _failure(
					&"invalid_schema",
					{},
					budget
				)
			reports.merge_report(
				validation,
				validation_schema.validate_definition({ "work_budget": budget }),
				true
			)
			if not GFVariantData.get_option_bool(validation, "ok"):
				return _failure(
					&"validation_failed",
					validation,
					budget
				)
			var table_validation: Dictionary = validation_schema.validate_table(
				table.records,
				{ "work_budget": budget }
			)
			reports.merge_report(
				validation,
				table_validation,
				true
			)
			if not GFVariantData.get_option_bool(validation, "ok"):
				return _failure(
					&"validation_failed",
					validation,
					budget
				)
			table.records.assign(GFVariantData.get_option_array(table_validation, "data"))
		changed[table_key] = table
		snapshot._tables[table_key] = table
	var tables_by_name: Dictionary = {}
	var schemas: Array[GFConfigTableSchema] = []
	for table_name: String in snapshot.get_table_ids():
		var table: GFConfigTableResource = snapshot._get_table(StringName(table_name))
		tables_by_name[StringName(table_name)] = table.records
		if table.schema != null:
			schemas.append(table.schema)
	var references: Dictionary = GFConfigReferenceResolver.validate_tables(
		tables_by_name,
		schemas,
		{ "work_budget": budget, "validate_schema": false }
	)
	reports.merge_report(
		validation,
		references,
		true
	)
	if not GFVariantData.get_option_bool(validation, "ok") or not budget.is_ok():
		return _failure(
			&"validation_failed",
			validation,
			budget
		)
	for table_name: Variant in changed:
		var table: GFConfigTableResource = changed[table_name]
		var id_field: StringName = table.get_id_field()
		for record: Dictionary in table.records:
			if not record.has(id_field):
				continue
			var record_id: Variant = record[id_field]
			if not table.records_by_id.has(record_id):
				table.records_by_id[record_id] = record
		var _index_count: int = table.rebuild_indexes()
		_freeze_collections(table.records)
		_freeze_collections(table.metadata)
		_freeze_collections(table.records_by_id)
		_freeze_collections(table.records_by_index)
		var schema_description: Variant = null
		if table.schema != null:
			schema_description = table.schema.describe({ "work_budget": budget })
		var description: Dictionary = {
			"records": table.records,
			"schema": schema_description,
			"metadata": table.metadata,
		}
		if not budget.admit_value(description, "snapshot.digest"):
			return _failure(
				&"work_budget_exceeded",
				{},
				budget
			)
		var digest_options: Dictionary = {
			"allow_floats": true,
			"max_items": 1_000_000,
			"max_output_bytes": 64 * 1024 * 1024,
		}
		var hash_preparation: GFDeterministicVariantSerializer.CanonicalHashPreparation = GFDeterministicVariantSerializer.prepare_sha256_for_framework(description, digest_options)
		var measurement: Dictionary = hash_preparation.get_measurement()
		var digest: String = ""
		if GFVariantData.get_option_bool(measurement, "ok"):
			if not budget.consume_work(
				GFVariantData.get_option_int(measurement, "items"),
				"snapshot.digest"
			):
				return _failure(
					&"work_budget_exceeded",
					{},
					budget
				)
			digest = hash_preparation.finish_sha256()
		snapshot._table_digests[table_name] = digest
	snapshot._capture_digest_report()
	snapshot._ready = true
	return {
		"ok": true,
		"snapshot": snapshot,
		"error_kind": &"",
		"validation_report": validation,
		"work_report": budget.get_report(),
	}


## 检查快照是否已通过完整捕获与校验。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 可发布时为 true。
func is_ready() -> bool:
	return _ready


## 读取配置集合身份。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 捕获时的 database_id。
func get_database_id() -> StringName:
	return _database_id


## 读取项目声明的内容版本。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 捕获时的版本字符串。
func get_version() -> String:
	return _version


## 返回规范内容摘要与覆盖范围。
##
## 包含记录、schema 描述、表元数据、集合身份与版本。Resource 值或编码预算
## 不支持时 complete 为 false 且 value 为空；这不会拒绝合法的共享资产配置。
## 摘要不包含自定义校验代码实现，也不证明外部资产内容或跨版本浮点计算一致。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 独立摘要报告。
## [br]
## @schema return: Dictionary，含 algorithm: StringName、value: String、complete: bool、unavailable_tables: PackedStringArray。
func get_digest_report() -> Dictionary:
	return _digest_report.duplicate(true)


## 取得已捕获的表名，排序且不暴露内部集合。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 已准备表名列表。
func get_table_ids() -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	for table_name: StringName in _tables:
		var _appended: bool = result.append(String(table_name))
	result.sort()
	return result


## 检查该表是否已包含在此快照中。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param table_name: 表名。
## [br]
## @return 已准备时为 true；未准备不等价于来源不存在。
func has_table(table_name: StringName) -> bool:
	return _tables.has(table_name)


## 取得独立的表资源副本，可用于编辑新的候选。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param table_name: 表名。
## [br]
## @return 表副本；未准备时为 null。
func get_table_resource(table_name: StringName) -> GFConfigTableResource:
	var table: GFConfigTableResource = _get_table(table_name)
	return table.duplicate_table() if table != null else null


## 取得独立的 schema 副本。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param table_name: 表名。
## [br]
## @return schema 副本；表或声明不存在时为 null。
func get_schema(table_name: StringName) -> GFConfigTableSchema:
	var table: GFConfigTableResource = _get_table(table_name)
	return table.schema.duplicate_schema() if table != null and table.schema != null else null


## 检查 schema 是否存在，不复制声明。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param table_name: 表名。
## [br]
## @return 已捕获该表且包含声明时为 true。
func has_schema(table_name: StringName) -> bool:
	var table: GFConfigTableResource = _get_table(table_name)
	return table != null and table.schema != null


## 按稳定记录 ID 查询副本。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param table_name: 表名。
## [br]
## @param record_id: 项目记录 ID。
## [br]
## @schema record_id: Variant，使用表 schema 声明的 ID 值类型。
## [br]
## @return 记录副本或 null。
## [br]
## @schema return: Dictionary 记录或 null。
func get_record(table_name: StringName, record_id: Variant) -> Variant:
	var table: GFConfigTableResource = _get_table(table_name)
	if table == null:
		return null
	var value: Variant = table.records_by_id.get(record_id)
	if value is Dictionary:
		var record: Dictionary = value
		return record.duplicate(true)
	return null


## 取得整表记录副本。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param table_name: 表名。
## [br]
## @return 已准备表的记录副本；未准备时为 null。
## [br]
## @schema return: Array[Dictionary] 或 null。
func get_table(table_name: StringName) -> Variant:
	var table: GFConfigTableResource = _get_table(table_name)
	if table == null:
		return null
	return table.get_records()


## 按命名索引声明生成键。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param table_name: 表名。
## [br]
## @param index_id: 索引 ID。
## [br]
## @param record: 参与索引的字段数据。
## [br]
## @schema record: Dictionary，含命名索引要求的字段。
## [br]
## @return 索引键；缺少表或索引时为空。
func make_index_key(
	table_name: StringName,
	index_id: StringName,
	record: Dictionary
) -> String:
	var table: GFConfigTableResource = _get_table(table_name)
	return table.make_index_key(index_id, record) if table != null else ""


## 取得命名索引命中的记录副本。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param table_name: 表名。
## [br]
## @param index_id: 索引 ID。
## [br]
## @param index_key: 编码后的索引键。
## [br]
## @return 命中记录，未命中时为空。
## [br]
## @schema return: Array[Dictionary]，不会暴露内部记录集合。
func get_index_records(
	table_name: StringName,
	index_id: StringName,
	index_key: String
) -> Array[Dictionary]:
	var records: Array[Dictionary] = []
	for record: Dictionary in _get_index_records(
		table_name,
		index_id,
		index_key
	):
		records.append(record.duplicate(true))
	return records


## 检查索引键，不复制命中记录。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param table_name: 表名。
## [br]
## @param index_id: 索引 ID。
## [br]
## @param index_key: 编码后的索引键。
## [br]
## @return 命中时为 true。
func has_index_key(
	table_name: StringName,
	index_id: StringName,
	index_key: String
) -> bool:
	return not _get_index_records(
		table_name,
		index_id,
		index_key
	).is_empty()


## 取得索引首条记录副本，避免复制全部命中项。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param table_name: 表名。
## [br]
## @param index_id: 索引 ID。
## [br]
## @param index_key: 编码后的索引键。
## [br]
## @return 首条记录副本或 null。
## [br]
## @schema return: Dictionary 或 null。
func get_index_record(
	table_name: StringName,
	index_id: StringName,
	index_key: String
) -> Variant:
	var records: Array = _get_index_records(
		table_name,
		index_id,
		index_key
	)
	if records.is_empty():
		return null
	var record: Dictionary = records[0]
	return record.duplicate(true)


# --- 私有/辅助方法 ---

## 合并各表摘要，任一表不能完整编码时不提供部分内容 hash。
## [br]
## @api private
func _capture_digest_report() -> void:
	var unavailable: PackedStringArray = PackedStringArray()
	for table_name: String in get_table_ids():
		if GFVariantData.get_option_string(_table_digests, table_name).is_empty():
			var _appended: bool = unavailable.append(table_name)
	var descriptor: Dictionary = {
		"database_id": _database_id,
		"version": _version,
		"tables": _table_digests,
	}
	_digest_report = {
		"algorithm": &"sha256",
		"value": GFDeterministicVariantSerializer.sha256(descriptor) if unavailable.is_empty() else "",
		"complete": unavailable.is_empty(),
		"unavailable_tables": unavailable,
	}


## 查询已构建的冻结索引；运行查询不再扫描或重建索引。
## [br]
## @api private
func _get_index_records(
	table_name: StringName,
	index_id: StringName,
	index_key: String
) -> Array:
	var table: GFConfigTableResource = _get_table(table_name)
	if table == null:
		return []
	var index: Dictionary = GFVariantData.get_option_dictionary(table.records_by_index, index_id)
	return GFVariantData.get_option_array(index, index_key)


## 只在本文件内借用已隔离表，公开查询必须返回副本。
## [br]
## @api private
func _get_table(table_name: StringName) -> GFConfigTableResource:
	var value: Variant = _tables.get(table_name)
	return value if value is GFConfigTableResource else null


## 构造不含可发布候选的失败结果。
## [br]
## @api private
static func _failure(
	kind: StringName,
	report: Dictionary,
	budget: GFConfigWorkBudget
) -> Dictionary:
	return {
		"ok": false,
		"snapshot": null,
		"error_kind": kind,
		"validation_report": report,
		"work_report": budget.get_report(),
	}


## 捕获已通过无循环预算检查；冻结集合防止内部查询误写。
## [br]
## @api private
static func _freeze_collections(value: Variant) -> void:
	if value is Dictionary:
		var dictionary: Dictionary = value
		if dictionary.is_read_only():
			return
		for key: Variant in dictionary:
			_freeze_collections(dictionary[key])
		dictionary.make_read_only()
	elif value is Array:
		var array: Array = value
		if array.is_read_only():
			return
		for item: Variant in array:
			_freeze_collections(item)
		array.make_read_only()
