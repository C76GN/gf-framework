## GFResourceConfigProvider: 通过已验收快照发布 Resource 配置集合。
##
## 作者资源可以编辑；运行查询读取隔离快照。替换、增量更新和移除均先验证
## 完整候选，随后检查发布代际，失败不会留下部分新表。
## [br]
## @api public
## [br]
## @category runtime_service
## [br]
## @since 5.2.0
class_name GFResourceConfigProvider
extends GFConfigProvider


# --- 公共方法 ---

## 准备完整数据库候选，保留准备开始时的代际供发布使用。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param database: 待捕获的作者数据库。
## [br]
## @param options: 候选工作预算。
## [br]
## @schema options: Dictionary，可包含 work_budget 或 work_limits；不接受增量 base_snapshot。
## [br]
## @return 捕获结果及 expected_generation。
## [br]
## @schema return: GFConfigSnapshot.capture() 结果，另含 expected_generation: int。
func prepare_database(database: GFConfigDatabaseResource, options: Dictionary = {}) -> Dictionary:
	var generation: int = get_publication_generation()
	if options.has("base_snapshot") or options.has("removed_tables"):
		return {
			"ok": false,
			"error_kind": &"invalid_replace_options",
			"snapshot": null,
			"expected_generation": generation,
		}
	var capture_options: Dictionary = options.duplicate()
	var result: Dictionary = GFConfigSnapshot.capture(database, capture_options)
	result["expected_generation"] = generation
	return result


## 捕获并原子替换完整数据库；校验期间发生其他发布时拒绝旧候选。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param database: 待发布的数据库。
## [br]
## @param options: 捕获预算。
## [br]
## @schema options: Dictionary，可包含 work_budget 或 work_limits。
## [br]
## @return 包含捕获诊断与发布状态的结果。
## [br]
## @schema return: Dictionary，含 ok、error_kind、generation、validation_report、work_report。
func replace_database(database: GFConfigDatabaseResource, options: Dictionary = {}) -> Dictionary:
	return _publish_prepared(prepare_database(database, options))


## 基于当前快照准备增量候选，校验合并后的跨表引用。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param tables: 本次新增或替换的表。
## [br]
## @schema tables: Array[GFConfigTableResource]，同一表只能出现一次。
## [br]
## @param options: 移除项、内容版本与捕获预算。
## [br]
## @schema options: Dictionary，可包含 removed_tables: PackedStringArray、version: String、work_budget 或 work_limits。
## [br]
## @return 捕获结果及 expected_generation；不修改当前快照。
## [br]
## @schema return: GFConfigSnapshot.capture() 结果，另含 expected_generation: int。
func prepare_update(tables: Array[GFConfigTableResource], options: Dictionary = {}) -> Dictionary:
	var generation: int = get_publication_generation()
	var base: GFConfigSnapshot = get_snapshot()
	var database: GFConfigDatabaseResource = GFConfigDatabaseResource.new()
	database.tables = tables.duplicate()
	if base != null:
		database.database_id = base.get_database_id()
		database.version = base.get_version()
	database.version = GFVariantData.get_option_string(
		options,
		"version",
		database.version
	)
	var capture_options: Dictionary = options.duplicate()
	capture_options["base_snapshot"] = base
	var result: Dictionary = GFConfigSnapshot.capture(database, capture_options)
	result["expected_generation"] = generation
	return result


## 验收并原子发布增量更新，包括明确声明的移除项。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param tables: 新增或替换的表。
## [br]
## @schema tables: Array[GFConfigTableResource]，每个表是本次候选。
## [br]
## @param options: 与 prepare_update() 相同。
## [br]
## @schema options: Dictionary，可包含 removed_tables、version、work_budget 或 work_limits。
## [br]
## @return 捕获诊断及发布状态，失败保留当前快照。
## [br]
## @schema return: Dictionary，含 ok、error_kind、generation、validation_report、work_report。
func update_tables(tables: Array[GFConfigTableResource], options: Dictionary = {}) -> Dictionary:
	return _publish_prepared(prepare_update(tables, options))


## 从完整数据库创建已发布的 Provider。
## [br]
## @api public
## [br]
## @since 5.2.0
## [br]
## @param database: 待捕获的数据库。
## [br]
## @return 已发布 Provider；任一候选校验失败时为 null。
static func from_database(database: GFConfigDatabaseResource) -> GFResourceConfigProvider:
	var provider: GFResourceConfigProvider = GFResourceConfigProvider.new()
	var result: Dictionary = provider.replace_database(database)
	return provider if GFVariantData.get_option_bool(result, "ok") else null


## 检查当前快照是否包含表，未准备不表示来源不存在。
## [br]
## @api public
## [br]
## @since 5.2.0
## [br]
## @param table_name: 表名。
## [br]
## @return 已准备时为 true。
func has_table(table_name: StringName) -> bool:
	var snapshot: GFConfigSnapshot = get_snapshot()
	return snapshot != null and snapshot.has_table(table_name)


## 取得已发布的表名。
## [br]
## @api public
## [br]
## @since 5.2.0
## [br]
## @return 排序后的表名。
func get_table_ids() -> PackedStringArray:
	var snapshot: GFConfigSnapshot = get_snapshot()
	return snapshot.get_table_ids() if snapshot != null else PackedStringArray()


## 取得已发布表的作者副本，用于构建下一次候选。
## [br]
## @api public
## [br]
## @since 5.2.0
## [br]
## @param table_name: 表名。
## [br]
## @return 表副本；未准备时为 null。
func get_table_resource(table_name: StringName) -> GFConfigTableResource:
	var snapshot: GFConfigSnapshot = get_snapshot()
	return snapshot.get_table_resource(table_name) if snapshot != null else null


## 取得全部已发布表的独立副本。
## [br]
## @api public
## [br]
## @since 5.2.0
## [br]
## @return 表资源副本；任一复制失败时返回空集合。
## [br]
## @schema return: Array[GFConfigTableResource]。
func get_table_resources() -> Array[GFConfigTableResource]:
	var result: Array[GFConfigTableResource] = []
	for table_name: String in get_table_ids():
		var table: GFConfigTableResource = get_table_resource(StringName(table_name))
		if table == null:
			return []
		result.append(table)
	return result


## 从当前快照查询记录副本，不隐式加载或更新表。
## [br]
## @api public
## [br]
## @since 5.2.0
## [br]
## @param table_name: 表名。
## [br]
## @param record_id: 记录 ID。
## [br]
## @schema record_id: Variant，使用项目声明的记录键类型。
## [br]
## @return 记录副本或 null。
## [br]
## @schema return: Dictionary 或 null。
func get_record(table_name: StringName, record_id: Variant) -> Variant:
	var snapshot: GFConfigSnapshot = get_snapshot()
	return snapshot.get_record(table_name, record_id) if snapshot != null else null


## 从当前快照查询整表副本，不执行来源回调。
## [br]
## @api public
## [br]
## @since 5.2.0
## [br]
## @param table_name: 表名。
## [br]
## @return 表记录副本或 null。
## [br]
## @schema return: Array[Dictionary] 或 null。
func get_table(table_name: StringName) -> Variant:
	var snapshot: GFConfigSnapshot = get_snapshot()
	return snapshot.get_table(table_name) if snapshot != null else null


## 按命名索引声明生成查询键。
## [br]
## @api public
## [br]
## @since 5.2.0
## [br]
## @param table_name: 表名。
## [br]
## @param index_id: 索引 ID。
## [br]
## @param record: 索引字段数据。
## [br]
## @schema record: Dictionary，含索引所需字段。
## [br]
## @return 查询键；无效时为空。
func make_index_key(
	table_name: StringName,
	index_id: StringName,
	record: Dictionary
) -> String:
	var snapshot: GFConfigSnapshot = get_snapshot()
	if snapshot == null:
		return ""
	return snapshot.make_index_key(
		table_name,
		index_id,
		record
	)


## 检查命名索引键。
## [br]
## @api public
## [br]
## @since 5.2.0
## [br]
## @param table_name: 表名。
## [br]
## @param index_id: 索引 ID。
## [br]
## @param index_key: 编码后的查询键。
## [br]
## @return 命中时为 true。
func has_index_key(
	table_name: StringName,
	index_id: StringName,
	index_key: String
) -> bool:
	var snapshot: GFConfigSnapshot = get_snapshot()
	if snapshot == null:
		return false
	return snapshot.has_index_key(
		table_name,
		index_id,
		index_key
	)


## 返回命名索引命中的记录副本。
## [br]
## @api public
## [br]
## @since 5.2.0
## [br]
## @param table_name: 表名。
## [br]
## @param index_id: 索引 ID。
## [br]
## @param index_key: 编码后的查询键。
## [br]
## @return 匹配记录副本；未命中时为空。
## [br]
## @schema return: Array[Dictionary]。
func get_index_records(
	table_name: StringName,
	index_id: StringName,
	index_key: String
) -> Array[Dictionary]:
	var snapshot: GFConfigSnapshot = get_snapshot()
	if snapshot == null:
		return []
	return snapshot.get_index_records(
		table_name,
		index_id,
		index_key
	)


## 返回命名索引命中的第一条记录副本。
## [br]
## @api public
## [br]
## @since 5.2.0
## [br]
## @param table_name: 表名。
## [br]
## @param index_id: 索引 ID。
## [br]
## @param index_key: 编码后的查询键。
## [br]
## @return 第一条匹配记录，未命中时为 null。
## [br]
## @schema return: Dictionary 或 null。
func get_index_record(
	table_name: StringName,
	index_id: StringName,
	index_key: String
) -> Variant:
	var snapshot: GFConfigSnapshot = get_snapshot()
	if snapshot == null:
		return null
	return snapshot.get_index_record(
		table_name,
		index_id,
		index_key
	)


# --- 私有/辅助方法 ---

## 保留捕获诊断，仅在候选和代际均有效时发布。
## [br]
## @api private
func _publish_prepared(prepared: Dictionary) -> Dictionary:
	if not GFVariantData.get_option_bool(prepared, "ok"):
		prepared["generation"] = get_publication_generation()
		return prepared
	var candidate: Variant = prepared.get("snapshot")
	if not candidate is GFConfigSnapshot:
		return { "ok": false, "error_kind": &"invalid_snapshot" }
	var snapshot: GFConfigSnapshot = candidate
	var result: Dictionary = publish_snapshot(
		snapshot,
		GFVariantData.get_option_int(
			prepared,
			"expected_generation",
			-1
		)
	)
	result["validation_report"] = prepared.get("validation_report", {})
	result["work_report"] = prepared.get("work_report", {})
	return result
