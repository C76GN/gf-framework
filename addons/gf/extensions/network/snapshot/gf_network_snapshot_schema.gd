## GFNetworkSnapshotSchema: 网络快照字段编码表。
##
## 用字段级编码器转换快照 state，适合项目在自己的同步、回放或存储流程中
## 统一压缩、量化和恢复状态字段。
## [br]
## @api public
## [br]
## @category resource_definition
## [br]
## @since 3.17.0
class_name GFNetworkSnapshotSchema
extends Resource


# --- 导出变量 ---

## 未注册字段是否原样保留。
## [br]
## @api public
@export var include_unregistered_fields: bool = true

## 字段编码器表。Key 推荐使用 StringName 或 String，Value 为 GFNetworkFieldSerializer。
## [br]
## @api public
## [br]
## @schema field_serializers: Dictionary[StringName|String, GFNetworkFieldSerializer]，字段名到字段编码器的映射。
@export var field_serializers: Dictionary = {}


# --- 公共方法 ---

## 设置字段编码器。
## [br]
## @api public
## [br]
## @param field_name: 字段名。
## [br]
## @param serializer: 字段编码器；为空时移除。
func set_field_serializer(field_name: StringName, serializer: GFNetworkFieldSerializer) -> void:
	if field_name == &"":
		return
	if serializer == null:
		var _name_erased: bool = field_serializers.erase(field_name)
		var _text_erased: bool = field_serializers.erase(String(field_name))
		return
	field_serializers[field_name] = serializer


## 移除字段编码器。
## [br]
## @api public
## [br]
## @param field_name: 字段名。
func remove_field_serializer(field_name: StringName) -> void:
	var _name_erased: bool = field_serializers.erase(field_name)
	var _text_erased: bool = field_serializers.erase(String(field_name))


## 获取字段编码器。
## [br]
## @api public
## [br]
## @param field_name: 字段名。
## [br]
## @return 字段编码器；不存在时返回 null。
func get_field_serializer(field_name: StringName) -> GFNetworkFieldSerializer:
	var value: Variant = null
	if field_serializers.has(field_name):
		value = field_serializers[field_name]
	elif field_serializers.has(String(field_name)):
		value = field_serializers[String(field_name)]
	return _variant_to_field_serializer(value)


## 检查字段是否注册了编码器。
## [br]
## @api public
## [br]
## @param field_name: 字段名。
## [br]
## @return 已注册时返回 true。
func has_field_serializer(field_name: StringName) -> bool:
	return get_field_serializer(field_name) != null


## 获取已注册字段名。
## [br]
## @api public
## [br]
## @return 字段名列表。
func get_registered_fields() -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	var seen: Dictionary = {}
	for key: Variant in field_serializers.keys():
		var serializer: GFNetworkFieldSerializer = _variant_to_field_serializer(field_serializers[key])
		if serializer == null:
			continue
		var field_name: String = GFVariantData.to_text(key)
		if seen.has(field_name):
			continue
		seen[field_name] = true
		_append_packed_string(result, field_name)
	result.sort()
	return result


## 编码状态字典。
## [br]
## @api public
## [br]
## @param state: 原始状态。
## [br]
## @return 编码后的状态。
## [br]
## @schema state: Dictionary[StringName|String, Variant]，原始快照状态字段。
## [br]
## @schema return: Dictionary[StringName|String, Variant]，编码后的状态字段。
func encode_state(state: Dictionary) -> Dictionary:
	var encoded: Dictionary = {}
	for field_name: String in get_registered_fields():
		var field_key: StringName = StringName(field_name)
		if not _state_has_field(state, field_key):
			continue

		var serializer: GFNetworkFieldSerializer = get_field_serializer(field_key)
		if serializer != null:
			encoded[field_key] = serializer.serialize_value(_state_get_field(state, field_key))

	if include_unregistered_fields:
		for key: Variant in state.keys():
			if has_field_serializer(StringName(str(key))):
				continue
			encoded[key] = GFVariantData.duplicate_variant(state[key])
	return encoded


## 解码状态字典。
## [br]
## @api public
## [br]
## @param encoded_state: 编码后的状态。
## [br]
## @return 解码后的状态。
## [br]
## @schema encoded_state: Dictionary[StringName|String, Variant]，编码后的状态字段。
## [br]
## @schema return: Dictionary[StringName|String, Variant]，解码后的状态字段。
func decode_state(encoded_state: Dictionary) -> Dictionary:
	var decoded: Dictionary = {}
	for field_name: String in get_registered_fields():
		var field_key: StringName = StringName(field_name)
		if not _state_has_field(encoded_state, field_key):
			continue

		var serializer: GFNetworkFieldSerializer = get_field_serializer(field_key)
		if serializer != null:
			decoded[field_key] = serializer.deserialize_value(_state_get_field(encoded_state, field_key))

	if include_unregistered_fields:
		for key: Variant in encoded_state.keys():
			if has_field_serializer(StringName(str(key))):
				continue
			decoded[key] = GFVariantData.duplicate_variant(encoded_state[key])
	return decoded


## 编码快照。
## [br]
## @api public
## [br]
## @param snapshot: 原始快照。
## [br]
## @return 快照字典；snapshot 为空时返回空字典。
## [br]
## @schema return: Dictionary，GFNetworkSnapshot.to_dict() 结构，其中 state 已按字段编码器转换。
func encode_snapshot(snapshot: GFNetworkSnapshot) -> Dictionary:
	if snapshot == null:
		return {}

	var data: Dictionary = snapshot.to_dict()
	data["state"] = encode_state(snapshot.state)
	return data


## 解码快照。
## [br]
## @api public
## [br]
## @param data: encode_snapshot() 或 GFNetworkSnapshot.to_dict() 形式的字典。
## [br]
## @return 解码后的快照。
## [br]
## @schema data: Dictionary，encode_snapshot() 或 GFNetworkSnapshot.to_dict() 结构。
func decode_snapshot(data: Dictionary) -> GFNetworkSnapshot:
	var snapshot: GFNetworkSnapshot = GFNetworkSnapshot.new()
	snapshot.from_dict(data)
	snapshot.state = decode_state(snapshot.state)
	return snapshot


## 编码快照 patch。
## [br]
## @api public
## [br]
## @param patch: GFNetworkSnapshot.make_patch_to() 生成的 patch 字典。
## [br]
## @return 编码后的 patch。
## [br]
## @schema patch: Dictionary，路径级 patch 结构。
## [br]
## @schema return: Dictionary，set 值已按已注册的顶层字段编码。
func encode_patch(patch: Dictionary) -> Dictionary:
	return _transform_patch(patch, true)


## 解码快照 patch。
## [br]
## @api public
## [br]
## @param encoded_patch: encode_patch() 生成的 patch 字典。
## [br]
## @return 解码后的 patch。
## [br]
## @schema encoded_patch: Dictionary，编码后的路径级 patch 结构。
## [br]
## @schema return: Dictionary，set 值已按已注册的顶层字段解码。
func decode_patch(encoded_patch: Dictionary) -> Dictionary:
	return _transform_patch(encoded_patch, false)


## 复制 Schema 配置。
## [br]
## @api public
## [br]
## @return 新 Schema。
func duplicate_schema() -> GFNetworkSnapshotSchema:
	var schema: GFNetworkSnapshotSchema = GFNetworkSnapshotSchema.new()
	schema.include_unregistered_fields = include_unregistered_fields
	for key: Variant in field_serializers.keys():
		var serializer: GFNetworkFieldSerializer = _variant_to_field_serializer(field_serializers[key])
		if serializer != null:
			schema.field_serializers[key] = serializer.duplicate_serializer()
	return schema


# --- 私有/辅助方法 ---

## 检查状态字典是否含 StringName 或对应 String 字段。
## [br]
## @api private
## [br]
func _state_has_field(state: Dictionary, field_name: StringName) -> bool:
	return state.has(field_name) or state.has(String(field_name))


## 从状态字典读取 StringName 字段，必要时回退到对应 String 键。
## [br]
## @api private
## [br]
func _state_get_field(state: Dictionary, field_name: StringName) -> Variant:
	if state.has(field_name):
		return state[field_name]
	return GFVariantData.get_option_value(state, String(field_name))


## 按 encode 方向转换 patch 的 set 与 erase 部分。
## [br]
## @api private
## [br]
func _transform_patch(patch: Dictionary, encode: bool) -> Dictionary:
	var result: Dictionary = patch.duplicate(true)
	result["set"] = _transform_patch_set_ops(GFVariantData.get_option_value(patch, "set", []), encode)
	result["erase"] = _filter_patch_erase_ops(GFVariantData.get_option_value(patch, "erase", []))
	return result


## 转换数组或字典形式的 set 操作，并按 Schema 配置筛选路径。
## [br]
## @api private
## [br]
func _transform_patch_set_ops(set_value: Variant, encode: bool) -> Variant:
	if set_value is Dictionary:
		return _transform_patch_set_dictionary(GFVariantData.as_dictionary(set_value), encode)
	if not (set_value is Array):
		return set_value

	var result: Array[Dictionary] = []
	var set_array: Array = GFVariantData.as_array(set_value)
	for op_value: Variant in set_array:
		if not (op_value is Dictionary):
			continue
		var op: Dictionary = GFVariantData.as_dictionary(op_value).duplicate(true)
		var path: Array = _patch_path_from_value(GFVariantData.get_option_value(op, "path", []))
		if not _should_include_patch_path(path):
			continue
		op["path"] = path
		op["value"] = _transform_patch_value_for_path(path, GFVariantData.get_option_value(op, "value"), encode)
		result.append(op)
	return result


## 转换字典形式 set 操作中的各个顶层字段值。
## [br]
## @api private
## [br]
func _transform_patch_set_dictionary(set_values: Dictionary, encode: bool) -> Dictionary:
	var result: Dictionary = {}
	for key: Variant in set_values.keys():
		var path: Array = [key]
		if not _should_include_patch_path(path):
			continue
		result[key] = _transform_patch_value_for_path(path, set_values[key], encode)
	return result


## 按 Schema 配置筛选 PackedStringArray 或 Array 形式的 erase 路径。
## [br]
## @api private
## [br]
func _filter_patch_erase_ops(erase_value: Variant) -> Variant:
	if erase_value is PackedStringArray:
		var erase_keys: PackedStringArray = PackedStringArray()
		for key: String in erase_value:
			if _should_include_patch_path([key]):
				_append_packed_string(erase_keys, key)
		return erase_keys
	if not (erase_value is Array):
		return erase_value

	var erase_paths: Array = []
	var erase_array: Array = GFVariantData.as_array(erase_value)
	for op_value: Variant in erase_array:
		var path: Array = _patch_path_from_value(op_value)
		if _should_include_patch_path(path):
			erase_paths.append(path)
	return erase_paths


## 对已注册的顶层字段调用编码器或解码器，其他路径返回复制后的值。
## [br]
## @api private
## [br]
func _transform_patch_value_for_path(path: Array, value: Variant, encode: bool) -> Variant:
	if path.size() != 1:
		return GFVariantData.duplicate_variant(value)

	var serializer: GFNetworkFieldSerializer = get_field_serializer(StringName(str(path[0])))
	if serializer == null:
		return GFVariantData.duplicate_variant(value)
	if encode:
		return serializer.serialize_value(value)
	return serializer.deserialize_value(value)


## 判断 patch 路径是否符合是否保留未注册字段的配置。
## [br]
## @api private
## [br]
func _should_include_patch_path(path: Array) -> bool:
	if path.is_empty() or include_unregistered_fields:
		return true
	return has_field_serializer(StringName(str(path[0])))


## 将 PackedStringArray、Array 或单个字符串路径值转换为 Array。
## [br]
## @api private
## [br]
func _patch_path_from_value(path_value: Variant) -> Array:
	var result: Array = []
	if path_value is PackedStringArray:
		for key: String in path_value:
			result.append(key)
	elif path_value is Array:
		for key: Variant in path_value:
			result.append(GFVariantData.duplicate_variant(key))
	elif path_value is String or path_value is StringName:
		result.append(path_value)
	return result


## 将 Variant 转为字段编码器类型；类型不符时返回 null。
## [br]
## @api private
## [br]
func _variant_to_field_serializer(value: Variant) -> GFNetworkFieldSerializer:
	if value is GFNetworkFieldSerializer:
		var serializer: GFNetworkFieldSerializer = value
		return serializer
	return null


## 将字符串追加到 PackedStringArray；目标不接受时不再处理。
## [br]
## @api private
## [br]
func _append_packed_string(target: PackedStringArray, value: String) -> void:
	var appended: bool = target.append(value)
	if appended:
		return
