## GFNetworkSnapshot: 通用网络状态快照。
##
## 保存 tick、peer_id、纯字典状态和元数据，可用于同步、回放、插值或项目自定义差量流程。
## [br]
## @api public
## [br]
## @category value_object
## [br]
## @since 3.17.0
class_name GFNetworkSnapshot
extends RefCounted


# --- 常量 ---

const _PATCH_FORMAT: StringName = &"gf_network_snapshot_patch"
const _PATCH_VERSION: int = 1
const _DEFAULT_PATCH_MAX_DEPTH: int = 8
const _MAX_PATCH_OPERATIONS: int = 4096
const _TRANSPORT_VALUE_VALIDATOR = preload("res://addons/gf/extensions/network/runtime/gf_network_transport_value_validator.gd")


# --- 公共变量 ---

## 快照所属 tick。
## [br]
## @api public
var tick: int = 0

## 快照来源 peer；-1 表示未指定。
## [br]
## @api public
var peer_id: int = -1

## 快照状态字典。
## [br]
## @api public
## [br]
## @schema state: Dictionary[StringName|String, Variant]，保存项目自定义同步状态。
var state: Dictionary = {}

## 项目自定义元数据。
## [br]
## @api public
## [br]
## @schema metadata: Dictionary，保存项目自定义快照元数据。
var metadata: Dictionary = {}


# --- Godot 生命周期方法 ---

func _init(
	p_tick: int = 0,
	p_state: Dictionary = {},
	p_peer_id: int = -1,
	p_metadata: Dictionary = {}
) -> void:
	tick = p_tick
	state = p_state.duplicate(true)
	peer_id = p_peer_id
	metadata = p_metadata.duplicate(true)


# --- 公共方法 ---

## 转为字典。
## [br]
## @api public
## [br]
## @return 快照字典。
## [br]
## @schema return: Dictionary，包含 tick、peer_id、state、metadata。
func to_dict() -> Dictionary:
	return {
		"tick": tick,
		"peer_id": peer_id,
		"state": state.duplicate(true),
		"metadata": metadata.duplicate(true),
	}


## 从字典恢复。
## [br]
## @api public
## [br]
## @param data: 快照字典。
## [br]
## @schema data: Dictionary，包含 tick、peer_id、state、metadata。
func from_dict(data: Dictionary) -> void:
	tick = GFVariantData.get_option_int(data, "tick")
	peer_id = GFVariantData.get_option_int(data, "peer_id", -1)
	state = GFVariantData.get_option_dictionary(data, "state")
	metadata = GFVariantData.get_option_dictionary(data, "metadata")


## 复制快照。
## [br]
## @api public
## [br]
## @return 新快照。
func duplicate_snapshot() -> GFNetworkSnapshot:
	return GFNetworkSnapshot.new(tick, state, peer_id, metadata)


## 检查状态字段是否存在。
## [br]
## @api public
## [br]
## @param key: 字段名。
## [br]
## @return 存在返回 true。
func has_value(key: StringName) -> bool:
	return state.has(key) or state.has(String(key))


## 读取状态字段。
## [br]
## @api public
## [br]
## @param key: 字段名。
## [br]
## @param default_value: 缺失时返回的默认值。
## [br]
## @return 字段值。
## [br]
## @schema default_value: Variant，状态字段缺失时返回的默认值。
## [br]
## @schema return: Variant，字段值或 default_value。
func get_value(key: StringName, default_value: Variant = null) -> Variant:
	return GFVariantData.get_option_value(state, key, default_value)


## 设置状态字段。
## [br]
## @api public
## [br]
## @param key: 字段名。
## [br]
## @param value: 字段值。
## [br]
## @schema value: Variant，字段值，会通过 GFVariantData.duplicate_variant() 复制后保存。
func set_value(key: StringName, value: Variant) -> void:
	state[key] = GFVariantData.duplicate_variant(value)


## 删除状态字段。
## [br]
## @api public
## [br]
## @param key: 字段名。
func erase_value(key: StringName) -> void:
	var _erased_name: bool = state.erase(key)
	var _erased_text: bool = state.erase(String(key))


## 生成当前快照到目标快照的浅层差量。
## [br]
## @api public
## [br]
## @param target: 目标快照。
## [br]
## @return 差量字典。
## [br]
## @schema return: Dictionary，成功时包含 ok、from_tick、to_tick、peer_id、set、erase、metadata；失败时包含 ok、error。
func make_delta_to(target: GFNetworkSnapshot) -> Dictionary:
	if target == null:
		return {
			"ok": false,
			"error": "Target snapshot is null.",
		}

	var set_values: Dictionary = {}
	var erase_keys: Array = []
	for key: Variant in target.state.keys():
		if not state.has(key) or state[key] != target.state[key]:
			set_values[key] = GFVariantData.duplicate_variant(target.state[key])
	for key: Variant in state.keys():
		if not target.state.has(key):
			erase_keys.append(GFVariantData.duplicate_variant(key))
	return {
		"ok": true,
		"from_tick": tick,
		"to_tick": target.tick,
		"peer_id": target.peer_id,
		"set": set_values,
		"erase": erase_keys,
		"metadata": target.metadata.duplicate(true),
	}


## 应用浅层差量并返回新快照。
## [br]
## @api public
## [br]
## @param delta: make_delta_to() 生成的差量字典。
## [br]
## @return 新快照。
## [br]
## @schema delta: Dictionary，make_delta_to() 返回的差量结构。
func apply_delta(delta: Dictionary) -> GFNetworkSnapshot:
	var next_snapshot: GFNetworkSnapshot = duplicate_snapshot()
	var set_values: Dictionary = GFVariantData.get_option_dictionary(delta, "set")
	for key: Variant in set_values.keys():
		next_snapshot.state[key] = GFVariantData.duplicate_variant(set_values[key])

	var erase_values: Variant = GFVariantData.get_option_value(delta, "erase", PackedStringArray())
	if erase_values is PackedStringArray:
		for key: String in erase_values:
			var _erased_text: bool = next_snapshot.state.erase(key)
			var _erased_name: bool = next_snapshot.state.erase(StringName(key))
	elif erase_values is Array:
		for key_variant: Variant in erase_values:
			var _erased_variant: bool = next_snapshot.state.erase(key_variant)
			var _erased_variant_name: bool = next_snapshot.state.erase(StringName(str(key_variant)))

	next_snapshot.tick = GFVariantData.get_option_int(delta, "to_tick", next_snapshot.tick)
	next_snapshot.peer_id = GFVariantData.get_option_int(delta, "peer_id", next_snapshot.peer_id)
	next_snapshot.metadata = GFVariantData.get_option_dictionary(
		delta,
		"metadata",
		next_snapshot.metadata
	)
	return next_snapshot


## 生成当前快照到目标快照的路径级 patch。
## [br]
## @api public
## [br]
## @param target: 目标快照。
## [br]
## @param options: 生成选项。
## [br]
## @return patch 字典。
## [br]
## @schema options: Dictionary，可选 recursive: bool = true，max_depth: int = 8。
## [br]
## @schema return: Dictionary，成功时包含 ok、format、version、from_tick、to_tick、peer_id、set、erase、metadata；失败时包含 ok、error。
func make_patch_to(target: GFNetworkSnapshot, options: Dictionary = {}) -> Dictionary:
	if target == null:
		return {
			"ok": false,
			"error": "Target snapshot is null.",
		}

	var set_ops: Array[Dictionary] = []
	var erase_ops: Array[Array] = []
	var recursive: bool = GFVariantData.get_option_bool(options, "recursive", true)
	var max_depth: int = maxi(
		GFVariantData.get_option_int(options, "max_depth", _DEFAULT_PATCH_MAX_DEPTH),
		0
	)
	if recursive:
		_diff_state_dictionaries(state, target.state, [], set_ops, erase_ops, max_depth)
	else:
		_diff_state_dictionaries(state, target.state, [], set_ops, erase_ops, 0)

	return {
		"ok": true,
		"format": _PATCH_FORMAT,
		"version": _PATCH_VERSION,
		"from_tick": tick,
		"to_tick": target.tick,
		"peer_id": target.peer_id,
		"set": set_ops,
		"erase": erase_ops,
		"metadata": target.metadata.duplicate(true),
		"set_count": set_ops.size(),
		"erase_count": erase_ops.size(),
	}


## 应用路径级 patch 并返回新快照。
## [br]
## @api public
## [br]
## @param patch: make_patch_to() 生成的 patch 字典。
## [br]
## @return 新快照。
## [br]
## @schema patch: Dictionary，make_patch_to() 返回的 patch 结构。
func apply_patch(patch: Dictionary) -> GFNetworkSnapshot:
	var next_snapshot: GFNetworkSnapshot = duplicate_snapshot()
	if not _is_valid_patch(patch):
		return next_snapshot
	var erase_values: Variant = GFVariantData.get_option_value(patch, "erase", [])
	if erase_values is Array:
		for erase_op: Variant in erase_values:
			_apply_erase_path(next_snapshot.state, _extract_patch_path(erase_op))

	var set_values: Variant = GFVariantData.get_option_value(patch, "set", [])
	if set_values is Array:
		for set_op: Variant in set_values:
			if not (set_op is Dictionary):
				continue
			var op: Dictionary = GFVariantData.as_dictionary(set_op)
			_apply_set_path(
				next_snapshot.state,
				_extract_patch_path(GFVariantData.get_option_value(op, "path", [])),
				GFVariantData.duplicate_variant(GFVariantData.get_option_value(op, "value"))
			)

	next_snapshot.tick = GFVariantData.get_option_int(patch, "to_tick", next_snapshot.tick)
	next_snapshot.peer_id = GFVariantData.get_option_int(patch, "peer_id", next_snapshot.peer_id)
	next_snapshot.metadata = GFVariantData.get_option_dictionary(
		patch,
		"metadata",
		next_snapshot.metadata
	)
	return next_snapshot


## 打包为网络消息。
## [br]
## @api public
## [br]
## @param message_type: 消息类型。
## [br]
## @param channel_id: 逻辑通道标识。
## [br]
## @return 网络消息。
func make_message(message_type: StringName = &"snapshot", channel_id: StringName = &"") -> GFNetworkMessage:
	return GFNetworkMessage.new(message_type, to_dict(), 0, tick, peer_id, channel_id)


# --- 私有/辅助方法 ---

func _is_valid_patch(patch: Dictionary) -> bool:
	if not (GFVariantData.get_option_value(patch, "ok") is bool):
		return false
	if not GFVariantData.get_option_bool(patch, "ok"):
		return false
	if GFVariantData.get_option_string_name(patch, "format") != _PATCH_FORMAT:
		return false
	if not _is_integer_value(GFVariantData.get_option_value(patch, "version")):
		return false
	if GFVariantData.get_option_int(patch, "version") != _PATCH_VERSION:
		return false
	if not _is_integer_value(GFVariantData.get_option_value(patch, "from_tick")):
		return false
	if GFVariantData.get_option_int(patch, "from_tick") != tick:
		return false
	if not _is_integer_value(GFVariantData.get_option_value(patch, "to_tick")):
		return false
	if patch.has("peer_id") and not _is_integer_value(patch["peer_id"]):
		return false
	if patch.has("metadata") and not (patch["metadata"] is Dictionary):
		return false

	var set_values: Variant = GFVariantData.get_option_value(patch, "set", [])
	var erase_values: Variant = GFVariantData.get_option_value(patch, "erase", [])
	if not (set_values is Array) or not (erase_values is Array):
		return false
	var set_operations: Array = set_values
	var erase_operations: Array = erase_values
	if set_operations.size() + erase_operations.size() > _MAX_PATCH_OPERATIONS:
		return false

	for set_item: Variant in set_operations:
		if not (set_item is Dictionary):
			return false
		var set_operation: Dictionary = set_item
		if not set_operation.has("path") or not set_operation.has("value"):
			return false
		var set_path: Array = _extract_patch_path(set_operation["path"])
		if not _is_valid_patch_path(set_path):
			return false
		var value_report: Dictionary = _TRANSPORT_VALUE_VALIDATOR.validate(set_operation["value"])
		if not GFVariantData.get_option_bool(value_report, "ok"):
			return false

	for erase_item: Variant in erase_operations:
		var erase_path: Array = _extract_patch_path(erase_item)
		if not _is_valid_patch_path(erase_path):
			return false

	var metadata_value: Variant = GFVariantData.get_option_value(patch, "metadata", {})
	var metadata_report: Dictionary = _TRANSPORT_VALUE_VALIDATOR.validate(metadata_value)
	return GFVariantData.get_option_bool(metadata_report, "ok")


func _is_valid_patch_path(path: Array) -> bool:
	if path.is_empty() or path.size() > _DEFAULT_PATCH_MAX_DEPTH:
		return false
	for key: Variant in path:
		if not (key is String) and not (key is StringName) and typeof(key) != TYPE_INT:
			return false
	return true


func _is_integer_value(value: Variant) -> bool:
	if typeof(value) == TYPE_INT:
		return true
	if typeof(value) != TYPE_FLOAT:
		return false
	var number: float = GFVariantData.to_float(value)
	return not is_nan(number) and not is_inf(number) and number == floor(number)


func _diff_state_dictionaries(
	source: Dictionary,
	target: Dictionary,
	path: Array,
	set_ops: Array[Dictionary],
	erase_ops: Array[Array],
	max_depth: int
) -> void:
	for target_key: Variant in target.keys():
		var next_path: Array = _path_with_key(path, target_key)
		if not _dictionary_has_key(source, target_key):
			_append_set_op(set_ops, next_path, target[target_key])
			continue

		var source_value: Variant = source[_dictionary_existing_key(source, target_key)]
		_diff_values(source_value, target[target_key], next_path, set_ops, erase_ops, max_depth)

	for source_key: Variant in source.keys():
		if not _dictionary_has_key(target, source_key):
			_append_erase_op(erase_ops, _path_with_key(path, source_key))


func _diff_values(
	source_value: Variant,
	target_value: Variant,
	path: Array,
	set_ops: Array[Dictionary],
	erase_ops: Array[Array],
	max_depth: int
) -> void:
	if (source_value is Dictionary
		and target_value is Dictionary
		and path.size() < max_depth
	):
		_diff_state_dictionaries(
			GFVariantData.as_dictionary(source_value),
			GFVariantData.as_dictionary(target_value),
			path,
			set_ops,
			erase_ops,
			max_depth
		)
		return

	if source_value != target_value:
		_append_set_op(set_ops, path, target_value)


func _append_set_op(set_ops: Array[Dictionary], path: Array, value: Variant) -> void:
	set_ops.append({
		"path": _duplicate_path(path),
		"value": GFVariantData.duplicate_variant(value),
	})


func _append_erase_op(erase_ops: Array[Array], path: Array) -> void:
	erase_ops.append(_duplicate_path(path))


func _path_with_key(path: Array, key: Variant) -> Array:
	var result: Array = _duplicate_path(path)
	result.append(GFVariantData.duplicate_variant(key))
	return result


func _duplicate_path(path: Array) -> Array:
	var result: Array = []
	for key: Variant in path:
		result.append(GFVariantData.duplicate_variant(key))
	return result


func _extract_patch_path(path_value: Variant) -> Array:
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


func _apply_set_path(root: Dictionary, path: Array, value: Variant) -> void:
	if path.is_empty():
		if value is Dictionary:
			root.clear()
			var value_dictionary: Dictionary = GFVariantData.as_dictionary(value)
			for key: Variant in value_dictionary.keys():
				root[key] = GFVariantData.duplicate_variant(value_dictionary[key])
		return

	var cursor: Dictionary = root
	for index: int in range(path.size() - 1):
		var key: Variant = path[index]
		var existing_key: Variant = _dictionary_existing_key(cursor, key)
		if not cursor.has(existing_key) or not (cursor[existing_key] is Dictionary):
			cursor[existing_key] = {}
		cursor = GFVariantData.as_dictionary(cursor[existing_key])

	var leaf_key: Variant = _dictionary_existing_key(cursor, path[path.size() - 1])
	cursor[leaf_key] = GFVariantData.duplicate_variant(value)


func _apply_erase_path(root: Dictionary, path: Array) -> void:
	if path.is_empty():
		return

	var cursor: Dictionary = root
	for index: int in range(path.size() - 1):
		var key: Variant = _dictionary_existing_key(cursor, path[index])
		if not cursor.has(key) or not (cursor[key] is Dictionary):
			return
		cursor = GFVariantData.as_dictionary(cursor[key])

	var leaf_key: Variant = _dictionary_existing_key(cursor, path[path.size() - 1])
	var _erased: bool = cursor.erase(leaf_key)


func _dictionary_has_key(data: Dictionary, key: Variant) -> bool:
	return data.has(_dictionary_existing_key(data, key))


func _dictionary_existing_key(data: Dictionary, key: Variant) -> Variant:
	if data.has(key):
		return key
	if key is StringName:
		var key_name: StringName = key
		var text_key: String = String(key_name)
		if data.has(text_key):
			return text_key
	if key is String:
		var key_text: String = key
		var name_key: StringName = StringName(key_text)
		if data.has(name_key):
			return name_key
	return key
