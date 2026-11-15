# GFDataValueCapture: 有预算的纯数据树捕获，集合身份只用于当前路径的循环检测。
# @api framework_internal
# @layer kernel/core
extends RefCounted


# --- 框架内部方法 ---

## 隔离纯值树，失败时丢弃全部部分副本。
## [br]
## @api framework_internal
## [br]
## @param value: 调用期间保持稳定的纯 Variant。
## [br]
## @schema value: Built-in values and containers without Object, Resource, Callable, Signal or RID.
## [br]
## @param limits: 正整数预算以及可选取消令牌。
## [br]
## @schema limits: Dictionary with max_items, max_depth, max_string_length, max_payload_bytes, max_elapsed_msec and cancel_token.
## [br]
## @return 捕获结果和处理计量。
## [br]
## @schema return: Dictionary with ok, value, error_kind, error_path, limit_kind, limit, observed, counts_complete, items, packed_items, payload_bytes and maximum_depth.
static func capture(value: Variant, limits: Dictionary = {}) -> Dictionary:
	var operation: _Capture = _Capture.new(limits)
	var copied: Variant = operation._copy_value(
		value,
		"$",
		0
	)
	var _within_budget: bool = operation._check("$")
	var report: Dictionary = operation._report
	report["counts_complete"] = report["ok"]
	report["value"] = copied if report["ok"] else null
	return report


# --- 内部类 ---

## 单次捕获拥有计量、有限递归路径及取消状态。
## [br]
## @api private
class _Capture extends RefCounted:


	# --- 私有变量 ---

	## 调用完成后交付的计量；部分树不进入失败报告。
	## [br]
	## @api private
	var _report: Dictionary = {
		"ok": true,
		"error_kind": "",
		"error_path": "",
		"limit_kind": "",
		"limit": 0,
		"observed": 0,
		"counts_complete": false,
		"items": 0,
		"packed_items": 0,
		"payload_bytes": 0,
		"maximum_depth": 0,
	}

	## 同一操作的固定硬预算。
	## [br]
	## @api private
	var _limits: Dictionary = {
		"max_items": 1000000,
		"max_depth": 64,
		"max_string_length": 1048576,
		"max_payload_bytes": 67108864,
		"max_elapsed_msec": 30000,
	}

	## 尚未完成复制的祖先容器，长度由深度预算限制。
	## [br]
	## @api private
	var _active: Array = []

	## 可选只读取消令牌。
	## [br]
	## @api private
	var _cancel_token: GFCancellationToken = null

	## 操作开始的单调时钟。
	## [br]
	## @api private
	var _started: int = Time.get_ticks_msec()


	# --- Godot 生命周期方法 ---

	## 固定本次限制；非法配置在触碰输入前失败。
	## [br]
	## @api private
	func _init(limits: Dictionary) -> void:
		for key: Variant in limits:
			if not (key is String or key is StringName):
				_fail("invalid_limits", "$")
				return
			if key == "cancel_token":
				if limits[key] != null and not limits[key] is GFCancellationToken:
					_fail("invalid_limits", "$")
					return
				_cancel_token = limits[key]
			elif (
				not _limits.has(key)
				or not limits[key] is int
				or limits[key] <= 0
			):
				_fail("invalid_limits", "$")
				return
			else:
				_limits[key] = limits[key]
		if _limits["max_depth"] > 256:
			_fail("invalid_limits", "$")


	# --- 私有/辅助方法 ---

	## 每个值按出现次数计量；共享子树在不同位置独立捕获。
	## [br]
	## @api private
	func _copy_value(
		value: Variant,
		path: String,
		depth: int
	) -> Variant:
		if not _check(path) or not _consume(
			"items",
			1,
			"max_items",
			path
		):
			return null
		if depth > _limits["max_depth"]:
			_limit(
				"max_depth",
				depth,
				path
			)
			return null
		var maximum_depth: int = _report["maximum_depth"]
		_report["maximum_depth"] = maxi(maximum_depth, depth)
		if value is Object or typeof(value) in [
			TYPE_CALLABLE,
			TYPE_SIGNAL,
			TYPE_RID,
		]:
			_fail("unsupported_type", path)
			return null
		if value is Array or value is Dictionary:
			for ancestor: Variant in _active:
				if is_same(ancestor, value):
					_fail("cycle", path)
					return null
			_active.append(value)
			var result: Variant = _copy_container(
				value,
				path,
				depth
			)
			var _removed_ancestor: Variant = _active.pop_back()
			return result
		if (
			value is String
			or value is StringName
			or value is NodePath
		):
			var text: String = str(value)
			if not _count_string(text, path):
				return null
			return value
		if typeof(value) >= TYPE_PACKED_BYTE_ARRAY and typeof(value) <= TYPE_PACKED_VECTOR4_ARRAY:
			return _copy_packed(value, path)
		var payload_size: int = _fixed_size(typeof(value))
		if payload_size < 0:
			_fail("unsupported_type", path)
			return null
		if not _consume(
			"payload_bytes",
			payload_size,
			"max_payload_bytes",
			path
		):
			return null
		return value


	## 先校验直接子项的最低成本，再分配目标容器。
	## [br]
	## @api private
	func _copy_container(
		value: Variant,
		path: String,
		depth: int
	) -> Variant:
		if value is Array:
			var source_array: Array = value
			if source_array.get_typed_builtin() == TYPE_OBJECT:
				_fail("unsupported_type", path)
				return null
			if not _admit_children(
				source_array.size(),
				path
			):
				return null
			var array_copy: Array = Array(
				[],
				source_array.get_typed_builtin(),
				source_array.get_typed_class_name(),
				source_array.get_typed_script()
			)
			for index: int in source_array.size():
				var item: Variant = _copy_value(
					source_array[index],
					"%s[%d]"
					% [path, index],
					depth + 1
				)
				if not _report["ok"]:
					return null
				array_copy.append(item)
			return array_copy
		var source: Dictionary = value
		if source.get_typed_key_builtin() == TYPE_OBJECT or source.get_typed_value_builtin() == TYPE_OBJECT:
			_fail("unsupported_type", path)
			return null
		var maximum_items: int = _limits["max_items"]
		if source.size() > (maximum_items >> 1):
			_limit(
				"max_items",
				_over_limit("max_items"),
				path
			)
			return null
		if not _admit_children(
			source.size() * 2,
			path
		):
			return null
		var result: Dictionary = Dictionary(
			{},
			source.get_typed_key_builtin(),
			source.get_typed_key_class_name(),
			source.get_typed_key_script(),
			source.get_typed_value_builtin(),
			source.get_typed_value_class_name(),
			source.get_typed_value_script()
		)
		var index: int = 0
		for key: Variant in source:
			var entry_path: String = (
				"%s[%d]"
				% [path, index]
			)
			var copied_key: Variant = _copy_value(
				key,
				entry_path + ".key",
				depth + 1
			)
			if not _report["ok"]:
				return null
			var item: Variant = _copy_value(
				source[key],
				entry_path + ".value",
				depth + 1
			)
			if not _report["ok"]:
				return null
			result[copied_key] = item
			index += 1
		return result


	## 用直接子项下界限制首次容器分配。
	## [br]
	## @api private
	func _admit_children(count: int, path: String) -> bool:
		var maximum_items: int = _limits["max_items"]
		var current_items: int = _report["items"]
		if count > maximum_items - current_items:
			_limit(
				"max_items",
				current_items + count,
				path
			)
			return false
		return true


	## Packed 内容由类型保证元素形状，整数列直接按宽度计量并复制。
	## [br]
	## @api private
	func _copy_packed(value: Variant, path: String) -> Variant:
		var count: int = _packed_count(value)
		if not _consume(
			"items",
			count,
			"max_items",
			path
		):
			return null
		_report["packed_items"] += count
		if value is PackedStringArray:
			var strings: PackedStringArray = value
			for text: String in strings:
				if not _check(path) or not _count_string(text, path):
					return null
			return strings.duplicate()
		var width: int = _packed_width(typeof(value))
		var maximum_bytes: int = _limits["max_payload_bytes"]
		# Int64 budgets require exact truncation before the multiplication overflow check.
		@warning_ignore("integer_division")
		var maximum_elements: int = maximum_bytes / width
		if count > maximum_elements:
			_limit(
				"max_payload_bytes",
				_over_limit("max_payload_bytes"),
				path
			)
			return null
		if not _consume(
			"payload_bytes",
			count * width,
			"max_payload_bytes",
			path
		):
			return null
		match typeof(value):
			TYPE_PACKED_BYTE_ARRAY:
				var values: PackedByteArray = value
				return values.duplicate()
			TYPE_PACKED_INT32_ARRAY:
				var values: PackedInt32Array = value
				return values.duplicate()
			TYPE_PACKED_INT64_ARRAY:
				var values: PackedInt64Array = value
				return values.duplicate()
			TYPE_PACKED_FLOAT32_ARRAY:
				var values: PackedFloat32Array = value
				return values.duplicate()
			TYPE_PACKED_FLOAT64_ARRAY:
				var values: PackedFloat64Array = value
				return values.duplicate()
			TYPE_PACKED_VECTOR2_ARRAY:
				var values: PackedVector2Array = value
				return values.duplicate()
			TYPE_PACKED_VECTOR3_ARRAY:
				var values: PackedVector3Array = value
				return values.duplicate()
			TYPE_PACKED_VECTOR4_ARRAY:
				var values: PackedVector4Array = value
				return values.duplicate()
			TYPE_PACKED_COLOR_ARRAY:
				var values: PackedColorArray = value
				return values.duplicate()
		return null


	## 分段测量 UTF-8，临时字符串缓冲有固定上界。
	## [br]
	## @api private
	func _count_string(value: String, path: String) -> bool:
		if value.length() > _limits["max_string_length"]:
			_limit(
				"max_string_length",
				value.length(),
				path
			)
			return false
		for offset: int in range(
			0,
			value.length(),
			4096
		):
			if not _check(path) or not _consume(
				"payload_bytes",
				value.substr(offset, 4096).to_utf8_buffer().size(),
				"max_payload_bytes",
				path
			):
				return false
		return true


	## 上限诊断避免 int64 加一溢出。
	## [br]
	## @api private
	func _over_limit(name: String) -> int:
		var limit: int = _limits[name]
		return limit + 1 if limit < 9223372036854775807 else limit


	## 有溢出保护的累计计量。
	## [br]
	## @api private
	func _consume(
		counter: String,
		amount: int,
		limit_name: String,
		path: String
	) -> bool:
		var current: int = _report[counter]
		var maximum: int = _limits[limit_name]
		if amount > maximum - current:
			_limit(
				limit_name,
				maximum + 1 if maximum < 9223372036854775807 else maximum,
				path
			)
			return false
		_report[counter] = current + amount
		return true


	## 在受控步骤之间观察截止时间和取消。
	## [br]
	## @api private
	func _check(path: String) -> bool:
		if not _report["ok"]:
			return false
		if _cancel_token != null and _cancel_token.is_cancel_requested():
			_fail("cancelled", path)
			return false
		var elapsed: int = Time.get_ticks_msec() - _started
		if elapsed > _limits["max_elapsed_msec"]:
			_limit(
				"max_elapsed_msec",
				elapsed,
				path
			)
			return false
		return true


	## 保留第一项失败。
	## [br]
	## @api private
	func _fail(kind: String, path: String) -> void:
		if _report["ok"]:
			_report["ok"] = false
			_report["error_kind"] = kind
			_report["error_path"] = path


	## 限额失败保留对应的计量下界。
	## [br]
	## @api private
	func _limit(
		name: String,
		observed: int,
		path: String
	) -> void:
		_fail("limit_exceeded", path)
		_report["limit_kind"] = name
		_report["limit"] = _limits[name]
		_report["observed"] = observed


	## 逻辑标量载荷宽度，容器管理成本由节点预算限制。
	## [br]
	## @api private
	func _fixed_size(type: int) -> int:
		match type:
			TYPE_NIL:
				return 0
			TYPE_BOOL:
				return 1
			TYPE_INT, TYPE_FLOAT:
				return 8
			TYPE_VECTOR2, TYPE_VECTOR2I:
				return 16
			TYPE_VECTOR3, TYPE_VECTOR3I:
				return 24
			TYPE_VECTOR4, TYPE_VECTOR4I, TYPE_RECT2, TYPE_RECT2I, TYPE_PLANE, TYPE_QUATERNION, TYPE_COLOR:
				return 32
			TYPE_TRANSFORM2D, TYPE_AABB:
				return 48
			TYPE_BASIS:
				return 72
			TYPE_TRANSFORM3D:
				return 96
			TYPE_PROJECTION:
				return 128
		return -1


	## Packed 元素个数。
	## [br]
	## @api private
	func _packed_count(value: Variant) -> int:
		match typeof(value):
			TYPE_PACKED_BYTE_ARRAY:
				var values: PackedByteArray = value
				return values.size()
			TYPE_PACKED_INT32_ARRAY:
				var values: PackedInt32Array = value
				return values.size()
			TYPE_PACKED_INT64_ARRAY:
				var values: PackedInt64Array = value
				return values.size()
			TYPE_PACKED_FLOAT32_ARRAY:
				var values: PackedFloat32Array = value
				return values.size()
			TYPE_PACKED_FLOAT64_ARRAY:
				var values: PackedFloat64Array = value
				return values.size()
			TYPE_PACKED_STRING_ARRAY:
				var values: PackedStringArray = value
				return values.size()
			TYPE_PACKED_VECTOR2_ARRAY:
				var values: PackedVector2Array = value
				return values.size()
			TYPE_PACKED_VECTOR3_ARRAY:
				var values: PackedVector3Array = value
				return values.size()
			TYPE_PACKED_VECTOR4_ARRAY:
				var values: PackedVector4Array = value
				return values.size()
			TYPE_PACKED_COLOR_ARRAY:
				var values: PackedColorArray = value
				return values.size()
		return 0


	## Packed 载荷预算使用足够容纳 double precision 构建的固定宽度。
	## [br]
	## @api private
	func _packed_width(type: int) -> int:
		match type:
			TYPE_PACKED_BYTE_ARRAY:
				return 1
			TYPE_PACKED_INT32_ARRAY, TYPE_PACKED_FLOAT32_ARRAY:
				return 4
			TYPE_PACKED_INT64_ARRAY, TYPE_PACKED_FLOAT64_ARRAY:
				return 8
			TYPE_PACKED_VECTOR2_ARRAY:
				return 16
			TYPE_PACKED_VECTOR3_ARRAY:
				return 24
			TYPE_PACKED_VECTOR4_ARRAY, TYPE_PACKED_COLOR_ARRAY:
				return 32
		return 1
