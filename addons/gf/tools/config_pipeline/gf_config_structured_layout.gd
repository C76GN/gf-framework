## GFConfigStructuredLayout: 把显式表格布局映射为未经类型转换的嵌套记录。
##
## 每实例只处理一次 decode。列路径使用 String 对象键和非负 int 数组下标，
## 不执行表达式、不查 schema；空单元格表示缺失，集合只从有值的物理行追加。
## [br]
## @api framework_internal
## [br]
## @category internal_helper
class_name GFConfigStructuredLayout
extends RefCounted


# --- 私有变量 ---

## 本次解码共用的预算；任何失败后不再返回部分记录。
## [br]
## @api private
var _budget: GFConfigWorkBudget = null

## 已校验的布局选项，仅存活于当前解码。
## [br]
## @api private
var _layout: Dictionary = {}

## 来源与工作表身份，不从单元格内容推断。
## [br]
## @api private
var _identity: Dictionary = {}

## 首次失败；后续写入不能覆盖最初的物理定位。
## [br]
## @api private
var _failure: Dictionary = {}

## 按逻辑行保存的稀疏单元格；转置只变坐标，不改变物理位置。
## [br]
## @api private
var _rows: Dictionary = {}

## 逻辑列数量，在分配或遍历矩形区域前受工作预算限制。
## [br]
## @api private
var _width: int = 0

## 逻辑末行号；用于发现稀疏 XML 中隐含的空行。
## [br]
## @api private
var _height: int = 0

## 表头逻辑行，必须严格递增且不能和数据区混合。
## [br]
## @api private
var _header_rows: Array[int] = []

## 实际参与输出的根字段，供后续同一 schema 验证。
## [br]
## @api private
var _header: PackedStringArray = PackedStringArray()

## 标量绑定列表；路径和列已在读数据前完整校验。
## [br]
## @api private
var _bindings: Array[Dictionary] = []

## 集合绑定列表；每项拥有独立的元素列和可选 map 键列。
## [br]
## @api private
var _collections: Array[Dictionary] = []

## 物理列所有权，防止同列被隐式消费或多次映射。
## [br]
## @api private
var _claimed_columns: Dictionary = {}

## 显式忽略的列不决定记录存在性，避免只有注释的行产生空记录。
## [br]
## @api private
var _ignored_columns: Dictionary = {}

## CSV 逻辑行到物理起始行的映射，防止带换行的引用单元格制造虚假空行。
## [br]
## @api private
var _physical_rows: Dictionary = {}


# --- 框架内部方法 ---

## 映射完整表格；失败只返回诊断，不泄漏已组装的部分记录。
## [br]
## @api framework_internal
## [br]
## @param rows: 稀疏物理行。
## [br]
## @schema rows: Array[Dictionary]，每项包含 row_number:int、cells:Dictionary[int,String]，CSV 另含连续的 logical_row:int。
## [br]
## @param options: 已准入的解析选项及共享工作预算。
## [br]
## @schema options: Dictionary，包含 layout、work_budget、source 和可选 sheet_name、sheet_path。
## [br]
## @param merged_ranges: 工作表声明的合并区域；只允许位于完整表头区域。
## [br]
## @schema merged_ranges: Array[Dictionary]，每项包含 first_row、last_row、first_column、last_column，均为一基物理坐标。
## [br]
## @return: 与平表 Layout 相同形状的完整结果。
## [br]
## @schema return: Dictionary，包含 success、data、header、header_location、row_locations；字段位置同时含 field_path、field_segments、物理 line、column、cell、source、sheet_name、sheet_path。
func decode(
	rows: Array[Dictionary],
	options: Dictionary,
	merged_ranges: Array[Dictionary] = []
) -> Dictionary:
	_budget = GFConfigWorkBudget.from_options(options)
	_layout = GFVariantData.get_option_dictionary(options, "layout")
	_identity = {
		"source": GFVariantData.get_option_string(options, "source"),
		"sheet_name": GFVariantData.get_option_string(options, "sheet_name"),
		"sheet_path": GFVariantData.get_option_string(options, "sheet_path"),
	}
	if not _validate_options(options):
		return _result_failure()
	if not _collect_cells(rows, options):
		return _result_failure()
	if not _expand_merged_headers(merged_ranges):
		return _result_failure()
	if not _compile_bindings():
		return _result_failure()
	return _collect_records()


# --- 私有/辅助方法 ---

## 拒绝未知或互相矛盾的结构化布局选项，避免拼写错误得到成功结果。
## [br]
## @api private
func _validate_options(options: Dictionary) -> bool:
	var allowed: Array[String] = [
		"orientation",
		"header_rows",
		"columns",
		"collections",
		"record_key_column",
		"ignored_columns",
		"blank_rows",
		"empty_string_token",
	]
	for key: Variant in _layout:
		if not key is String:
			return _fail("invalid_layout_option", "Layout option keys must be strings.")
		var option_key: String = key
		if not allowed.has(option_key):
			return _fail(
				"invalid_layout_option",
				"Unknown structured layout option: %s." % str(key)
			)
	var orientation: Variant = _layout.get("orientation", "rows")
	if orientation != "rows" and orientation != "columns":
		return _fail("invalid_layout_orientation", "Layout orientation must be rows or columns.")
	var blank_rows: Variant = _layout.get("blank_rows", "reject")
	if blank_rows != "reject" and blank_rows != "skip":
		return _fail("invalid_layout_blank_rows", "Layout blank_rows must be reject or skip.")
	if _layout.has("empty_string_token"):
		var token: Variant = _layout["empty_string_token"]
		if not token is String or token == "":
			return _fail("invalid_layout_empty_string", "empty_string_token must be a non-empty string.")
	for incompatible: String in [
		"header_row",
		"comment_prefixes",
		"comment_row_prefixes",
		"comment_column_prefixes",
		"condition_symbols",
		"enable_condition_directives",
	]:
		if options.has(incompatible):
			return _fail(
				"conflicting_layout_options",
				"Structured layout does not combine with %s." % incompatible
			)
	var header_value: Variant = _layout.get(
		"header_rows",
		[1]
	)
	if not header_value is Array:
		return _fail("invalid_layout_headers", "header_rows must be an array of increasing positive integers.")
	var header_values: Array = header_value
	for item: Variant in header_values:
		if not item is int:
			return _fail("invalid_layout_headers", "header_rows must contain integers.")
		var row_number: int = item
		if (
			row_number <= 0
			or (
				not _header_rows.is_empty()
				and row_number <= _header_rows[_header_rows.size() - 1]
			)
		):
			return _fail("invalid_layout_headers", "header_rows must be strictly increasing and positive.")
		_header_rows.append(row_number)
	if _header_rows.is_empty():
		return _fail("invalid_layout_headers", "At least one header row is required.")
	if _layout.has("record_key_column"):
		var key_column: Variant = _layout["record_key_column"]
		if not key_column is int or key_column <= 0:
			return _fail("invalid_layout_record_key", "record_key_column must be a positive integer.")
	return _budget.is_ok()


## 将输入映射成逻辑坐标，并在展开稀疏/转置区域前一次预付完整访问工作量。
## [br]
## @api private
func _collect_cells(rows: Array[Dictionary], options: Dictionary) -> bool:
	var transpose: bool = _layout.get("orientation", "rows") == "columns"
	var trim_cells: bool = GFVariantData.get_option_bool(
		options,
		"trim_cells",
		true
	)
	var seen_rows: Dictionary = {}
	for row_info: Dictionary in rows:
		if not _budget.consume_work(1, "layout.structured.rows"):
			return false
		var physical_row: int = GFVariantData.get_option_int(row_info, "row_number")
		if physical_row <= 0 or seen_rows.has(physical_row):
			return _fail("invalid_layout_row", "Physical row numbers must be positive and unique.")
		seen_rows[physical_row] = true
		var grid_row: int = GFVariantData.get_option_int(
			row_info,
			"logical_row",
			physical_row
		)
		_physical_rows[grid_row] = physical_row
		var cells: Dictionary = GFVariantData.get_option_dictionary(row_info, "cells")
		if not transpose:
			_height = maxi(_height, grid_row)
		for key: Variant in cells:
			if not _budget.consume_work(1, "layout.structured.cells"):
				return false
			if (
				not key is int
				or key < 0
				or not cells[key] is String
			):
				return _fail("invalid_layout_cell", "Cells require non-negative integer columns and text values.")
			var physical_column: int = key + 1
			var text: String = cells[key]
			if trim_cells:
				text = text.strip_edges()
			var logical_row: int = physical_column if transpose else physical_row
			var logical_column: int = grid_row if transpose else physical_column
			if not transpose:
				logical_row = grid_row
			_width = maxi(_width, logical_column)
			_height = maxi(_height, logical_row)
			var logical_cells: Dictionary = _rows.get(logical_row, {})
			if logical_cells.has(logical_column):
				return _fail("duplicate_layout_cell", "A physical cell was supplied twice.")
			var location: Dictionary = _identity.duplicate()
			location["line"] = physical_row
			location["column"] = physical_column
			location["column_index"] = physical_column - 1
			location["cell"] = _cell_label(physical_row, physical_column)
			logical_cells[logical_column] = { "text": text, "location": location }
			_rows[logical_row] = logical_cells
	if _width <= 0 or _height < _header_rows[_header_rows.size() - 1]:
		return _fail("missing_layout_header", "Structured table headers are missing.")
	if not _budget.consume_work(_width, "layout.structured.width") or not _budget.consume_work(_height, "layout.structured.height"):
		return false
	if not _budget.consume_work(
		_width * _height,
		"layout.structured.rectangle"
	):
		return false
	for header_row: int in _header_rows:
		if not _rows.has(header_row):
			return _fail("missing_layout_header", "A declared header row is missing.")
	return true


## 只展开真实声明的合并表头；拒绝跨越数据、非空覆盖或相互重叠的区域。
## [br]
## @api private
func _expand_merged_headers(ranges: Array[Dictionary]) -> bool:
	var covered: Dictionary = {}
	var transpose: bool = _layout.get("orientation", "rows") == "columns"
	for area: Dictionary in ranges:
		var first_row: int = GFVariantData.get_option_int(area, "first_row")
		var last_row: int = GFVariantData.get_option_int(area, "last_row")
		var first_column: int = GFVariantData.get_option_int(area, "first_column")
		var last_column: int = GFVariantData.get_option_int(area, "last_column")
		if (
			first_row <= 0
			or first_column <= 0
			or last_row < first_row
			or last_column < first_column
		):
			return _fail("invalid_layout_merge", "Invalid merged cell range.")
		var row_start: int = first_column if transpose else first_row
		var row_end: int = last_column if transpose else last_row
		var column_start: int = first_row if transpose else first_column
		var column_end: int = last_row if transpose else last_column
		if not _budget.consume_work(row_end, "layout.structured.merge_rows") or not _budget.consume_work(column_end, "layout.structured.merge_columns"):
			return false
		if not _budget.consume_work(
			(row_end - row_start + 1) * (column_end - column_start + 1),
			"layout.structured.merge"
		):
			return false
		var anchor: Dictionary = _cell(row_start, column_start)
		if GFVariantData.get_option_string(anchor, "text").is_empty():
			return _fail(
				"empty_layout_merge",
				"Merged headers require a non-empty anchor.",
				_cell_location(row_start, column_start)
			)
		for row_number: int in range(
			row_start,
			row_end + 1
		):
			if not _header_rows.has(row_number):
				return _fail(
					"layout_merge_outside_header",
					"Merged cells are supported only inside declared header rows.",
					_cell_location(row_start, column_start)
				)
			var cells: Dictionary = _rows.get(row_number, {})
			for column_number: int in range(
				column_start,
				column_end + 1
			):
				var coordinate: Vector2i = Vector2i(row_number, column_number)
				if covered.has(coordinate):
					return _fail(
						"overlapping_layout_merge",
						"Merged header ranges overlap.",
						_cell_location(row_number, column_number)
					)
				covered[coordinate] = true
				if coordinate != Vector2i(row_start, column_start) and not _text(row_number, column_number).is_empty():
					return _fail(
						"layout_merge_overwrite",
						"Merged header would overwrite a non-empty cell.",
						_cell_location(row_number, column_number)
					)
				cells[column_number] = anchor
			_rows[row_number] = cells
		if column_end > _width:
			if not _budget.consume_work(
				(column_end - _width) * _height,
				"layout.structured.merge_expansion"
			):
				return false
			_width = column_end
	return true


## 默认从多行表头产生对象路径；显式 bindings 的路径完全替代推导，未绑定列必须显式忽略。
## [br]
## @api private
func _compile_bindings() -> bool:
	var ignored_value: Variant = _layout.get("ignored_columns", [])
	if not ignored_value is Array:
		return _fail("invalid_layout_columns", "ignored_columns must be an array.")
	var ignored: Array = ignored_value
	for column: Variant in ignored:
		if not _claim_column(column):
			return false
		_ignored_columns[column] = true
	var collections_value: Variant = _layout.get("collections", [])
	if not collections_value is Array:
		return _fail("invalid_layout_collections", "collections must be an array.")
	var collections: Array = collections_value
	for value: Variant in collections:
		if not value is Dictionary:
			return _fail("invalid_layout_collection", "Each collection must be a dictionary.")
		var group: Dictionary = value
		if not _validate_keys(
			group,
			[
				"kind",
				"path",
				"columns",
				"key_column",
			]
		):
			return false
		var kind: Variant = group.get("kind")
		if kind != "array" and kind != "map":
			return _fail("invalid_layout_collection", "Collection kind must be array or map.")
		var path: Array = _validate_path(
			group.get("path"),
			false
		)
		if not _failure.is_empty():
			return false
		if kind == "map":
			if not _claim_column(group.get("key_column")):
				return false
		elif group.has("key_column"):
			return _fail("invalid_layout_collection", "Array collections cannot declare key_column.")
		var members: Array[Dictionary] = _compile_columns(
			group.get("columns"),
			true
		)
		if not _failure.is_empty() or members.is_empty():
			return _fail("invalid_layout_collection", "Collections require at least one element binding.")
		_collections.append(
			{
				"kind": kind,
				"path": path,
				"columns": members,
				"key_column": group.get("key_column", 0),
			}
		)
		_add_header(path)
	if _layout.has("columns"):
		_bindings = _compile_columns(
			_layout["columns"],
			false
		)
		if not _failure.is_empty():
			return false
	else:
		for column_number: int in range(
			1,
			_width + 1
		):
			if _claimed_columns.has(column_number):
				continue
			var path: Array = []
			var header_locations: Array[Dictionary] = []
			var previous_location: Dictionary = {}
			for row_number: int in _header_rows:
				var label: String = _text(row_number, column_number)
				var location: Dictionary = _cell_location(row_number, column_number)
				if not label.is_empty() and location != previous_location:
					path.append(label)
					header_locations.append(location)
					previous_location = location
			if path.is_empty():
				return _fail(
					"empty_layout_header",
					"Every unignored column requires a header or explicit binding.",
					_cell_location(
						_header_rows[_header_rows.size() - 1],
						column_number
					)
				)
			if not _claim_column(column_number):
				return false
			_bindings.append(
				{
					"column": column_number,
					"path": path,
					"header_locations": header_locations,
				}
			)
	for binding: Dictionary in _bindings:
		_add_header(GFVariantData.get_option_array(binding, "path"))
	if _layout.has("record_key_column"):
		var key_column: int = GFVariantData.get_option_int(_layout, "record_key_column")
		if key_column > _width:
			return _fail("invalid_layout_record_key", "record_key_column is outside the table.")
		_claimed_columns[key_column] = true
	var paths: Array = []
	for binding: Dictionary in _bindings:
		paths.append(binding["path"])
	for group: Dictionary in _collections:
		paths.append(group["path"])
	return _validate_distinct_paths(paths)


## 为一个字段组校验列归属、路径类型及前缀冲突；元素标量仅允许唯一空路径。
## [br]
## @api private
func _compile_columns(value: Variant, allow_empty_path: bool) -> Array[Dictionary]:
	var bindings: Array[Dictionary] = []
	if not value is Array:
		var _failed: bool = _fail("invalid_layout_columns", "columns must be an array of bindings.")
		return bindings
	var entries: Array = value
	var paths: Array = []
	for entry: Variant in entries:
		if not entry is Dictionary:
			var _failed: bool = _fail("invalid_layout_binding", "A column binding must be a dictionary.")
			return []
		var binding: Dictionary = entry
		if not _validate_keys(
			binding,
			["column", "path"]
		) or not _claim_column(binding.get("column")):
			return []
		var path: Array = _validate_path(
			binding.get("path"),
			allow_empty_path
		)
		if not _failure.is_empty():
			return []
		paths.append(path)
		bindings.append({ "column": binding["column"], "path": path })
	if not _validate_distinct_paths(paths):
		return []
	return bindings


## 路径段本身没有转义语法；字符串键原样保留，整数段表示零基数组下标。
## [br]
## @api private
func _validate_path(value: Variant, allow_empty: bool) -> Array:
	if not value is Array:
		var _failed: bool = _fail("invalid_layout_path", "Paths must be arrays of string keys or non-negative integer indices.")
		return []
	var path: Array = value
	if path.is_empty() and not allow_empty:
		var _failed: bool = _fail("invalid_layout_path", "Root bindings require a non-empty object path.")
		return []
	if not path.is_empty() and not path[0] is String:
		var _failed: bool = _fail("invalid_layout_path", "Record and element object paths must begin with a string key.")
		return []
	for segment: Variant in path:
		if not (
			(
				segment is String
				and segment != ""
			)
			or (
				segment is int
				and segment >= 0
			)
		):
			var _failed: bool = _fail("invalid_layout_path", "Path segments must be non-empty strings or non-negative integers.")
			return []
	if not _budget.check_depth(
		path.size(),
		"layout.structured.path"
	):
		return []
	return path.duplicate()


## 路径等价或祖先重叠都在读取数据前拒绝，空单元格不能掩盖错误映射。
## [br]
## @api private
func _validate_distinct_paths(paths: Array) -> bool:
	for index: int in range(paths.size()):
		var left: Array = paths[index]
		for other: int in range(index):
			var right: Array = paths[other]
			var length: int = mini(
				left.size(),
				right.size()
			)
			if not _budget.consume_work(
				length + 1,
				"layout.structured.path_conflicts"
			):
				return false
			var same_prefix: bool = true
			for segment: int in range(length):
				if left[segment] != right[segment] or typeof(left[segment]) != typeof(right[segment]):
					same_prefix = false
					break
			if same_prefix:
				return _fail("conflicting_layout_paths", "Bindings cannot share or contain the same path.")
	return true


## 列号以转置后的逻辑表格为准；重复列映射不是隐式复制操作。
## [br]
## @api private
func _claim_column(value: Variant) -> bool:
	if not value is int:
		return _fail("invalid_layout_column", "Column numbers must be positive integers.")
	var column: int = value
	if (
		column <= 0
		or column > _width
		or _claimed_columns.has(column)
	):
		return _fail(
			"invalid_layout_column",
			"Column is outside the table or already bound: %d." % column
		)
	_claimed_columns[column] = true
	return true


## 校验组内只使用已知键，避免误拼配置被静默忽略。
## [br]
## @api private
func _validate_keys(value: Dictionary, allowed: Array[String]) -> bool:
	for key: Variant in value:
		if not key is String:
			return _fail("invalid_layout_binding", "Binding option keys must be strings.")
		var option_key: String = key
		if not allowed.has(option_key):
			return _fail(
				"invalid_layout_binding",
				"Unknown binding option: %s." % str(key)
			)
	return true


## 按连续键分组；空键仅延续已有记录，非连续重复键拒绝，最后一组随返回一同保留。
## [br]
## @api private
func _collect_records() -> Dictionary:
	var records: Array[Dictionary] = []
	var locations: Array[Dictionary] = []
	var record: Dictionary = {}
	var location: Dictionary = {}
	var seen_keys: Dictionary = {}
	var current_key: String = ""
	var key_column: int = GFVariantData.get_option_int(_layout, "record_key_column")
	var has_record: bool = false
	for row_number: int in range(
		_header_rows[_header_rows.size() - 1] + 1,
		_height + 1
	):
		var any_value: bool = false
		for column: int in range(
			1,
			_width + 1
		):
			if not _text(row_number, column).is_empty():
				if not _claimed_columns.has(column):
					var _failed: bool = _fail(
						"unmapped_layout_column",
						"Non-empty data has no column binding.",
						_cell_location(row_number, column)
					)
					return _result_failure()
				if not _ignored_columns.has(column):
					any_value = true
		if not any_value:
			if _layout.get("blank_rows", "reject") == "skip":
				continue
			var _failed: bool = _fail(
				"empty_layout_row",
				"Empty data rows require explicit blank_rows=skip.",
				_cell_location(row_number, 1)
			)
			return _result_failure()
		var key: String = _text(row_number, key_column) if key_column > 0 else ""
		var starts_record: bool = (
			key_column == 0
			or (
				not key.is_empty()
				and key != current_key
			)
		)
		if starts_record:
			if not key.is_empty() and seen_keys.has(key):
				var _failed: bool = _fail(
					"noncontiguous_layout_record",
					"A record key reappeared after another record.",
					_cell_location(row_number, key_column)
				)
				return _result_failure()
			record = {}
			location = _cell_location(row_number, 1)
			location["fields"] = {}
			location["row_index"] = records.size()
			records.append(record)
			locations.append(location)
			has_record = true
			current_key = key
			if not key.is_empty():
				seen_keys[key] = true
		elif not has_record:
			var _failed: bool = _fail(
				"orphan_layout_continuation",
				"A continuation row has no preceding record.",
				_cell_location(row_number, key_column)
			)
			return _result_failure()
		if not _apply_columns(
			record,
			location,
			row_number,
			_bindings,
			[]
		):
			return _result_failure()
		for group: Dictionary in _collections:
			if not _append_collection(
				record,
				location,
				row_number,
				group
			):
				return _result_failure()
	if not _budget.admit_value(records, "layout.structured.records"):
		return _result_failure()
	if not _budget.admit_value(locations, "layout.structured.locations"):
		return _result_failure()
	return {
		"success": true,
		"data": records,
		"header": _header,
		"header_location": _header_location(),
		"row_locations": locations,
		"source": _identity["source"],
		"error": "",
		"error_line": 0,
		"error_column": 0,
	}


## 标量字段只在有值时写入；同组续行重复值必须完全相同。
## [br]
## @api private
func _apply_columns(
	record: Dictionary,
	location: Dictionary,
	row_number: int,
	bindings: Array[Dictionary],
	prefix: Array
) -> bool:
	for binding: Dictionary in bindings:
		var column: int = GFVariantData.get_option_int(binding, "column")
		var text: String = _text(row_number, column)
		if text.is_empty():
			continue
		var path: Array = prefix + GFVariantData.get_option_array(binding, "path")
		var value: String = "" if text == _layout.get("empty_string_token", null) else text
		var field_location: Dictionary = _cell_location(row_number, column)
		if not _set_path(
			record,
			path,
			value,
			field_location
		):
			return false
		_record_location(
			location,
			path,
			field_location
		)
	return _budget.is_ok()


## 每条有值的物理行贡献一个集合元素；map 键重复或只有值没有键都失败。
## [br]
## @api private
func _append_collection(
	record: Dictionary,
	location: Dictionary,
	row_number: int,
	group: Dictionary
) -> bool:
	var members: Array[Dictionary] = []
	members.assign(GFVariantData.get_option_array(group, "columns"))
	var key_column: int = GFVariantData.get_option_int(group, "key_column")
	var key: String = _text(row_number, key_column) if key_column > 0 else ""
	var any_value: bool = not key.is_empty()
	for binding: Dictionary in members:
		if not _text(
			row_number,
			GFVariantData.get_option_int(binding, "column")
		).is_empty():
			any_value = true
	if not any_value:
		return true
	var path: Array = GFVariantData.get_option_array(group, "path").duplicate()
	var map_group: bool = group["kind"] == "map"
	if map_group and key.is_empty():
		return _fail(
			"missing_layout_map_key",
			"A map element requires a non-empty key.",
			_cell_location(row_number, key_column)
		)
	var collection: Variant = _get_path(record, path)
	if collection == null:
		if map_group:
			collection = {}
		else:
			collection = []
		if not _set_path(
			record,
			path,
			collection,
			_cell_location(
				row_number,
				key_column if map_group else GFVariantData.get_option_int(
					members[0],
					"column"
				)
			)
		):
			return false
	if map_group:
		if not collection is Dictionary:
			return _fail("conflicting_layout_container", "A map path already holds another value.")
		var map_value: Dictionary = collection
		if map_value.has(key):
			return _fail(
				"duplicate_layout_map_key",
				"A map element key occurs more than once.",
				_cell_location(row_number, key_column)
			)
		path.append(key)
	else:
		if not collection is Array:
			return _fail("conflicting_layout_container", "An array path already holds another value.")
		var array_value: Array = collection
		path.append(array_value.size())
	var first_path: Array = GFVariantData.get_option_array(
		members[0],
		"path"
	)
	if first_path.is_empty():
		var column: int = GFVariantData.get_option_int(
			members[0],
			"column"
		)
		if _text(row_number, column).is_empty():
			return _fail(
				"missing_layout_element",
				"Scalar collection elements require a value.",
				_cell_location(row_number, column)
			)
	else:
		if not _set_path(
			record,
			path,
			{},
			_cell_location(
				row_number,
				GFVariantData.get_option_int(
					members[0],
					"column"
				)
			)
		):
			return false
	if map_group:
		_record_location(
			location,
			path,
			_cell_location(row_number, key_column)
		)
	return _apply_columns(
		record,
		location,
		row_number,
		members,
		path
	)


## 有界创建路径容器；数组只准顺序追加，绝不按稀疏下标无限填洞。
## [br]
## @api private
func _set_path(
	root: Dictionary,
	path: Array,
	value: Variant,
	location: Dictionary
) -> bool:
	var container: Variant = root
	for index: int in range(path.size()):
		if not _budget.consume_work(1, "layout.structured.insert") or not _budget.check_depth(
			index + 1,
			"layout.structured.insert"
		):
			return false
		var segment: Variant = path[index]
		var final: bool = index == path.size() - 1
		var existing: Variant = null
		var present: bool = false
		if container is Dictionary and segment is String:
			var dictionary: Dictionary = container
			present = dictionary.has(segment)
			existing = dictionary.get(segment)
			if not present:
				dictionary[segment] = value if final else _new_container(path[index + 1])
				existing = dictionary[segment]
		elif container is Array and segment is int:
			var array: Array = container
			var offset: int = segment
			if offset > array.size():
				return _fail(
					"sparse_layout_array",
					"Array bindings must populate indices without holes.",
					location,
					path
				)
			present = offset < array.size()
			if not present:
				array.append(value if final else _new_container(path[index + 1]))
			existing = array[offset]
		else:
			return _fail(
				"conflicting_layout_container",
				"A field path crosses a scalar or incompatible container.",
				location,
				path
			)
		if final:
			if present and existing != value:
				return _fail(
					"conflicting_layout_value",
					"Continuation rows disagree on a scalar field.",
					location,
					path
				)
		else:
			container = existing
	return true


## 路径段决定空容器种类，不读取 schema 或把数字字符串猜作数组下标。
## [br]
## @api private
func _new_container(segment: Variant) -> Variant:
	if segment is int:
		return []
	return {}


## 查询已创建的集合路径；不存在返回 null，不生成容器。
## [br]
## @api private
func _get_path(root: Dictionary, path: Array) -> Variant:
	if not _budget.consume_work(
		path.size(),
		"layout.structured.lookup"
	):
		return null
	var value: Variant = root
	for segment: Variant in path:
		if value is Dictionary and segment is String:
			var dictionary: Dictionary = value
			value = dictionary.get(segment)
		elif value is Array and segment is int:
			var array: Array = value
			var index: int = segment
			if index >= array.size():
				return null
			value = array[index]
		else:
			return null
	return value


## 保存首个赋值位置；同值续行不会把原始定义位置改成最后一行。
## [br]
## @api private
func _record_location(
	location: Dictionary,
	path: Array,
	physical: Dictionary
) -> void:
	var fields: Dictionary = location["fields"]
	var field_path: String = _format_path(path)
	if fields.has(field_path):
		return
	var field_location: Dictionary = physical.duplicate()
	field_location["field_path"] = field_path
	field_location["field_segments"] = path.duplicate()
	if not _budget.admit_value(field_location, "layout.structured.field_location"):
		return
	fields[field_path] = field_location
	location["fields"] = fields


## 构造表头位置时保留合并区域锚点；显式路径不改变物理来源。
## [br]
## @api private
func _header_location() -> Dictionary:
	var location: Dictionary = _cell_location(
		_header_rows[_header_rows.size() - 1],
		1
	)
	location["fields"] = {}
	for binding: Dictionary in _bindings:
		var header_locations: Array = GFVariantData.get_option_array(binding, "header_locations")
		var physical: Dictionary = _cell_location(
			_header_rows[_header_rows.size() - 1],
			GFVariantData.get_option_int(binding, "column")
		)
		if not header_locations.is_empty():
			var last_header_location: Dictionary = header_locations[header_locations.size() - 1]
			physical = last_header_location.duplicate()
		physical["header_locations"] = header_locations
		_record_location(
			location,
			GFVariantData.get_option_array(binding, "path"),
			physical
		)
	return location


## 单元格缺失时仍能给出它在原始工作表中的准确坐标。
## [br]
## @api private
func _cell_location(row_number: int, column: int) -> Dictionary:
	var cell: Dictionary = _cell(row_number, column)
	if cell.has("location"):
		return GFVariantData.get_option_dictionary(cell, "location").duplicate()
	var transpose: bool = _layout.get("orientation", "rows") == "columns"
	var grid_row: int = column if transpose else row_number
	var physical_row: int = _physical_rows.get(grid_row, grid_row)
	var physical_column: int = row_number if transpose else column
	var location: Dictionary = _identity.duplicate()
	location["line"] = physical_row
	location["column"] = physical_column
	location["column_index"] = physical_column - 1
	location["cell"] = _cell_label(physical_row, physical_column)
	return location


## 不补齐稀疏单元格，只按需要返回缺失标记。
## [br]
## @api private
func _cell(row_number: int, column: int) -> Dictionary:
	var cells: Dictionary = _rows.get(row_number, {})
	var result: Dictionary = cells.get(column, {})
	return result


## 读取保留的原始字符串；缺失与空单元格均表示没有赋值。
## [br]
## @api private
func _text(row_number: int, column: int) -> String:
	return GFVariantData.get_option_string(
		_cell(row_number, column),
		"text"
	)


## 记录输出根字段，不把显示表头路径误当作平字段名。
## [br]
## @api private
func _add_header(path: Array) -> void:
	if path.is_empty():
		return
	var root: String = path[0]
	if not _header.has(root):
		var _appended: bool = _header.append(root)


## 展示路径保留简单点号记法；特殊键用 JSON 字符串括号，精确段同时单独保存。
## [br]
## @api private
func _format_path(path: Array) -> String:
	var result: String = ""
	for segment: Variant in path:
		if segment is int:
			result += "[%d]" % segment
		elif segment is String:
			var key: String = segment
			if key.is_valid_identifier():
				result += ("." if not result.is_empty() else "") + key
			else:
				result += "[" + JSON.stringify(key) + "]"
	return result


## 将一基列号转换为 XLSX 风格地址，只描述物理位置而不参与解析。
## [br]
## @api private
func _cell_label(row_number: int, column: int) -> String:
	var letters: String = ""
	var remaining: int = column
	while remaining > 0:
		remaining -= 1
		letters = String.chr(65 + remaining % 26) + letters
		remaining = floori(float(remaining) / 26.0)
	return (
		"%s%d"
		% [letters, row_number]
	)


## 锁存第一条结构失败，完整包含逻辑路径和物理定位。
## [br]
## @api private
func _fail(
	kind: String,
	message: String,
	location: Dictionary = {},
	path: Array = []
) -> bool:
	if _failure.is_empty():
		var context: Dictionary = location.duplicate()
		if not path.is_empty():
			context["field_path"] = _format_path(path)
			context["field_segments"] = path.duplicate()
		_failure = {
			"success": false,
			"data": null,
			"header": PackedStringArray(),
			"row_locations": [],
			"source": _identity.get("source", ""),
			"error_kind": kind,
			"error": message,
			"error_line": GFVariantData.get_option_int(location, "line"),
			"error_column": GFVariantData.get_option_int(location, "column"),
			"context": context,
		}
	return false


## 预算首次失败具有最终否决权，绝不把空错误当成成功。
## [br]
## @api private
func _result_failure() -> Dictionary:
	if not _budget.is_ok():
		var report: Dictionary = _budget.get_report()
		_failure = {}
		var _failed: bool = _fail(
			GFVariantData.get_option_string(report, "error_kind"),
			GFVariantData.get_option_string(report, "error")
		)
		_failure["budget_report"] = report
	if _failure.is_empty():
		var _failed: bool = _fail("invalid_layout", "Structured layout could not be completed.")
	return _failure
