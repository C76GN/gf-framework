## GFTableColumnDefinition: 通用表格列定义。
##
## 描述一列如何从任意行数据中读取、格式化、排序、过滤和写回值。
## 它不创建 Control、不绑定资源表或配置表格式，也不规定视觉、编辑器或业务语义。
## [br]
## @api public
## [br]
## @category resource_definition
## [br]
## @since 5.2.0
class_name GFTableColumnDefinition
extends Resource


# --- 枚举 ---

## 默认排序值解释方式。
## [br]
## @api public
## [br]
## @since 5.2.0
enum SortMode {
	## 根据值类型自动选择排序方式。
	AUTO,
	## 按文本排序。
	TEXT,
	## 按数字排序。
	NUMBER,
	## 按布尔值排序。
	BOOL,
}


# --- 导出变量 ---

## 列稳定 ID，用于排序、提交和保存 UI 状态。
## [br]
## @api public
## [br]
## @since 5.2.0
@export var column_id: StringName = &""

## 读取行数据时使用的字段键。为空时使用 column_id。
## [br]
## @api public
## [br]
## @since 5.2.0
@export var value_key: StringName = &""

## 显示标题。为空时使用 column_id。
## [br]
## @api public
## [br]
## @since 5.2.0
@export var display_label: String = ""

## 该列是否应出现在默认可见列中。
## [br]
## @api public
## [br]
## @since 5.2.0
@export var visible: bool = true

## 该列是否允许参与排序。
## [br]
## @api public
## [br]
## @since 5.2.0
@export var sortable: bool = true

## 该列是否允许参与文本过滤。
## [br]
## @api public
## [br]
## @since 5.2.0
@export var filterable: bool = true

## 该列是否允许通过 write_value() 或 GFTableDataView.commit_cell_value() 写回。
## [br]
## @api public
## [br]
## @since 5.2.0
@export var editable: bool = false

## 默认排序方式。
## [br]
## @api public
## [br]
## @since 5.2.0
@export var sort_mode: SortMode = SortMode.AUTO

## 可选元数据，供项目 UI、编辑器工具或自定义渲染器使用。
## [br]
## @api public
## [br]
## @since 5.2.0
## [br]
## @schema metadata: Dictionary，保存调用方附加到列定义上的元数据。
@export var metadata: Dictionary = {}


# --- 公共变量 ---

## 自定义取值回调。有效时应接收 row 与 column 两个参数。
## [br]
## @api public
## [br]
## @since 5.2.0
var value_getter: Callable = Callable()

## 自定义写值回调。有效时应接收 row、value 与 column 三个参数；返回 false 表示写入失败。
## [br]
## @api public
## [br]
## @since 5.2.0
var value_setter: Callable = Callable()

## 自定义格式化回调。有效时应接收 value、row 与 column 三个参数。
## [br]
## @api public
## [br]
## @since 5.2.0
var value_formatter: Callable = Callable()

## 自定义比较回调。有效时应接收 left_value、right_value、left_row、right_row 与 column 五个参数。
## [br]
## @api public
## [br]
## @since 5.2.0
var value_comparator: Callable = Callable()


# --- 公共方法 ---

## 配置列定义并返回自身，便于测试或运行时快速创建列。
## [br]
## @api public
## [br]
## @since 5.2.0
## [br]
## @param p_column_id: 列稳定 ID。
## [br]
## @param p_display_label: 可选显示标题。
## [br]
## @param p_value_key: 可选字段键；为空时使用列 ID。
## [br]
## @return 当前列定义。
func configure(
	p_column_id: StringName,
	p_display_label: String = "",
	p_value_key: StringName = &""
) -> GFTableColumnDefinition:
	column_id = p_column_id
	display_label = p_display_label
	value_key = p_value_key
	return self


## 获取稳定列键。
## [br]
## @api public
## [br]
## @since 5.2.0
## [br]
## @return 列 ID。
func get_column_key() -> StringName:
	return column_id


## 获取读取值时使用的字段键。
## [br]
## @api public
## [br]
## @since 5.2.0
## [br]
## @return 字段键。
func get_value_key() -> StringName:
	if value_key != &"":
		return value_key
	return column_id


## 获取显示标题。
## [br]
## @api public
## [br]
## @since 5.2.0
## [br]
## @return 显示标题。
func get_display_label() -> String:
	if not display_label.is_empty():
		return display_label
	return String(column_id)


## 从行数据中读取该列的值。
## [br]
## @api public
## [br]
## @since 5.2.0
## [br]
## @param row_data: 行数据，可为 Dictionary、Object、Resource 或自定义回调支持的类型。
## [br]
## @return 读取到的值。
## [br]
## @schema row_data: Variant，调用方保存的行数据。
## [br]
## @schema return: Variant，列值。
func read_value(row_data: Variant) -> Variant:
	if value_getter.is_valid():
		return value_getter.call(row_data, self)
	return _read_default_value(row_data)


## 将该列的值写回行数据。
## [br]
## @api public
## [br]
## @since 5.2.0
## [br]
## @param row_data: 行数据。
## [br]
## @param new_value: 要写入的新值。
## [br]
## @return 写入成功返回 true。
## [br]
## @schema row_data: Variant，调用方保存的行数据。
## [br]
## @schema new_value: Variant，列新值。
func write_value(row_data: Variant, new_value: Variant) -> bool:
	if not editable:
		return false
	if value_setter.is_valid():
		var setter_result: Variant = value_setter.call(row_data, new_value, self)
		if setter_result is bool:
			var setter_ok: bool = setter_result
			return setter_ok
		return true
	return _write_default_value(row_data, new_value)


## 将值格式化成用于过滤或显示的文本。
## [br]
## @api public
## [br]
## @since 5.2.0
## [br]
## @param value: 列值。
## [br]
## @param row_data: 行数据。
## [br]
## @return 文本值。
## [br]
## @schema value: Variant，待格式化列值。
## [br]
## @schema row_data: Variant，调用方保存的行数据。
func format_value(value: Variant, row_data: Variant = null) -> String:
	if value_formatter.is_valid():
		var formatted_value: Variant = value_formatter.call(value, row_data, self)
		return GFVariantData.to_text(formatted_value)
	if value == null:
		return ""
	return GFVariantData.to_text(value)


## 判断该列是否匹配过滤文本。
## [br]
## @api public
## [br]
## @since 5.2.0
## [br]
## @param row_data: 行数据。
## [br]
## @param query: 过滤文本。
## [br]
## @param case_sensitive: 是否区分大小写。
## [br]
## @return 匹配时返回 true。
## [br]
## @schema row_data: Variant，调用方保存的行数据。
func matches_query(row_data: Variant, query: String, case_sensitive: bool = false) -> bool:
	if not filterable:
		return false
	if query.is_empty():
		return true

	var value_text: String = format_value(read_value(row_data), row_data)
	var query_text: String = query
	if not case_sensitive:
		value_text = value_text.to_lower()
		query_text = query_text.to_lower()
	return value_text.find(query_text) >= 0


## 比较两个行值。
## [br]
## @api public
## [br]
## @since 5.2.0
## [br]
## @param left_value: 左侧值。
## [br]
## @param right_value: 右侧值。
## [br]
## @param left_row: 左侧行数据。
## [br]
## @param right_row: 右侧行数据。
## [br]
## @return 小于返回 -1，等于返回 0，大于返回 1。
## [br]
## @schema left_value: Variant，左侧列值。
## [br]
## @schema right_value: Variant，右侧列值。
## [br]
## @schema left_row: Variant，左侧行数据。
## [br]
## @schema right_row: Variant，右侧行数据。
func compare_values(
	left_value: Variant,
	right_value: Variant,
	left_row: Variant = null,
	right_row: Variant = null
) -> int:
	if value_comparator.is_valid():
		var compare_result: Variant = value_comparator.call(left_value, right_value, left_row, right_row, self)
		return _normalize_compare_result(compare_result)

	match _resolve_sort_mode(left_value, right_value):
		SortMode.NUMBER:
			return _compare_float_values(left_value, right_value)
		SortMode.BOOL:
			return _compare_bool_values(left_value, right_value)
		_:
			return _compare_text_values(left_value, right_value, left_row, right_row)


## 创建同内容拷贝。
## [br]
## @api public
## [br]
## @since 5.2.0
## [br]
## @return 新列定义。
func duplicate_column() -> GFTableColumnDefinition:
	var column: GFTableColumnDefinition = GFTableColumnDefinition.new()
	column.column_id = column_id
	column.value_key = value_key
	column.display_label = display_label
	column.visible = visible
	column.sortable = sortable
	column.filterable = filterable
	column.editable = editable
	column.sort_mode = sort_mode
	column.metadata = metadata.duplicate(true)
	column.value_getter = value_getter
	column.value_setter = value_setter
	column.value_formatter = value_formatter
	column.value_comparator = value_comparator
	return column


## 导出列定义摘要。
## [br]
## @api public
## [br]
## @since 5.2.0
## [br]
## @return 列定义字典。
## [br]
## @schema return: Dictionary，包含 column_id、value_key、display_label、visible、sortable、filterable、editable、sort_mode 和 metadata。
func describe() -> Dictionary:
	return {
		"column_id": column_id,
		"value_key": get_value_key(),
		"display_label": get_display_label(),
		"visible": visible,
		"sortable": sortable,
		"filterable": filterable,
		"editable": editable,
		"sort_mode": sort_mode,
		"metadata": metadata.duplicate(true),
	}


# --- 私有/辅助方法 ---

func _read_default_value(row_data: Variant) -> Variant:
	var key: StringName = get_value_key()
	if row_data is Dictionary:
		var dictionary: Dictionary = row_data
		return GFVariantData.get_option_value(dictionary, key)
	if row_data is Object:
		var object_ref: Object = row_data
		if _object_has_property(object_ref, key):
			return object_ref.get(key)
	return null


func _write_default_value(row_data: Variant, new_value: Variant) -> bool:
	var key: StringName = get_value_key()
	if row_data is Dictionary:
		var dictionary: Dictionary = row_data
		dictionary[key] = new_value
		return true
	if row_data is Object:
		var object_ref: Object = row_data
		if not _object_has_property(object_ref, key):
			return false
		object_ref.set(key, new_value)
		return true
	return false


func _object_has_property(object_ref: Object, property_key: StringName) -> bool:
	for property_info: Dictionary in object_ref.get_property_list():
		var raw_property_name: Variant = GFVariantData.get_option_value(property_info, "name")
		if raw_property_name is String or raw_property_name is StringName:
			var property_name: StringName = GFVariantData.to_string_name(raw_property_name)
			if property_name == property_key:
				return true
	return false


func _resolve_sort_mode(left_value: Variant, right_value: Variant) -> SortMode:
	if sort_mode != SortMode.AUTO:
		return sort_mode
	if _is_number_like(left_value) and _is_number_like(right_value):
		return SortMode.NUMBER
	if left_value is bool and right_value is bool:
		return SortMode.BOOL
	return SortMode.TEXT


func _compare_float_values(left_value: Variant, right_value: Variant) -> int:
	var left_number: float = GFVariantData.to_float(left_value)
	var right_number: float = GFVariantData.to_float(right_value)
	if is_equal_approx(left_number, right_number):
		return 0
	return -1 if left_number < right_number else 1


func _compare_bool_values(left_value: Variant, right_value: Variant) -> int:
	var left_bool: bool = GFVariantData.to_bool(left_value)
	var right_bool: bool = GFVariantData.to_bool(right_value)
	if left_bool == right_bool:
		return 0
	return 1 if left_bool else -1


func _compare_text_values(
	left_value: Variant,
	right_value: Variant,
	left_row: Variant,
	right_row: Variant
) -> int:
	var left_text: String = format_value(left_value, left_row).to_lower()
	var right_text: String = format_value(right_value, right_row).to_lower()
	if left_text == right_text:
		return 0
	return -1 if left_text < right_text else 1


func _normalize_compare_result(compare_result: Variant) -> int:
	if compare_result is bool:
		var bool_result: bool = compare_result
		return -1 if bool_result else 1
	if compare_result is int or compare_result is float:
		var number_result: float = GFVariantData.to_float(compare_result)
		if is_equal_approx(number_result, 0.0):
			return 0
		return -1 if number_result < 0.0 else 1
	return 0


func _is_number_like(value: Variant) -> bool:
	return value is int or value is float
