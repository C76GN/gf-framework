## GFConfigProviderAdapter: 外部配置来源的显式捕获适配器。
##
## 注册仅建立来源清单；prepare_tables() 捕获引用闭包，load_tables() 验收后发布。
## 查询继承已发布快照协议，不执行加载器。生成对象提供整表方法，或明确的
## record_ids 与记录方法；对象记录通过 record_projector 转为 Dictionary。
## [br]
## @api public
## [br]
## @category runtime_service
## [br]
## @since 7.0.0
class_name GFConfigProviderAdapter
extends GFResourceConfigProvider


# --- 私有变量 ---

## 独立于运行快照的来源声明。
## [br]
## @api private
var _sources: Dictionary = {}

## 来源清单变更代际。
## [br]
## @api private
var _source_generation: int = 0

## 最近准备结果，与活动数据状态分离。
## [br]
## @api private
var _load_reports: Dictionary = {}

## 禁止加载器重入准备；依赖通过 schema 声明。
## [br]
## @api private
var _preparing: bool = false

## 重入使外层候选一并失败。
## [br]
## @api private
var _preparation_invalidated: bool = false


# --- 公共方法 ---

## 注册或替换来源，不改变已发布的表。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param table_name: 非空表名。
## [br]
## @param source: 在显式准备时读取的来源。
## [br]
## @schema source: Array、按 ID 索引的 Dictionary、Object 或 Callable；Callable 接收 table_name、metadata 并返回上述数据。
## [br]
## @param options: 来源声明；集合和 schema 在注册时复制。
## [br]
## @schema options: Dictionary，可包含 schema: GFConfigTableSchema、id_field: StringName、table_method: StringName（默认 get_table）、record_method: StringName（默认 get_record）、record_ids: Array、record_projector: Callable（接收单条记录并返回 Dictionary）、metadata: Dictionary、content_version: String。
## [br]
## @return 声明合法时为 true；失败保留原来源。
func register_table_source(
	table_name: StringName,
	source: Variant,
	options: Dictionary = {}
) -> bool:
	if table_name == &"" or not _is_supported_source(source):
		return false
	var schema_value: Variant = options.get("schema")
	if schema_value != null and not schema_value is GFConfigTableSchema:
		return false
	var schema: GFConfigTableSchema = null
	if schema_value is GFConfigTableSchema:
		var author_schema: GFConfigTableSchema = schema_value
		if author_schema.table_name != &"" and author_schema.table_name != table_name:
			return false
		schema = author_schema.duplicate_schema()
		if schema == null:
			return false
		schema.table_name = table_name
	else:
		schema = GFConfigTableSchema.new()
		schema.table_name = table_name
		schema.id_field = GFVariantData.get_option_string_name(
			options,
			"id_field",
			&"id"
		)
	var projector_value: Variant = options.get(
		"record_projector",
		Callable()
	)
	var ids_value: Variant = options.get("record_ids", [])
	if not projector_value is Callable or not ids_value is Array:
		return false
	var ids: Array = ids_value
	var metadata: Dictionary = GFVariantData.get_option_dictionary(options, "metadata")
	var budget: GFConfigWorkBudget = GFConfigWorkBudget.new()
	if not budget.admit_value(ids, "source.record_ids") or not budget.admit_value(metadata, "source.metadata"):
		return false
	_sources[table_name] = {
		"source": source,
		"schema": schema,
		"table_method": GFVariantData.get_option_string_name(
			options,
			"table_method",
			&"get_table"
		),
		"record_method": GFVariantData.get_option_string_name(
			options,
			"record_method",
			&"get_record"
		),
		"record_ids": ids.duplicate(true),
		"record_projector": projector_value,
		"metadata": metadata.duplicate(true),
		"content_version": GFVariantData.get_option_string(options, "content_version"),
	}
	_source_generation += 1
	_load_reports[table_name] = { "status": &"registered", "error_kind": &"" }
	return true


## 注销来源；活动表通过 update_tables() 显式移除。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param table_name: 来源表名。
## [br]
## @return 是否移除了来源。
func unregister_table_source(table_name: StringName) -> bool:
	if not _sources.erase(table_name):
		return false
	_source_generation += 1
	var _removed: bool = _load_reports.erase(table_name)
	return true


## 释放来源和准备报告；已有快照仍可查询。
## [br]
## @api public
## [br]
## @since 7.0.0
func clear_table_sources() -> void:
	_sources.clear()
	_load_reports.clear()
	_source_generation += 1


## 检查来源是否存在，与活动表是否已加载分别查询。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param table_name: 来源表名。
## [br]
## @return 是否已注册来源。
func has_table_source(table_name: StringName) -> bool:
	return _sources.has(table_name)


## 返回来源清单；get_table_ids() 返回已发布清单。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 排序后的来源表名。
func get_source_ids() -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	for table_name: StringName in _sources:
		var _appended: bool = result.append(String(table_name))
	result.sort()
	return result


## 捕获指定来源及 schema 引用闭包，不发布候选。
##
## 每次请求重新捕获选定闭包；其他活动表复用旧快照。循环引用按集合捕获，
## 加载器递归准备则失败。加载器是同步可信代码；异步 IO 由项目完成后再注册。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param table_names: 本次请求的根表。
## [br]
## @param options: 内容版本、移除项和共享工作预算。
## [br]
## @schema options: Dictionary，与 prepare_update() 相同；非空来源 content_version 必须匹配 version。
## [br]
## @return 候选及其发布代际，失败不影响活动数据。
## [br]
## @schema return: Dictionary，含 ok、error_kind、snapshot、expected_generation；成功另含 prepared_tables、source_generation、validation_report、work_report。
func prepare_tables(table_names: PackedStringArray, options: Dictionary = {}) -> Dictionary:
	if _preparing:
		_preparation_invalidated = true
		return _failure(&"reentrant_preparation")
	_preparing = true
	_preparation_invalidated = false
	var source_generation: int = _source_generation
	var publication_generation: int = get_publication_generation()
	var declarations: Dictionary = _sources.duplicate()
	var result: Dictionary = _capture_sources(
		table_names,
		options,
		declarations
	)
	if _preparation_invalidated:
		result = _failure(&"reentrant_preparation")
	elif source_generation != _source_generation:
		result = _failure(&"source_changed")
	elif publication_generation != get_publication_generation():
		result = _failure(&"generation_conflict")
	_preparing = false
	result["expected_generation"] = publication_generation
	result["source_generation"] = source_generation
	for table_name: String in table_names:
		_load_reports[StringName(table_name)] = { "status": &"prepared" if GFVariantData.get_option_bool(result, "ok") else &"failed", "error_kind": result.get("error_kind", &""), }
	return result


## 显式准备并发布指定闭包，失败保留原活动快照。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param table_names: 请求的根表。
## [br]
## @param options: 与 prepare_tables() 相同。
## [br]
## @schema options: Dictionary，可包含 version、removed_tables、work_budget 或 work_limits。
## [br]
## @return 准备诊断与发布结果。
## [br]
## @schema return: Dictionary，含 ok、error_kind、generation，以及准备结果中的诊断字段。
func load_tables(table_names: PackedStringArray, options: Dictionary = {}) -> Dictionary:
	var result: Dictionary = prepare_tables(table_names, options)
	if not GFVariantData.get_option_bool(result, "ok"):
		return result
	var value: Variant = result.get("snapshot")
	if not value is GFConfigSnapshot:
		return _failure(&"invalid_snapshot")
	var snapshot: GFConfigSnapshot = value
	var publication: Dictionary = publish_snapshot(
		snapshot,
		GFVariantData.get_option_int(
			result,
			"expected_generation",
			-1
		)
	)
	result.merge(publication, true)
	return result


## 查询来源、最近准备结果与活动数据状态，不触发加载。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param table_name: 表名。
## [br]
## @return 独立报告副本。
## [br]
## @schema return: Dictionary，含 status: StringName（registered/prepared/failed/missing）、error_kind: StringName、registered: bool、loaded: bool、generation: int。
func get_load_report(table_name: StringName) -> Dictionary:
	var report: Dictionary = GFVariantData.get_option_dictionary(_load_reports, table_name).duplicate(true)
	if report.is_empty():
		report = { "status": &"missing", "error_kind": &"" }
	report["registered"] = has_table_source(table_name)
	report["loaded"] = has_table(table_name)
	report["generation"] = get_publication_generation()
	return report


## 返回不触发加载的来源与活动快照概况。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @return 独立诊断字典。
## [br]
## @schema return: Dictionary，含 source_ids: PackedStringArray、loaded_table_ids: PackedStringArray、source_generation: int、generation: int。
func get_debug_snapshot() -> Dictionary:
	return {
		"source_ids": get_source_ids(),
		"loaded_table_ids": get_table_ids(),
		"source_generation": _source_generation,
		"generation": get_publication_generation(),
	}


# --- 私有/辅助方法 ---

## 固定来源清单后计算闭包，再按顺序捕获每张表。
## [br]
## @api private
func _capture_sources(
	table_names: PackedStringArray,
	options: Dictionary,
	declarations: Dictionary
) -> Dictionary:
	var budget: GFConfigWorkBudget = GFConfigWorkBudget.from_options(options)
	var pending: PackedStringArray = table_names.duplicate()
	var selected: Dictionary = {}
	var cursor: int = 0
	while cursor < pending.size():
		if not budget.consume_work(1, "source.closure"):
			return _failure(&"work_budget_exceeded")
		var table_name: StringName = StringName(pending[cursor])
		cursor += 1
		if selected.has(table_name):
			continue
		if not declarations.has(table_name):
			return _failure(&"missing_source")
		var declaration: Dictionary = declarations[table_name]
		selected[table_name] = declaration
		var schema: GFConfigTableSchema = declaration["schema"]
		for reference_definition: GFConfigTableReference in schema.references:
			if reference_definition != null:
				var _appended: bool = pending.append(String(reference_definition.target_table_name))
	var names: Array = selected.keys()
	names.sort()
	var tables: Array[GFConfigTableResource] = []
	var version: String = GFVariantData.get_option_string(options, "version")
	if version.is_empty() and get_snapshot() != null:
		version = get_snapshot().get_version()
	for table_name: StringName in names:
		var declaration: Dictionary = selected[table_name]
		var source_version: String = declaration["content_version"]
		if not source_version.is_empty() and source_version != version:
			return _failure(&"content_version_mismatch")
		var table: GFConfigTableResource = _capture_table(
			table_name,
			declaration,
			budget
		)
		if table == null:
			return _failure(&"source_capture_failed")
		tables.append(table)
	var capture_options: Dictionary = options.duplicate()
	capture_options["work_budget"] = budget
	var _removed_limits: bool = capture_options.erase("work_limits")
	var result: Dictionary = prepare_update(tables, capture_options)
	result["prepared_tables"] = PackedStringArray(names)
	return result


## 将外部容器或生成对象一次性转换为隔离的作者记录。
## [br]
## @api private
func _capture_table(
	table_name: StringName,
	declaration: Dictionary,
	budget: GFConfigWorkBudget
) -> GFConfigTableResource:
	var source: Variant = declaration["source"]
	if source is Callable:
		var loader: Callable = source
		if not loader.is_valid():
			return null
		var metadata: Dictionary = declaration["metadata"]
		source = loader.call(
			table_name,
			metadata.duplicate(true)
		)
	if typeof(source) == TYPE_OBJECT:
		if not is_instance_valid(source):
			return null
		var source_object: Object = source
		var table_method: StringName = declaration["table_method"]
		if source_object.has_method(table_method):
			source = source_object.call(table_method)
		else:
			var record_method: StringName = declaration["record_method"]
			var record_ids: Array = declaration["record_ids"]
			if not source_object.has_method(record_method) or record_ids.is_empty():
				return null
			var records: Dictionary = {}
			for record_id: Variant in record_ids:
				if not budget.consume_work(1, "source.record") or not is_instance_valid(source_object):
					return null
				if records.has(record_id):
					return null
				records[record_id] = source_object.call(record_method, record_id)
			source = records
	if not source is Array and not source is Dictionary:
		return null
	var table: GFConfigTableResource = GFConfigTableResource.new()
	table.table_name = table_name
	var schema: GFConfigTableSchema = declaration["schema"]
	table.schema = schema.duplicate_schema({ "work_budget": budget })
	if table.schema == null:
		return null
	var projector: Callable = declaration["record_projector"]
	if source is Array:
		var source_array: Array = source
		for value: Variant in source_array:
			var record: Variant = _capture_record(
				value,
				projector,
				budget
			)
			if not record is Dictionary:
				return null
			table.records.append(record)
	else:
		var source_dictionary: Dictionary = source
		for record_id: Variant in source_dictionary:
			var value: Variant = _capture_record(
				source_dictionary[record_id],
				projector,
				budget
			)
			if not value is Dictionary:
				return null
			var record: Dictionary = value
			if not record.has(schema.id_field):
				record[schema.id_field] = record_id
			elif not GFVariantData.values_equal(
				record[schema.id_field],
				record_id,
				{ "match_string_names": true }
			):
				return null
			table.records.append(record)
	return table


## 验证外部记录形状与预算后复制；对象投影由项目明确提供。
## [br]
## @api private
func _capture_record(
	value: Variant,
	projector: Callable,
	budget: GFConfigWorkBudget
) -> Variant:
	if not budget.consume_work(1, "source.project_record"):
		return null
	var projected: Variant = projector.call(value) if projector.is_valid() else value
	if not projected is Dictionary or not budget.admit_value(projected, "source.record"):
		return null
	var record: Dictionary = projected
	return record.duplicate(true)


## 检查来源种类及对象存活状态。
## [br]
## @api private
func _is_supported_source(source: Variant) -> bool:
	if source is Array or source is Dictionary:
		return true
	if source is Callable:
		var loader: Callable = source
		return loader.is_valid()
	return typeof(source) == TYPE_OBJECT and is_instance_valid(source)


## 构造不包含候选的可观察失败。
## [br]
## @api private
func _failure(error_kind: StringName) -> Dictionary:
	return {
		"ok": false,
		"error_kind": error_kind,
		"snapshot": null,
		"expected_generation": get_publication_generation(),
	}
