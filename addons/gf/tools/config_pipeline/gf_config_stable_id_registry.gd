## GFConfigStableIDRegistry: 项目所有的不可变稳定 ID 登记簿。
##
## ID 由作者明确指定；本类型不自动分配、不修改来源表、不写文件。
## 每张表独立登记符号和正整数 ID；删除产生永久墓碑，符号及 ID 均不可复用。
## [br]
## @api public
## [br]
## @category tool_api
## [br]
## @since unreleased
class_name GFConfigStableIDRegistry
extends RefCounted


# --- 私有变量 ---

## 已验收记录，调用者只能取得副本。
## [br]
## @api private
var _record: Dictionary = {}


# --- 公共方法 ---

## 创建尚无登记的空簿。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 可用于首次显式登记的空簿。
static func create_empty() -> GFConfigStableIDRegistry:
	return from_record(
		{
			"format": "gf.config.stable_ids",
			"format_version": 1,
			"tables": {},
		}
	)


## 验证完整历史记录；墓碑与活动条目共同占有 ID。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param record: 登记簿纯数据。
## [br]
## @schema record: 封闭 Dictionary，format:String="gf.config.stable_ids"、format_version:int=1、tables:Dictionary[String,Dictionary[String,Dictionary]]。table和symbol为1至256字符精确名称；条目仅含 id:String（1至2147483647的规范十进制文本）及 state:String（active/retired）。最多4096表、65536条目，总预算8MiB、262144节点、深度8；无循环、无原生对象。
## [br]
## @return 冻结登记簿；任何结构、重复 ID 或预算问题返回 null。
static func from_record(record: Dictionary) -> GFConfigStableIDRegistry:
	if (
		record.size() != 3
		or not record.get("format") is String
		or record.get("format") != "gf.config.stable_ids"
		or not record.get("format_version") is int
		or record["format_version"] != 1
		or not record.get("tables") is Dictionary
	):
		return null
	for key: Variant in record:
		if not key is String:
			return null
	var measured: Dictionary = GFDeterministicVariantSerializer.measure_canonical(
		record,
		{
			"max_depth": 8,
			"max_items": 262144,
			"max_output_bytes": 8388608,
			"max_string_length": 256,
		}
	)
	if not GFVariantData.get_option_bool(measured, "ok"):
		return null
	var tables: Dictionary = record["tables"]
	if tables.size() > 4096:
		return null
	var entry_count: int = 0
	for table: Variant in tables:
		if not _valid_name(table) or not tables[table] is Dictionary:
			return null
		var entries: Dictionary = tables[table]
		var ids: Dictionary = {}
		entry_count += entries.size()
		if entry_count > 65536:
			return null
		for symbol: Variant in entries:
			if not _valid_name(symbol) or not entries[symbol] is Dictionary:
				return null
			var entry: Dictionary = entries[symbol]
			var raw_id: Variant = entry.get("id")
			if (
				entry.size() != 2
				or not raw_id is String
				or not entry.get("state") is String
				or entry["state"] not in ["active", "retired"]
			):
				return null
			for key: Variant in entry:
				if not key is String:
					return null
			var id_text: String = raw_id
			if (
				not id_text.is_valid_int()
				or id_text.length() > 10
				or id_text.to_int() < 1
				or id_text.to_int() > 2147483647
				or str(id_text.to_int()) != id_text
				or ids.has(id_text)
			):
				return null
			ids[id_text] = true
	var registry: GFConfigStableIDRegistry = GFConfigStableIDRegistry.new()
	registry._record = record.duplicate(true)
	return registry


## 从有界 JSON 文本读取登记簿；ID 使用文本避免 JSON 数值精度变化。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param text: 最多8MiB的登记簿 JSON。
## [br]
## @return 完整验证的登记簿；失败返回 null。
static func from_json(text: String) -> GFConfigStableIDRegistry:
	if text.length() > 8388608 or text.to_utf8_buffer().size() > 8388608:
		return null
	var parser: JSON = JSON.new()
	if parser.parse(text) != OK or not parser.data is Dictionary:
		return null
	var record: Dictionary = parser.data
	if record.get("format_version") is float and record["format_version"] == 1.0:
		record["format_version"] = 1
	return from_record(record)


## 只读比较当前作者映射；不分配 ID、不改变登记簿、不写入文件。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param assignments: 对账范围内完整的活动符号映射；范围内没有出现的历史活动符号列为待退役。
## [br]
## @schema assignments: Dictionary[String,Dictionary[String,int]]，table到symbol到显式正整数ID；ID范围1至2147483647，每表唯一；名称与数量预算同from_record。局部范围中的整表退役必须显式提供该表的空字典。
## [br]
## @param options: 显式选择对账范围及允许恢复的原身份；省略时保留整簿对账和禁止恢复的行为。
## [br]
## @schema options: 封闭 Dictionary，可含 scope_tables:Array[String] 和 restorations:Dictionary[String,Dictionary[String,String]]。scope_tables为空时对账整簿；非空时最多4096个唯一精确表名，必须与assignments的表集合相同，范围外历史表保持不变。restorations以table/symbol到原ID的规范十进制String声明恢复，必须匹配历史记录及本次assignments中的int ID；已经active的同一声明幂等无变化。拒绝未知字段、其他身份、改号和非规范文本。
## [br]
## @return 差异或错误；失败不交付部分变化。
## [br]
## @schema return: 封闭 Dictionary，success:bool、changes:Array[Dictionary]、error:String。变化仅含 table:String、symbol:String、id:int、kind:String（register/retire/restore），按table和symbol排序；预览不会修改原登记簿。
func preview(assignments: Dictionary, options: Dictionary = {}) -> Dictionary:
	var plan: Dictionary = _reconcile(assignments, options)
	return {
		"success": plan["success"],
		"changes": plan["changes"],
		"error": plan["error"],
	}


## 构造显式映射的下一代登记簿；调用者负责把它与产物放入同一文件事务。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param assignments: 对账范围内完整的活动符号映射。
## [br]
## @schema assignments: 与 preview.assignments 相同的 Dictionary[String,Dictionary[String,int]]。
## [br]
## @param options: 对账表范围及原身份恢复声明；语义与 preview.options 相同。
## [br]
## @schema options: 封闭 Dictionary，可含 scope_tables:Array[String] 和 restorations:Dictionary[String,Dictionary[String,String]]；恢复ID使用原登记簿的规范十进制文本，作者映射ID仍必须是int。省略时对账整簿且不允许恢复。
## [br]
## @return 下一代冻结登记簿；范围不明确、身份不匹配、重复、改号或预算失败返回 null，原登记簿保持不变。
func with_assignments(assignments: Dictionary, options: Dictionary = {}) -> GFConfigStableIDRegistry:
	var plan: Dictionary = _reconcile(assignments, options)
	if not GFVariantData.get_option_bool(plan, "success"):
		return null
	return from_record(GFVariantData.get_option_dictionary(plan, "record"))


## 查询活动符号的稳定 ID。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param table: 表的登记命名空间。
## [br]
## @param symbol: 作者符号。
## [br]
## @return 活动条目的正整数 ID；未登记、已退役或无效实例返回0。
func get_id(table: String, symbol: String) -> int:
	var tables: Dictionary = GFVariantData.get_option_dictionary(_record, "tables")
	var entries: Dictionary = GFVariantData.get_option_dictionary(tables, table)
	var entry: Dictionary = GFVariantData.get_option_dictionary(entries, symbol)
	return GFVariantData.get_option_string(entry, "id").to_int() if entry.get("state") == "active" else 0


## 获取完整历史的隔离副本。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 登记簿记录；非工厂实例返回空字典。
## [br]
## @schema return: 与 from_record.record 相同的封闭记录。
func to_record() -> Dictionary:
	return _record.duplicate(true)


# --- 私有/辅助方法 ---

## 在已声明范围内有界建立新映射；恢复仅改变原身份的状态，历史占号关系保持不变。
## [br]
## @api private
func _reconcile(assignments: Dictionary, options: Dictionary) -> Dictionary:
	if _record.is_empty() or assignments.size() > 4096:
		return _failure("登记簿或表数量无效。")
	var measured: Dictionary = GFDeterministicVariantSerializer.measure_canonical(
		assignments,
		{
			"max_depth": 4,
			"max_items": 140000,
			"max_output_bytes": 8388608,
			"max_string_length": 256,
		}
	)
	if not GFVariantData.get_option_bool(measured, "ok"):
		return _failure("作者 ID 映射超过预算或不是原生数据。")
	var option_error: String = _validate_reconciliation_options(assignments, options)
	if not option_error.is_empty():
		return _failure(option_error)
	var scope_tables: Array = GFVariantData.get_option_array(options, "scope_tables")
	var restorations: Dictionary = GFVariantData.get_option_dictionary(options, "restorations")
	var selected_tables: Dictionary = {}
	for table_name: String in scope_tables:
		selected_tables[table_name] = true
	var candidate: Dictionary = _record.duplicate(true)
	var tables: Dictionary = candidate["tables"]
	var changes: Array[Dictionary] = []
	for table: Variant in assignments:
		if not _valid_name(table) or not assignments[table] is Dictionary:
			return _failure("作者 ID 映射必须使用合法表名和符号字典。")
		var desired: Dictionary = assignments[table]
		var entries: Dictionary = GFVariantData.get_option_dictionary(tables, table)
		var occupied: Dictionary = {}
		for symbol: String in entries:
			var entry: Dictionary = entries[symbol]
			occupied[entry["id"]] = symbol
		for symbol: Variant in desired:
			if (
				not _valid_name(symbol)
				or not desired[symbol] is int
				or desired[symbol] < 1
				or desired[symbol] > 2147483647
			):
				return _failure("符号或 ID 无效；ID 必须是明确的正整数。")
			var id_text: String = str(desired[symbol])
			if entries.has(symbol):
				var existing: Dictionary = entries[symbol]
				if existing["id"] != id_text:
					return _failure(
						"不能改变已登记 ID：%s/%s。"
						% [table, symbol]
					)
				if existing["state"] != "active":
					var restored_symbols: Dictionary = GFVariantData.get_option_dictionary(restorations, table)
					if not restored_symbols.has(symbol):
						return _failure(
							"已退役身份必须显式声明恢复：%s/%s。"
							% [table, symbol]
						)
					existing["state"] = "active"
					changes.append(
						{
							"table": table,
							"symbol": symbol,
							"id": desired[symbol],
							"kind": "restore",
						}
					)
			elif occupied.has(id_text):
				return _failure(
					"ID 已被活动符号或永久墓碑占用：%s/%s。"
					% [table, id_text]
				)
			else:
				entries[symbol] = { "id": id_text, "state": "active" }
				occupied[id_text] = symbol
				changes.append(
					{
						"table": table,
						"symbol": symbol,
						"id": desired[symbol],
						"kind": "register",
					}
				)
		tables[table] = entries
	for table: String in tables:
		if not selected_tables.is_empty() and not selected_tables.has(table):
			continue
		var desired: Dictionary = GFVariantData.get_option_dictionary(assignments, table)
		var entries: Dictionary = tables[table]
		for symbol: String in entries:
			var entry: Dictionary = entries[symbol]
			if entry["state"] == "active" and not desired.has(symbol):
				entry["state"] = "retired"
				var id_text: String = entry["id"]
				changes.append(
					{
						"table": table,
						"symbol": symbol,
						"id": id_text.to_int(),
						"kind": "retire",
					}
				)
	if from_record(candidate) == null:
		return _failure("登记簿历史超过预算。")
	var precedes: Callable = func(left: Dictionary, right: Dictionary) -> bool:
		return (
			left["table"] < right["table"]
			or (
				left["table"] == right["table"]
				and left["symbol"] < right["symbol"]
			)
		)
	changes.sort_custom(precedes)
	return {
		"success": true,
		"changes": changes,
		"record": candidate,
		"error": "",
	}


## 在复制历史前验收闭合选项；局部范围必须完整列出，恢复声明不能指向范围外或新身份。
## [br]
## @api private
func _validate_reconciliation_options(assignments: Dictionary, options: Dictionary) -> String:
	if options.size() > 2:
		return "稳定 ID 对账选项含有未知字段。"
	for option_key: Variant in options:
		if not option_key is String or option_key not in ["scope_tables", "restorations"]:
			return "稳定 ID 对账选项含有未知字段。"
	var scope_value: Variant = options.get("scope_tables", [])
	var restorations_value: Variant = options.get("restorations", {})
	if not scope_value is Array or not restorations_value is Dictionary:
		return "对账范围必须是表名数组，恢复声明必须是字典。"
	var scope_tables: Array = scope_value
	var restorations: Dictionary = restorations_value
	if scope_tables.size() > 4096 or restorations.size() > 4096:
		return "稳定 ID 对账选项超过表数量限制。"
	var measured: Dictionary = GFDeterministicVariantSerializer.measure_canonical(
		options,
		{
			"max_depth": 5,
			"max_items": 140000,
			"max_output_bytes": 8388608,
			"max_string_length": 256,
		}
	)
	if not GFVariantData.get_option_bool(measured, "ok"):
		return "稳定 ID 对账选项超过预算或不是原生数据。"
	var selected_tables: Dictionary = {}
	for table_name: Variant in scope_tables:
		if (
			not _valid_name(table_name)
			or selected_tables.has(table_name)
			or not assignments.has(table_name)
		):
			return "局部对账范围必须使用唯一精确表名，并显式提供每张表的完整映射。"
		selected_tables[table_name] = true
	if not selected_tables.is_empty() and assignments.size() != selected_tables.size():
		return "作者映射必须精确匹配局部对账范围，范围外的表不能参与更新。"
	var historical_tables: Dictionary = _record["tables"]
	for table_name: Variant in restorations:
		if (
			not _valid_name(table_name)
			or not restorations[table_name] is Dictionary
			or not assignments.get(table_name) is Dictionary
			or not historical_tables.get(table_name) is Dictionary
		):
			return "恢复声明必须引用本次作者映射中的历史表。"
		var restored_symbols: Dictionary = restorations[table_name]
		var desired: Dictionary = assignments[table_name]
		var historical_entries: Dictionary = historical_tables[table_name]
		for symbol: Variant in restored_symbols:
			if (
				not _valid_name(symbol)
				or not restored_symbols[symbol] is String
				or not desired.get(symbol) is int
				or not historical_entries.has(symbol)
			):
				return "恢复声明必须给出原符号及规范十进制文本 ID，并在作者表中保留同一整数 ID。"
			var original: Dictionary = historical_entries[symbol]
			var requested_id: String = restored_symbols[symbol]
			if requested_id != original["id"] or requested_id != str(desired[symbol]):
				return "恢复声明不能改变历史符号或 ID，也不接受非规范数字文本。"
	return ""


## 保持精确名称身份，不做隐式修剪或类型转换。
## [br]
## @api private
static func _valid_name(raw: Variant) -> bool:
	if not raw is String:
		return false
	var value: String = raw
	if (
		value.is_empty()
		or value.length() > 256
		or value != value.strip_edges()
	):
		return false
	for index: int in range(value.length()):
		if value.unicode_at(index) < 32:
			return false
	return true


## 失败不交付部分登记变化。
## [br]
## @api private
static func _failure(message: String) -> Dictionary:
	return {
		"success": false,
		"changes": [],
		"record": {},
		"error": message,
	}
