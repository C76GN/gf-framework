# Save Profile evidence 的共享有界值校验；每次调用拥有独立递归路径与计数状态。
extends RefCounted


# --- 常量 ---

## 事务、settlement 与 resolution evidence 的最大递归深度。
## [br]
## @api private
## [br]
const _MAX_EVIDENCE_DEPTH: int = 16

## evidence 支持性检查允许的最大值数量。
## [br]
## @api private
## [br]
const _MAX_EVIDENCE_ITEMS: int = 2048

## evidence 中 String 与 StringName 的最大字符数。
## [br]
## @api private
## [br]
const _MAX_EVIDENCE_STRING_LENGTH: int = 2048


# --- 框架内部方法 ---

## 用独立计数与递归路径状态校验有界 Profile evidence。
## [br]
## @api framework_internal
## [br]
## @layer extensions/save
## [br]
## @since unreleased
## [br]
## @param evidence: 待检查的事务、结算或对账证据。
## [br]
## @schema evidence: Bounded scalar, packed-array, Array and Dictionary evidence without Objects or geometric values.
## [br]
## @return 值类型、数值、深度、计数与容器身份均符合 evidence 合同时返回 true。
static func is_supported_for_framework(evidence: Dictionary) -> bool:
	var state: Dictionary = { "items": 0, "visited": [], }
	return _is_evidence_value_supported(
		evidence,
		0,
		state
	)


# --- 私有/辅助方法 ---

## 按深度、值数量和字符串长度限制递归检查 evidence 值及其容器。
## [br]
## @api private
## [br]
static func _is_evidence_value_supported(
	value: Variant,
	depth: int,
	state: Dictionary
) -> bool:
	if depth > _MAX_EVIDENCE_DEPTH:
		return false
	var item_count: int = GFVariantData.get_option_int(state, "items") + 1
	state["items"] = item_count
	if item_count > _MAX_EVIDENCE_ITEMS:
		return false

	match typeof(value):
		TYPE_NIL, TYPE_BOOL, TYPE_INT:
			return true
		TYPE_FLOAT:
			var number: float = value
			return not is_nan(number) and not is_inf(number)
		TYPE_STRING:
			var text: String = value
			return text.length() <= _MAX_EVIDENCE_STRING_LENGTH
		TYPE_STRING_NAME:
			var identifier: StringName = value
			return String(identifier).length() <= _MAX_EVIDENCE_STRING_LENGTH
		TYPE_PACKED_BYTE_ARRAY:
			var values: PackedByteArray = value
			return _consume_packed_items(
				values.size(),
				state
			)
		TYPE_PACKED_INT32_ARRAY:
			var values: PackedInt32Array = value
			return _consume_packed_items(
				values.size(),
				state
			)
		TYPE_PACKED_INT64_ARRAY:
			var values: PackedInt64Array = value
			return _consume_packed_items(
				values.size(),
				state
			)
		TYPE_PACKED_FLOAT32_ARRAY:
			var values: PackedFloat32Array = value
			if not _consume_packed_items(
				values.size(),
				state
			):
				return false
			for number: float in values:
				if is_nan(number) or is_inf(number):
					return false
			return true
		TYPE_PACKED_FLOAT64_ARRAY:
			var values: PackedFloat64Array = value
			if not _consume_packed_items(
				values.size(),
				state
			):
				return false
			for number: float in values:
				if is_nan(number) or is_inf(number):
					return false
			return true
		TYPE_PACKED_STRING_ARRAY:
			var values: PackedStringArray = value
			if not _consume_packed_items(
				values.size(),
				state
			):
				return false
			for text: String in values:
				if text.length() > _MAX_EVIDENCE_STRING_LENGTH:
					return false
			return true
		TYPE_ARRAY:
			var array_value: Array = value
			var visited: Array = _get_visited(state)
			if _contains_collection_identity(visited, array_value):
				return false
			visited.append(array_value)
			for entry: Variant in array_value:
				if not _is_evidence_value_supported(
					entry,
					depth + 1,
					state
				):
					var _removed_array_failure: Variant = visited.pop_back()
					return false
			var _removed_array: Variant = visited.pop_back()
			return true
		TYPE_DICTIONARY:
			var dictionary_value: Dictionary = value
			var visited: Array = _get_visited(state)
			if _contains_collection_identity(visited, dictionary_value):
				return false
			visited.append(dictionary_value)
			for key: Variant in dictionary_value.keys():
				if (
					typeof(key) not in [TYPE_STRING, TYPE_STRING_NAME]
					or not _is_evidence_value_supported(
						key,
						depth + 1,
						state
					)
				):
					var _removed_invalid_key: Variant = visited.pop_back()
					return false
				if not _is_evidence_value_supported(
					dictionary_value[key],
					depth + 1,
					state
				):
					var _removed_dictionary_failure: Variant = visited.pop_back()
					return false
			var _removed_dictionary: Variant = visited.pop_back()
			return true
		_:
			return false


## 将 packed 容器元素数计入预算并报告是否仍未超出上限。
## [br]
## @api private
## [br]
static func _consume_packed_items(item_count: int, state: Dictionary) -> bool:
	var next_count: int = GFVariantData.get_option_int(state, "items") + item_count
	state["items"] = next_count
	return next_count <= _MAX_EVIDENCE_ITEMS


## 从 evidence 检查状态中读取当前递归路径容器数组。
## [br]
## @api private
## [br]
static func _get_visited(state: Dictionary) -> Array:
	return GFVariantData.as_array(GFVariantData.get_option_value(state, "visited"))


## 按对象身份检查候选容器是否已在当前递归路径中。
## [br]
## @api private
## [br]
static func _contains_collection_identity(collections: Array, candidate: Variant) -> bool:
	for collection: Variant in collections:
		if is_same(collection, candidate):
			return true
	return false
