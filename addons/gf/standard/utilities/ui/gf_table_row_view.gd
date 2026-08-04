## GFTableRowView: 表格行谓词使用的隔离只读视图。
##
## 只公开稳定行 ID、源索引和已配置列的复制值，不公开源行容器。
## 项目谓词可以读取隐藏列，但不能通过该视图修改权威表格数据。
## [br]
## @api public
## [br]
## @category value_object
## [br]
## @since unreleased
class_name GFTableRowView
extends RefCounted


# --- 常量 ---

const _MAX_SNAPSHOT_DEPTH: int = 64
const _MAX_SNAPSHOT_NODE_COUNT: int = 16_384
const _MAX_SNAPSHOT_COLLECTION_ITEM_COUNT: int = 65_536
const _MAX_SNAPSHOT_UTF8_BYTES: int = 1_048_576


# --- 私有变量 ---

var _configured: bool = false
var _source_row_index: int = -1
var _row_id: Variant = null
var _values: Dictionary = {}


# --- 公共方法 ---

## 获取稳定行 ID 副本。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 稳定行 ID 副本。
## [br]
## @schema return: Variant stable row identity copy.
func get_row_id() -> Variant:
	return _get_isolated_copy(_row_id)


## 获取源行索引。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 构建该视图时的源行索引。
func get_source_row_index() -> int:
	return _source_row_index


## 判断是否包含指定列值。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param column_id: 稳定列 ID。
## [br]
## @return 存在列值时返回 true。
func has_value(column_id: StringName) -> bool:
	return _values.has(column_id) or _values.has(String(column_id))


## 获取指定列的隔离值副本。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param column_id: 稳定列 ID。
## [br]
## @param default_value: 列不存在时返回的默认值。
## [br]
## @schema default_value: Variant fallback copied before return.
## [br]
## @return 列值或默认值的副本。
## [br]
## @schema return: Variant isolated column value copy.
func get_value(column_id: StringName, default_value: Variant = null) -> Variant:
	return _get_isolated_copy(GFVariantData.get_option_value(_values, column_id, default_value))


## 获取全部列值副本。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 以列 ID 为键的隔离值副本。
## [br]
## @schema return: Dictionary keyed by StringName column IDs with copied Variant values.
func get_values() -> Dictionary:
	var copied_value: Variant = _get_isolated_copy(_values)
	return GFVariantData.as_dictionary(copied_value)


# --- 框架内部方法 ---

## 在固定预算内复制可安全交给项目回调的隔离 Variant。
##
## Dictionary、Array、PackedArray 与可验证深复制的无脚本 Resource 会得到独立副本；
## 循环、脚本 Resource、其他 Object、Callable、Signal、RID 或超出预算的值会失败关闭。
## [br]
## @api framework_internal
## [br]
## @since unreleased
## [br]
## @param value: 待隔离的 Variant。
## [br]
## @schema value: Variant snapshot candidate.
## [br]
## @return 包含 ok、value 与 error_code 的复制报告。
## [br]
## @schema return: Dictionary with ok: bool, value: Variant, and error_code: StringName.
static func duplicate_isolated_variant_for_framework(value: Variant) -> Dictionary:
	var preflight_state: Dictionary = _make_snapshot_state()
	var preflight_report: Dictionary = _preflight_isolated_value(
		value,
		preflight_state,
		0
	)
	if not GFVariantData.get_option_bool(preflight_report, "ok"):
		return preflight_report
	var copy_state: Dictionary = _make_snapshot_state()
	return _duplicate_isolated_value(value, copy_state, 0)


## 从未暴露的 canonical RowView 基类存储创建项目回调独占快照。
##
## 方法不调用候选可覆写 getter，并重新执行完整隔离复制与预算校验。
## [br]
## @api framework_internal
## [br]
## @since unreleased
## [br]
## @param source: 框架持有的 canonical RowView。
## [br]
## @return 独立的纯 GFTableRowView；输入失效或复制失败时返回 null。
static func snapshot_for_framework(source: GFTableRowView) -> GFTableRowView:
	if source == null or not is_instance_valid(source) or not source._configured:
		return null
	var snapshot: GFTableRowView = GFTableRowView.new()
	if not snapshot.configure_for_framework(
		source._source_row_index,
		source._row_id,
		source._values
	):
		return null
	return snapshot


## 写入框架构建的行快照。
## [br]
## @api framework_internal
## [br]
## @since unreleased
## [br]
## @param source_row_index: 源行索引。
## [br]
## @param row_id: 稳定行 ID。
## [br]
## @schema row_id: Variant stable row identity.
## [br]
## @param values: 以列 ID 为键的值快照。
## [br]
## @schema values: Dictionary keyed by StringName column IDs with Variant values.
## [br]
## @return 首次配置且 row_id 是 GFVariantKeyCodec 稳定 key 时返回 true。
func configure_for_framework(
	source_row_index: int,
	row_id: Variant,
	values: Dictionary
) -> bool:
	if _configured or source_row_index < 0 or not GFVariantKeyCodec.is_stable_key(row_id):
		return false
	var row_id_report: Dictionary = duplicate_isolated_variant_for_framework(row_id)
	if not GFVariantData.get_option_bool(row_id_report, "ok"):
		return false
	var values_report: Dictionary = duplicate_isolated_variant_for_framework(values)
	if not GFVariantData.get_option_bool(values_report, "ok"):
		return false
	var copied_values_value: Variant = GFVariantData.get_option_value(values_report, "value")
	if not copied_values_value is Dictionary:
		return false
	var copied_values: Dictionary = copied_values_value
	_configured = true
	_source_row_index = source_row_index
	_row_id = GFVariantData.get_option_value(row_id_report, "value")
	_values = copied_values
	return true


# --- 私有/辅助方法 ---

static func _make_snapshot_state() -> Dictionary:
	return {
		"node_count": 0,
		"collection_item_count": 0,
		"utf8_byte_count": 0,
		"active_references": [],
	}


static func _preflight_isolated_value(
	value: Variant,
	state: Dictionary,
	depth: int
) -> Dictionary:
	var budget_error: StringName = _consume_snapshot_node(state, depth)
	if budget_error != &"":
		return _make_copy_failure(budget_error)
	if _is_packed_array_type(typeof(value)):
		if not _reserve_packed_array_bytes(state, value):
			return _make_copy_failure(&"snapshot_budget_exceeded")
		return _make_copy_success(null)

	match typeof(value):
		TYPE_STRING, TYPE_STRING_NAME, TYPE_NODE_PATH:
			if not _reserve_utf8_bytes(state, GFVariantData.to_text(value)):
				return _make_copy_failure(&"snapshot_utf8_budget_exceeded")
		TYPE_ARRAY:
			var source_array: Array = value
			if not _reserve_collection_items(state, source_array.size()):
				return _make_copy_failure(&"snapshot_collection_budget_exceeded")
			if not _push_active_reference(state, source_array):
				return _make_copy_failure(&"circular_snapshot_value")
			for item: Variant in source_array:
				var item_report: Dictionary = _preflight_isolated_value(
					item,
					state,
					depth + 1
				)
				if not GFVariantData.get_option_bool(item_report, "ok"):
					_pop_active_reference(state)
					return item_report
			_pop_active_reference(state)
		TYPE_DICTIONARY:
			var source_dictionary: Dictionary = value
			if not _reserve_collection_items(state, source_dictionary.size() * 2):
				return _make_copy_failure(&"snapshot_collection_budget_exceeded")
			if not _push_active_reference(state, source_dictionary):
				return _make_copy_failure(&"circular_snapshot_value")
			for source_key: Variant in source_dictionary.keys():
				var key_report: Dictionary = _preflight_isolated_value(
					source_key,
					state,
					depth + 1
				)
				if not GFVariantData.get_option_bool(key_report, "ok"):
					_pop_active_reference(state)
					return key_report
				var value_report: Dictionary = _preflight_isolated_value(
					source_dictionary[source_key],
					state,
					depth + 1
				)
				if not GFVariantData.get_option_bool(value_report, "ok"):
					_pop_active_reference(state)
					return value_report
			_pop_active_reference(state)
		TYPE_OBJECT:
			if not value is Resource:
				return _make_copy_failure(&"unsafe_snapshot_reference")
			var source_resource: Resource = value
			if source_resource.get_script() != null:
				return _make_copy_failure(&"scripted_resource_snapshot")
			if not _push_active_reference(state, source_resource):
				return _make_copy_failure(&"circular_snapshot_value")
			var property_list: Array[Dictionary] = source_resource.get_property_list()
			if not _reserve_collection_items(state, property_list.size()):
				_pop_active_reference(state)
				return _make_copy_failure(&"snapshot_collection_budget_exceeded")
			for property_info: Dictionary in property_list:
				var usage: int = GFVariantData.get_option_int(property_info, "usage")
				if (usage & PROPERTY_USAGE_STORAGE) == 0:
					continue
				var property_name: StringName = GFVariantData.get_option_string_name(
					property_info,
					"name"
				)
				if property_name == &"script":
					continue
				var property_report: Dictionary = _preflight_isolated_value(
					source_resource.get(property_name),
					state,
					depth + 1
				)
				if not GFVariantData.get_option_bool(property_report, "ok"):
					_pop_active_reference(state)
					return property_report
			_pop_active_reference(state)
		TYPE_CALLABLE, TYPE_SIGNAL, TYPE_RID:
			return _make_copy_failure(&"unsafe_snapshot_reference")
	return _make_copy_success(null)


static func _get_isolated_copy(value: Variant) -> Variant:
	var report: Dictionary = duplicate_isolated_variant_for_framework(value)
	if not GFVariantData.get_option_bool(report, "ok"):
		return null
	return GFVariantData.get_option_value(report, "value")


static func _duplicate_isolated_value(
	value: Variant,
	state: Dictionary,
	depth: int
) -> Dictionary:
	var budget_error: StringName = _consume_snapshot_node(state, depth)
	if budget_error != &"":
		return _make_copy_failure(budget_error)
	if _is_packed_array_type(typeof(value)):
		if not _reserve_packed_array_bytes(state, value):
			return _make_copy_failure(&"snapshot_utf8_budget_exceeded")
		return _make_copy_success(GFVariantData.duplicate_variant(value, true, false))

	match typeof(value):
		TYPE_STRING, TYPE_STRING_NAME, TYPE_NODE_PATH:
			if not _reserve_utf8_bytes(state, GFVariantData.to_text(value)):
				return _make_copy_failure(&"snapshot_utf8_budget_exceeded")
			return _make_copy_success(value)
		TYPE_ARRAY:
			var source_array: Array = value
			return _duplicate_isolated_array(source_array, state, depth)
		TYPE_DICTIONARY:
			var source_dictionary: Dictionary = value
			return _duplicate_isolated_dictionary(source_dictionary, state, depth)
		TYPE_OBJECT:
			if value is Resource:
				var source_resource: Resource = value
				return _duplicate_isolated_resource(source_resource, state, depth)
			return _make_copy_failure(&"unsafe_snapshot_reference")
		TYPE_CALLABLE, TYPE_SIGNAL, TYPE_RID:
			return _make_copy_failure(&"unsafe_snapshot_reference")
		_:
			return _make_copy_success(value)


static func _duplicate_isolated_array(
	source_array: Array,
	state: Dictionary,
	depth: int
) -> Dictionary:
	if not _reserve_collection_items(state, source_array.size()):
		return _make_copy_failure(&"snapshot_collection_budget_exceeded")
	if not _push_active_reference(state, source_array):
		return _make_copy_failure(&"circular_snapshot_value")
	var copied_array: Array = []
	for item: Variant in source_array:
		var item_report: Dictionary = _duplicate_isolated_value(item, state, depth + 1)
		if not GFVariantData.get_option_bool(item_report, "ok"):
			_pop_active_reference(state)
			return item_report
		copied_array.append(GFVariantData.get_option_value(item_report, "value"))
	_pop_active_reference(state)
	return _make_copy_success(copied_array)


static func _duplicate_isolated_dictionary(
	source_dictionary: Dictionary,
	state: Dictionary,
	depth: int
) -> Dictionary:
	if not _reserve_collection_items(state, source_dictionary.size() * 2):
		return _make_copy_failure(&"snapshot_collection_budget_exceeded")
	if not _push_active_reference(state, source_dictionary):
		return _make_copy_failure(&"circular_snapshot_value")
	var copied_dictionary: Dictionary = {}
	for source_key: Variant in source_dictionary.keys():
		var key_report: Dictionary = _duplicate_isolated_value(source_key, state, depth + 1)
		if not GFVariantData.get_option_bool(key_report, "ok"):
			_pop_active_reference(state)
			return key_report
		var value_report: Dictionary = _duplicate_isolated_value(
			source_dictionary[source_key],
			state,
			depth + 1
		)
		if not GFVariantData.get_option_bool(value_report, "ok"):
			_pop_active_reference(state)
			return value_report
		copied_dictionary[GFVariantData.get_option_value(key_report, "value")] = (
			GFVariantData.get_option_value(value_report, "value")
		)
	_pop_active_reference(state)
	return _make_copy_success(copied_dictionary)


static func _duplicate_isolated_resource(
	source_resource: Resource,
	state: Dictionary,
	depth: int
) -> Dictionary:
	if source_resource.get_script() != null:
		return _make_copy_failure(&"scripted_resource_snapshot")
	if not _push_active_reference(state, source_resource):
		return _make_copy_failure(&"circular_snapshot_value")
	var copied_resource: Resource = source_resource.duplicate(true)
	if copied_resource == null or is_same(copied_resource, source_resource):
		_pop_active_reference(state)
		return _make_copy_failure(&"resource_snapshot_duplicate_failed")
	var validation_report: Dictionary = _validate_resource_copy(
		source_resource,
		copied_resource,
		state,
		depth + 1
	)
	_pop_active_reference(state)
	if not GFVariantData.get_option_bool(validation_report, "ok"):
		return validation_report
	return _make_copy_success(copied_resource)


static func _validate_resource_copy(
	source_resource: Resource,
	copied_resource: Resource,
	state: Dictionary,
	depth: int
) -> Dictionary:
	if source_resource.get_script() != null or copied_resource.get_script() != null:
		return _make_copy_failure(&"scripted_resource_snapshot")
	var property_list: Array[Dictionary] = source_resource.get_property_list()
	if not _reserve_collection_items(state, property_list.size()):
		return _make_copy_failure(&"snapshot_collection_budget_exceeded")
	for property_info: Dictionary in property_list:
		var usage: int = GFVariantData.get_option_int(property_info, "usage")
		if (usage & PROPERTY_USAGE_STORAGE) == 0:
			continue
		var property_name: StringName = GFVariantData.get_option_string_name(
			property_info,
			"name"
		)
		if property_name == &"script":
			continue
		var pair_report: Dictionary = _validate_isolated_pair(
			source_resource.get(property_name),
			copied_resource.get(property_name),
			state,
			depth
		)
		if not GFVariantData.get_option_bool(pair_report, "ok"):
			return pair_report
	return _make_copy_success(copied_resource)


static func _validate_isolated_pair(
	source_value: Variant,
	copied_value: Variant,
	state: Dictionary,
	depth: int
) -> Dictionary:
	var budget_error: StringName = _consume_snapshot_node(state, depth)
	if budget_error != &"":
		return _make_copy_failure(budget_error)
	if typeof(source_value) != typeof(copied_value):
		return _make_copy_failure(&"resource_snapshot_shape_mismatch")
	if _is_packed_array_type(typeof(source_value)):
		if not _reserve_packed_array_bytes(state, copied_value):
			return _make_copy_failure(&"snapshot_utf8_budget_exceeded")
		if not GFVariantData.values_equal(source_value, copied_value):
			return _make_copy_failure(&"resource_snapshot_value_mismatch")
		return _make_copy_success(copied_value)

	match typeof(source_value):
		TYPE_STRING, TYPE_STRING_NAME, TYPE_NODE_PATH:
			if not _reserve_utf8_bytes(state, GFVariantData.to_text(copied_value)):
				return _make_copy_failure(&"snapshot_utf8_budget_exceeded")
			if not GFVariantData.values_equal(source_value, copied_value):
				return _make_copy_failure(&"resource_snapshot_value_mismatch")
		TYPE_ARRAY:
			var source_array: Array = source_value
			var copied_array: Array = copied_value
			if is_same(source_array, copied_array) or source_array.size() != copied_array.size():
				return _make_copy_failure(&"resource_snapshot_alias")
			if not _reserve_collection_items(state, source_array.size()):
				return _make_copy_failure(&"snapshot_collection_budget_exceeded")
			if not _push_active_reference(state, source_array):
				return _make_copy_failure(&"circular_snapshot_value")
			for index: int in range(source_array.size()):
				var item_report: Dictionary = _validate_isolated_pair(
					source_array[index],
					copied_array[index],
					state,
					depth + 1
				)
				if not GFVariantData.get_option_bool(item_report, "ok"):
					_pop_active_reference(state)
					return item_report
			_pop_active_reference(state)
		TYPE_DICTIONARY:
			var source_dictionary: Dictionary = source_value
			var copied_dictionary: Dictionary = copied_value
			if (
				is_same(source_dictionary, copied_dictionary)
				or source_dictionary.size() != copied_dictionary.size()
			):
				return _make_copy_failure(&"resource_snapshot_alias")
			var source_keys: Array = source_dictionary.keys()
			var copied_keys: Array = copied_dictionary.keys()
			if not _reserve_collection_items(state, source_keys.size() * 2):
				return _make_copy_failure(&"snapshot_collection_budget_exceeded")
			if not _push_active_reference(state, source_dictionary):
				return _make_copy_failure(&"circular_snapshot_value")
			for index: int in range(source_keys.size()):
				var key_report: Dictionary = _validate_isolated_pair(
					source_keys[index],
					copied_keys[index],
					state,
					depth + 1
				)
				if not GFVariantData.get_option_bool(key_report, "ok"):
					_pop_active_reference(state)
					return key_report
				var value_report: Dictionary = _validate_isolated_pair(
					source_dictionary[source_keys[index]],
					copied_dictionary[copied_keys[index]],
					state,
					depth + 1
				)
				if not GFVariantData.get_option_bool(value_report, "ok"):
					_pop_active_reference(state)
					return value_report
			_pop_active_reference(state)
		TYPE_OBJECT:
			if not source_value is Resource or not copied_value is Resource:
				return _make_copy_failure(&"unsafe_snapshot_reference")
			var source_resource: Resource = source_value
			var copied_resource: Resource = copied_value
			if source_resource.get_script() != null or copied_resource.get_script() != null:
				return _make_copy_failure(&"scripted_resource_snapshot")
			if is_same(source_resource, copied_resource):
				return _make_copy_failure(&"resource_snapshot_alias")
			if not _push_active_reference(state, source_resource):
				return _make_copy_failure(&"circular_snapshot_value")
			var resource_report: Dictionary = _validate_resource_copy(
				source_resource,
				copied_resource,
				state,
				depth + 1
			)
			_pop_active_reference(state)
			return resource_report
		TYPE_CALLABLE, TYPE_SIGNAL, TYPE_RID:
			return _make_copy_failure(&"unsafe_snapshot_reference")
		_:
			if not GFVariantData.values_equal(source_value, copied_value):
				return _make_copy_failure(&"resource_snapshot_value_mismatch")
	return _make_copy_success(copied_value)


static func _consume_snapshot_node(state: Dictionary, depth: int) -> StringName:
	if depth > _MAX_SNAPSHOT_DEPTH:
		return &"snapshot_depth_exceeded"
	var node_count: int = GFVariantData.get_option_int(state, "node_count") + 1
	state["node_count"] = node_count
	if node_count > _MAX_SNAPSHOT_NODE_COUNT:
		return &"snapshot_node_budget_exceeded"
	return &""


static func _reserve_collection_items(state: Dictionary, item_count: int) -> bool:
	var next_count: int = (
		GFVariantData.get_option_int(state, "collection_item_count")
		+ maxi(item_count, 0)
	)
	state["collection_item_count"] = next_count
	return next_count <= _MAX_SNAPSHOT_COLLECTION_ITEM_COUNT


static func _reserve_utf8_bytes(state: Dictionary, text_value: String) -> bool:
	var used_bytes: int = GFVariantData.get_option_int(state, "utf8_byte_count")
	var remaining_bytes: int = _MAX_SNAPSHOT_UTF8_BYTES - used_bytes
	if remaining_bytes < 0 or text_value.length() > remaining_bytes:
		return false
	return _reserve_bytes(state, text_value.to_utf8_buffer().size())


static func _reserve_packed_array_bytes(state: Dictionary, value: Variant) -> bool:
	var byte_count: int = 0
	match typeof(value):
		TYPE_PACKED_BYTE_ARRAY:
			var values: PackedByteArray = value
			return _reserve_fixed_width_packed_array(state, values.size(), 1)
		TYPE_PACKED_INT32_ARRAY:
			var values: PackedInt32Array = value
			return _reserve_fixed_width_packed_array(state, values.size(), 4)
		TYPE_PACKED_FLOAT32_ARRAY:
			var values: PackedFloat32Array = value
			return _reserve_fixed_width_packed_array(state, values.size(), 4)
		TYPE_PACKED_INT64_ARRAY:
			var values: PackedInt64Array = value
			return _reserve_fixed_width_packed_array(state, values.size(), 8)
		TYPE_PACKED_FLOAT64_ARRAY:
			var values: PackedFloat64Array = value
			return _reserve_fixed_width_packed_array(state, values.size(), 8)
		TYPE_PACKED_VECTOR2_ARRAY:
			var values: PackedVector2Array = value
			return _reserve_fixed_width_packed_array(state, values.size(), 16)
		TYPE_PACKED_VECTOR3_ARRAY:
			var values: PackedVector3Array = value
			return _reserve_fixed_width_packed_array(state, values.size(), 24)
		TYPE_PACKED_COLOR_ARRAY:
			var values: PackedColorArray = value
			return _reserve_fixed_width_packed_array(state, values.size(), 16)
		TYPE_PACKED_VECTOR4_ARRAY:
			var values: PackedVector4Array = value
			return _reserve_fixed_width_packed_array(state, values.size(), 32)
		TYPE_PACKED_STRING_ARRAY:
			var values: PackedStringArray = value
			if not _reserve_collection_items(state, values.size()):
				return false
			for item: String in values:
				if not _reserve_utf8_bytes(state, item):
					return false
			return true
	return _reserve_bytes(state, byte_count)


static func _reserve_fixed_width_packed_array(
	state: Dictionary,
	item_count: int,
	item_width: int
) -> bool:
	if not _reserve_collection_items(state, item_count):
		return false
	var used_bytes: int = GFVariantData.get_option_int(state, "utf8_byte_count")
	var remaining_bytes: int = _MAX_SNAPSHOT_UTF8_BYTES - used_bytes
	if item_width <= 0 or item_count > floori(float(remaining_bytes) / float(item_width)):
		return false
	return _reserve_bytes(state, item_count * item_width)


static func _is_packed_array_type(value_type: int) -> bool:
	return value_type in [
		TYPE_PACKED_BYTE_ARRAY,
		TYPE_PACKED_INT32_ARRAY,
		TYPE_PACKED_INT64_ARRAY,
		TYPE_PACKED_FLOAT32_ARRAY,
		TYPE_PACKED_FLOAT64_ARRAY,
		TYPE_PACKED_STRING_ARRAY,
		TYPE_PACKED_VECTOR2_ARRAY,
		TYPE_PACKED_VECTOR3_ARRAY,
		TYPE_PACKED_COLOR_ARRAY,
		TYPE_PACKED_VECTOR4_ARRAY,
	]


static func _reserve_bytes(state: Dictionary, byte_count: int) -> bool:
	var next_count: int = (
		GFVariantData.get_option_int(state, "utf8_byte_count")
		+ maxi(byte_count, 0)
	)
	state["utf8_byte_count"] = next_count
	return next_count <= _MAX_SNAPSHOT_UTF8_BYTES


static func _push_active_reference(state: Dictionary, value: Variant) -> bool:
	var active_references_value: Variant = GFVariantData.get_option_value(
		state,
		"active_references"
	)
	var active_references: Array = []
	if active_references_value is Array:
		active_references = active_references_value
	for active_value: Variant in active_references:
		if is_same(active_value, value):
			return false
	active_references.append(value)
	state["active_references"] = active_references
	return true


static func _pop_active_reference(state: Dictionary) -> void:
	var active_references_value: Variant = GFVariantData.get_option_value(
		state,
		"active_references"
	)
	var active_references: Array = []
	if active_references_value is Array:
		active_references = active_references_value
	if not active_references.is_empty():
		active_references.pop_back()
	state["active_references"] = active_references


static func _make_copy_success(value: Variant) -> Dictionary:
	return {
		"ok": true,
		"value": value,
		"error_code": &"",
	}


static func _make_copy_failure(error_code: StringName) -> Dictionary:
	return {
		"ok": false,
		"value": null,
		"error_code": error_code,
	}
