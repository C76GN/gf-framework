# 按稳定记录身份比较作者 IR，输出结构与字段名称，不携带业务值。
# 内部 classless helper，不形成独立公开类型。
extends RefCounted


# --- 公共方法 ---

## 有界比较两代已验收 IR，引用影响取两代声明的并集。
## [br]
## @api framework_internal
## [br]
## @param before: 旧版作者 IR；首次建立基线时可为空。
## [br]
## @param after: 新版作者 IR。
## [br]
## @param targets: 当前消费目标声明。
## [br]
## @schema targets: Array[GFConfigPipelineConsumerTarget]。
## [br]
## @param options: 共享构建预算。
## [br]
## @schema options: Dictionary，可含 work_budget 或 work_limits。
## [br]
## @return 无业务值的保守影响报告；不稳定记录身份或不支持摘要的值标记unknown。
## [br]
## @schema return: Dictionary，success:bool、tables:Array[Dictionary]、affected_tables:PackedStringArray、affected_targets:PackedStringArray、error:String。每表含table:String、kind:String（added/removed/changed）、schema_changed:bool、record_comparison:String（complete/unknown）、added:PackedStringArray、removed:PackedStringArray、changed:Array[{id:String,fields:PackedStringArray}]；ID为带Variant类型的规范文本。影响闭包是保守上界，不表示业务值一定受影响。
static func compare(
	before: GFConfigPipelineIR,
	after: GFConfigPipelineIR,
	targets: Array[GFConfigPipelineConsumerTarget] = [],
	options: Dictionary = {}
) -> Dictionary:
	if (
		after == null
		or not after.is_sealed()
		or (
			before != null
			and not before.is_sealed()
		)
		or targets.size() > 64
	):
		return _failure("差异比较需要完整封存的 IR。")
	var budget: GFConfigWorkBudget = GFConfigWorkBudget.from_options(options)
	var old_tables: Dictionary = _table_lookup(before)
	var new_tables: Dictionary = _table_lookup(after)
	var names: PackedStringArray = _union_names(old_tables, new_tables)
	if names.size() > 4096:
		return _failure("差异表数量超过4096。")
	var changes: Array[Dictionary] = []
	var affected: Dictionary = {}
	var reverse: Dictionary = {}
	for table_name: String in names:
		var old_table: GFConfigPipelineTableIR = old_tables.get(table_name)
		var new_table: GFConfigPipelineTableIR = new_tables.get(table_name)
		for table: GFConfigPipelineTableIR in [old_table, new_table]:
			if table == null:
				continue
			var schema: GFConfigTableSchema = table.get_schema()
			if schema == null:
				continue
			for reference_definition: GFConfigTableReference in schema.references:
				if not budget.consume_work(1, "diff.reference"):
					return _failure("引用影响分析预算耗尽。")
				if reference_definition != null:
					var users: Dictionary = GFVariantData.get_option_dictionary(
						reverse,
						String(reference_definition.target_table_name)
					)
					users[table_name] = true
					reverse[String(reference_definition.target_table_name)] = users
		var old_schema: GFConfigTableSchema = old_table.get_schema() if old_table != null else null
		var new_schema: GFConfigTableSchema = new_table.get_schema() if new_table != null else null
		var old_schema_hash: String = _fingerprint(old_schema.describe() if old_schema != null else {})
		var new_schema_hash: String = _fingerprint(new_schema.describe() if new_schema != null else {})
		var schema_known: bool = not old_schema_hash.is_empty() and not new_schema_hash.is_empty()
		var schema_changed: bool = not schema_known or old_schema_hash != new_schema_hash
		var old_rows: Dictionary = _record_lookup(old_table, budget)
		var new_rows: Dictionary = _record_lookup(new_table, budget)
		var known: bool = (
			old_rows["success"]
			and new_rows["success"]
			and schema_known
		)
		if not budget.is_ok():
			return _failure("差异比较预算耗尽。")
		var change_kind: String = "changed"
		if old_table == null:
			change_kind = "added"
		elif new_table == null:
			change_kind = "removed"
		var change: Dictionary = {
			"table": table_name,
			"kind": change_kind,
			"schema_changed": schema_changed,
			"record_comparison": "complete" if known else "unknown",
			"added": PackedStringArray(),
			"removed": PackedStringArray(),
			"changed": [],
		}
		if known:
			var old_records: Dictionary = old_rows["records"]
			var new_records: Dictionary = new_rows["records"]
			var added: PackedStringArray = []
			var removed: PackedStringArray = []
			var modified: Array[Dictionary] = []
			for id: String in _union_names(old_records, new_records):
				if not budget.consume_work(1, "diff.record"):
					return _failure("差异比较预算耗尽。")
				if not old_records.has(id):
					var _added: bool = added.append(id)
				elif not new_records.has(id):
					var _removed: bool = removed.append(id)
				else:
					var old_record: Dictionary = old_records[id]
					var new_record: Dictionary = new_records[id]
					var fields: PackedStringArray = []
					for field: String in _union_names(old_record, new_record):
						if not budget.consume_work(1, "diff.field"):
							return _failure("差异比较预算耗尽。")
						var old_hash: String = _fingerprint(old_record.get(field))
						var new_hash: String = _fingerprint(new_record.get(field))
						if old_hash.is_empty() or new_hash.is_empty():
							change["record_comparison"] = "unknown"
						if (
							old_record.has(field) != new_record.has(field)
							or old_hash.is_empty()
							or new_hash.is_empty()
							or old_hash != new_hash
						):
							var _field_added: bool = fields.append(field)
					if not fields.is_empty():
						modified.append({ "id": id, "fields": fields })
			change["added"] = added
			change["removed"] = removed
			change["changed"] = modified
		var added_ids: PackedStringArray = change["added"]
		var removed_ids: PackedStringArray = change["removed"]
		var changed_rows: Array = change["changed"]
		if (
			old_table == null
			or new_table == null
			or schema_changed
			or not known
			or not added_ids.is_empty()
			or not removed_ids.is_empty()
			or not changed_rows.is_empty()
		):
			changes.append(change)
			affected[table_name] = true
	var pending: PackedStringArray = _union_names(affected, {})
	var cursor: int = 0
	while cursor < pending.size():
		var users: Dictionary = GFVariantData.get_option_dictionary(
			reverse,
			pending[cursor]
		)
		cursor += 1
		for table_name: String in users:
			if not budget.consume_work(1, "diff.reference_impact"):
				return _failure("引用影响分析预算耗尽。")
			if not affected.has(table_name):
				affected[table_name] = true
				var _appended: bool = pending.append(table_name)
	var affected_targets: PackedStringArray = []
	for target: GFConfigPipelineConsumerTarget in targets:
		if target == null or not GFVariantData.get_option_bool(
			target.capture(),
			"success"
		):
			return _failure("消费目标声明无效。")
		for root: String in target.root_tables:
			if affected.has(root):
				var _appended: bool = affected_targets.append(String(target.target_id))
				break
	affected_targets.sort()
	return {
		"success": true,
		"tables": changes,
		"affected_tables": _union_names(affected, {}),
		"affected_targets": affected_targets,
		"error": "",
	}


# --- 私有/辅助方法 ---

## 保留封存表引用；所有值读取仍经 IR 隔离入口。
## [br]
## @api private
static func _table_lookup(ir: GFConfigPipelineIR) -> Dictionary:
	var result: Dictionary = {}
	if ir != null:
		for table: GFConfigPipelineTableIR in ir.get_tables():
			result[String(table.get_table_name())] = table
	return result


## 没有稳定唯一 ID 的表不按数组下标伪造记录身份。
## [br]
## @api private
static func _record_lookup(table: GFConfigPipelineTableIR, budget: GFConfigWorkBudget) -> Dictionary:
	var records: Dictionary = {}
	if table == null:
		return { "success": true, "records": records }
	var schema: GFConfigTableSchema = table.get_schema()
	if schema == null or schema.id_field == &"":
		return { "success": false, "records": {} }
	for row: Dictionary in table.get_records():
		if not budget.admit_value(row, "diff.capture") or not row.has(schema.id_field):
			return { "success": false, "records": {} }
		var id: Variant = row[schema.id_field]
		if (
			not id is int
			and not id is String
			and not id is StringName
		):
			return { "success": false, "records": {} }
		var identity: String = (
			"%d:%s"
			% [typeof(id), var_to_str(id)]
		)
		if records.has(identity):
			return { "success": false, "records": {} }
		records[identity] = row
	return { "success": true, "records": records }


## 规范类型摘要不会把int与float或大整数混为相同值。
## [br]
## @api private
static func _fingerprint(value: Variant) -> String:
	var options: Dictionary = {
		"allow_floats": true,
		"max_depth": 64,
		"max_items": 100000,
		"max_output_bytes": 8388608,
		"max_string_length": 8388608,
	}
	if not GFVariantData.get_option_bool(
		GFDeterministicVariantSerializer.measure_canonical(value, options),
		"ok"
	):
		return ""
	return GFDeterministicVariantSerializer.sha256(value, options)


## 稳定排序名称并集；非文本字段由上游规范化契约拒绝。
## [br]
## @api private
static func _union_names(left: Dictionary, right: Dictionary) -> PackedStringArray:
	var names: Dictionary = {}
	for key: Variant in left:
		names[GFVariantData.to_text(key)] = true
	for key: Variant in right:
		names[GFVariantData.to_text(key)] = true
	var result: PackedStringArray = []
	for entry_name: String in names:
		var _appended: bool = result.append(entry_name)
	result.sort()
	return result


## 预算或契约失败不输出部分影响分析。
## [br]
## @api private
static func _failure(message: String) -> Dictionary:
	return {
		"success": false,
		"tables": [],
		"affected_tables": PackedStringArray(),
		"affected_targets": PackedStringArray(),
		"error": message,
	}
