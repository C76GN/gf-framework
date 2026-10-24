# Save 请求的小型纯数据隔离边界；大 section 载荷不经过此路径。
extends RefCounted


# --- 常量 ---

## 完整请求元数据允许的最大嵌套深度。
## [br]
## @api private
## [br]
const _MAX_DEPTH: int = 64

## 完整请求元数据允许的最大遍历节点数。
## [br]
## @api private
## [br]
const _MAX_NODES: int = 100_000

## 保守计量的元数据复制预算；并非序列化后的文件大小。
## [br]
## @api private
## [br]
const _MAX_BYTES: int = 1_048_576

## 检查已通过大小预检的纯数据与浮点值。
## [br]
## @api private
## [br]
const _PERSISTED_VALUE_VALIDATOR_SCRIPT = preload("res://addons/gf/extensions/save/core/gf_save_persisted_value_validator.gd")


# --- 框架内部方法 ---

## 在复制前完成深度、节点和字节预算预检，再隔离全部请求元数据。
##
## 三个字典共享 64 层、100000 节点与 1 MiB 保守计量预算。对象、可执行值、
## 循环和非有限数被拒绝。预检按展开后的引用计量，重复子树也不能绕过预算。
## [br]
## @api framework_internal
## [br]
## @since unreleased
## [br]
## @param document_metadata: 文档元数据。
## [br]
## @param context: Provider 纯数据上下文。
## [br]
## @param result_metadata: 结果元数据。
## [br]
## @schema document_metadata: Dictionary of bounded Save persisted values.
## [br]
## @schema context: Dictionary of bounded Save persisted values.
## [br]
## @schema result_metadata: Dictionary of bounded Save persisted values.
## [br]
## @return 三个隔离字典组成的记录；输入无效或超预算时为空。
## [br]
## @schema return: Empty on rejection; otherwise document_metadata, context, result_metadata are isolated Dictionaries.
static func capture(
	document_metadata: Dictionary,
	context: Dictionary,
	result_metadata: Dictionary
) -> Dictionary:
	var inputs: Dictionary = {
		"document_metadata": document_metadata,
		"context": context,
		"result_metadata": result_metadata,
	}
	var budget: Dictionary = { "nodes": 0, "bytes": 0, }
	if not _fits_budget(
		inputs,
		0,
		[],
		budget
	):
		return {}
	var report: Dictionary = _PERSISTED_VALUE_VALIDATOR_SCRIPT.validate(inputs)
	if not GFVariantData.get_option_bool(
		report,
		"ok",
		false
	):
		return {}
	return inputs.duplicate(true)


# --- 私有/辅助方法 ---

## 在任何完整复制或 packed-array 展开前拒绝超预算输入。
## [br]
## @api private
## [br]
static func _fits_budget(
	value: Variant,
	depth: int,
	ancestors: Array,
	budget: Dictionary
) -> bool:
	if depth > _MAX_DEPTH or not _charge(
		budget,
		1,
		128
	):
		return false
	match typeof(value):
		TYPE_OBJECT, TYPE_CALLABLE, TYPE_SIGNAL, TYPE_RID:
			return false
		TYPE_STRING:
			var text: String = value
			return _charge(
				budget,
				0,
				text.length() * 4
			)
		TYPE_STRING_NAME:
			var name: StringName = value
			return _charge(
				budget,
				0,
				name.length() * 4
			)
		TYPE_NODE_PATH:
			var path: NodePath = value
			if not _charge(
				budget,
				path.get_name_count() + path.get_subname_count(),
				path.get_name_count() + path.get_subname_count()
			):
				return false
			for index: int in range(path.get_name_count()):
				if not _charge(
					budget,
					0,
					path.get_name(index).length() * 4
				):
					return false
			for index: int in range(path.get_subname_count()):
				if not _charge(
					budget,
					0,
					path.get_subname(index).length() * 4
				):
					return false
			return true
		TYPE_ARRAY, TYPE_DICTIONARY:
			if not _has_plain_container_type(value):
				return false
			for ancestor: Variant in ancestors:
				if is_same(ancestor, value):
					return false
			ancestors.append(value)
			var accepted: bool = true
			if value is Array:
				var array: Array = value
				if array.size() > _MAX_NODES - GFVariantData.get_option_int(budget, "nodes"):
					accepted = false
				else:
					for item: Variant in array:
						if not _fits_budget(
							item,
							depth + 1,
							ancestors,
							budget
						):
							accepted = false
							break
			else:
				var dictionary: Dictionary = value
				if dictionary.size() * 2 > _MAX_NODES - GFVariantData.get_option_int(budget, "nodes"):
					accepted = false
				else:
					for key: Variant in dictionary:
						if not _fits_budget(
							key,
							depth + 1,
							ancestors,
							budget
						) or not _fits_budget(
							dictionary[key],
							depth + 1,
							ancestors,
							budget
						):
							accepted = false
							break
			var _removed: Variant = ancestors.pop_back()
			return accepted
		TYPE_PACKED_BYTE_ARRAY:
			var bytes: PackedByteArray = value
			return _charge(
				budget,
				0,
				bytes.size()
			)
		TYPE_PACKED_INT32_ARRAY:
			var integers: PackedInt32Array = value
			return _charge(
				budget,
				0,
				integers.size() * 4
			)
		TYPE_PACKED_INT64_ARRAY:
			var integers: PackedInt64Array = value
			return _charge(
				budget,
				0,
				integers.size() * 8
			)
		TYPE_PACKED_FLOAT32_ARRAY:
			var numbers: PackedFloat32Array = value
			return _charge(
				budget,
				numbers.size(),
				numbers.size() * 32
			)
		TYPE_PACKED_FLOAT64_ARRAY:
			var numbers: PackedFloat64Array = value
			return _charge(
				budget,
				numbers.size(),
				numbers.size() * 32
			)
		TYPE_PACKED_VECTOR2_ARRAY:
			var vectors: PackedVector2Array = value
			return _charge(
				budget,
				vectors.size(),
				vectors.size() * 32
			)
		TYPE_PACKED_VECTOR3_ARRAY:
			var vectors: PackedVector3Array = value
			return _charge(
				budget,
				vectors.size(),
				vectors.size() * 32
			)
		TYPE_PACKED_VECTOR4_ARRAY:
			var vectors: PackedVector4Array = value
			return _charge(
				budget,
				vectors.size(),
				vectors.size() * 32
			)
		TYPE_PACKED_COLOR_ARRAY:
			var colors: PackedColorArray = value
			return _charge(
				budget,
				colors.size(),
				colors.size() * 32
			)
		TYPE_PACKED_STRING_ARRAY:
			var strings: PackedStringArray = value
			if not _charge(
				budget,
				strings.size(),
				strings.size() * 32
			):
				return false
			for text: String in strings:
				if not _charge(
					budget,
					0,
					text.length() * 4
				):
					return false
	return true


## 空容器也必须检查类型元数据，避免对象约束或脚本引用越过纯数据边界。
## [br]
## @api private
## [br]
static func _has_plain_container_type(value: Variant) -> bool:
	if value is Array:
		var array: Array = value
		return (
			array.get_typed_script() == null
			and array.get_typed_class_name().is_empty()
			and array.get_typed_builtin() not in [
				TYPE_OBJECT,
				TYPE_CALLABLE,
				TYPE_SIGNAL,
				TYPE_RID,
			]
		)
	var dictionary: Dictionary = value
	return (
		dictionary.get_typed_key_script() == null
		and dictionary.get_typed_value_script() == null
		and dictionary.get_typed_key_class_name().is_empty()
		and dictionary.get_typed_value_class_name().is_empty()
		and dictionary.get_typed_key_builtin() not in [
			TYPE_OBJECT,
			TYPE_CALLABLE,
			TYPE_SIGNAL,
			TYPE_RID,
		]
		and dictionary.get_typed_value_builtin() not in [
			TYPE_OBJECT,
			TYPE_CALLABLE,
			TYPE_SIGNAL,
			TYPE_RID,
		]
	)


## 累计保守成本；先检查剩余量以避免整数溢出和后续大分配。
## [br]
## @api private
## [br]
static func _charge(
	budget: Dictionary,
	nodes: int,
	bytes: int
) -> bool:
	var used_nodes: int = GFVariantData.get_option_int(budget, "nodes")
	var used_bytes: int = GFVariantData.get_option_int(budget, "bytes")
	if nodes > _MAX_NODES - used_nodes or bytes > _MAX_BYTES - used_bytes:
		return false
	budget["nodes"] = used_nodes + nodes
	budget["bytes"] = used_bytes + bytes
	return true
