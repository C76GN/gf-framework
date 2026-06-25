## GFReactiveStateStore: 运行时 Dictionary 状态树与路径订阅容器。
##
## 管理一份纯 Variant Dictionary 状态，提供路径读写、批量 dirty 派发、
## 路径订阅和 owner 生命周期清理。它不定义业务字段含义，也不替代
## `GFBindableProperty` 的单值响应式协议。
## [br]
## @api public
## [br]
## @category runtime_handle
## [br]
## @since 5.0.0
class_name GFReactiveStateStore
extends RefCounted


# --- 信号 ---

## 状态变更 flush 后发出。
## [br]
## @api public
## [br]
## @since 5.0.0
## [br]
## @param changes: 本次派发的变更记录。
## [br]
## @param snapshot: 当前状态快照。
## [br]
## @schema changes: Array[Dictionary]，每项包含 kind、path、path_segments、old_value、new_value、old_exists、new_exists、old_type、new_type。
## [br]
## @schema snapshot: Dictionary，当前状态深拷贝。
signal state_changed(changes: Array[Dictionary], snapshot: Dictionary)

## 单条路径变更派发时发出。
## [br]
## @api public
## [br]
## @since 5.0.0
## [br]
## @param path: 变更路径。
## [br]
## @param change: 变更记录。
## [br]
## @schema change: Dictionary，包含 kind、path、path_segments、old_value、new_value、old_exists、new_exists、old_type、new_type。
signal path_changed(path: String, change: Dictionary)


# --- 常量 ---

## 只接收完全相同路径的变更。
## [br]
## @api public
## [br]
## @since 5.0.0
const SUBSCRIBE_EXACT: int = 0

## 接收指定路径及其子路径的变更。
## [br]
## @api public
## [br]
## @since 5.0.0
const SUBSCRIBE_PREFIX: int = 1

## 接收所有路径变更。
## [br]
## @api public
## [br]
## @since 5.0.0
const SUBSCRIBE_ANY: int = 2

const _INSTANCE_GUARD = preload("res://addons/gf/kernel/core/gf_instance_guard.gd")


# --- 私有变量 ---

var _state: Dictionary = {}
var _batch_depth: int = 0
var _dirty_changes: Array[Dictionary] = []
var _dirty_change_indices: Dictionary = {}
var _subscriptions: Array[Dictionary] = []
var _next_subscription_id: int = 1
var _is_flushing: bool = false


# --- Godot 生命周期方法 ---

## 构造函数。
## [br]
## @api public
## [br]
## @since 5.0.0
## [br]
## @param initial_state: 初始状态字典。
## [br]
## @schema initial_state: Dictionary，初始状态会被深拷贝保存。
func _init(initial_state: Dictionary = {}) -> void:
	_state = GFVariantData.to_dictionary(initial_state)


# --- 公共方法 ---

## 将路径归一为路径段数组。
## [br]
## @api public
## [br]
## @since 5.0.0
## [br]
## @param path: String、StringName、NodePath、PackedStringArray 或 Array 路径。
## [br]
## @return 路径段数组。String 路径使用点号分段，Array 路径允许 int 段表示数组索引。
## [br]
## @schema path: Variant，路径表达。
## [br]
## @schema return: Array，路径段数组。
static func normalize_path(path: Variant) -> Array:
	if path == null:
		return []
	if path is PackedStringArray:
		var packed_path: PackedStringArray = path
		var packed_segments: Array = []
		for segment_text: String in packed_path:
			if not segment_text.is_empty():
				packed_segments.append(StringName(segment_text))
		return packed_segments
	if path is Array:
		var path_array: Array = path
		var array_segments: Array = []
		for segment_variant: Variant in path_array:
			if segment_variant is int:
				var segment_index: int = segment_variant
				array_segments.append(segment_index)
			else:
				var segment_name: StringName = GFVariantData.to_string_name(segment_variant)
				if segment_name != &"":
					array_segments.append(segment_name)
		return array_segments
	var text: String = GFVariantData.to_text(path)
	if text.is_empty():
		return []

	var segments: Array = []
	for part: String in text.split(".", false):
		if not part.is_empty():
			segments.append(StringName(part))
	return segments


## 将路径格式化为稳定文本。
## [br]
## @api public
## [br]
## @since 5.0.0
## [br]
## @param path: 路径表达。
## [br]
## @return 路径文本。
## [br]
## @schema path: Variant，路径表达。
static func format_path(path: Variant) -> String:
	return _format_path_segments(normalize_path(path))


## 获取当前状态快照。
## [br]
## @api public
## [br]
## @since 5.0.0
## [br]
## @param copy_value: 为 true 时返回深拷贝。
## [br]
## @return 状态字典。
## [br]
## @schema return: Dictionary，当前状态。
func get_state(copy_value: bool = true) -> Dictionary:
	if copy_value:
		return GFVariantData.to_dictionary(_state)
	return _state


## 替换整份状态，并按 GFVariantData.diff_variant() 生成路径级变更。
## [br]
## @api public
## [br]
## @since 5.0.0
## [br]
## @param new_state: 新状态字典。
## [br]
## @param options: 可选项。支持 copy_values、max_changes。
## [br]
## @return 状态发生变化时返回 true。
## [br]
## @schema new_state: Dictionary，新状态会被深拷贝保存。
## [br]
## @schema options: Dictionary，可选字段 copy_values 默认为 true，max_changes 控制路径级 diff 上限；diff 截断时会发根级 state_replaced 变更。
func set_state(new_state: Dictionary, options: Dictionary = {}) -> bool:
	var next_state: Dictionary = GFVariantData.to_dictionary(new_state)
	var diff_options: Dictionary = {
		"copy_values": GFVariantData.get_option_bool(options, "copy_values", true),
		"max_changes": GFVariantData.get_option_int(options, "max_changes", 1024),
	}
	var diff_report: Dictionary = GFVariantData.diff_variant(_state, next_state, diff_options)
	if not GFVariantData.get_option_bool(diff_report, "changed", false):
		return false

	var previous_state: Dictionary = _state
	_state = next_state
	if GFVariantData.get_option_bool(diff_report, "truncated", false):
		_enqueue_change(_make_change("state_replaced", [], previous_state, next_state, true, true))
	else:
		_enqueue_report_changes(diff_report, [])
	_flush_if_ready()
	return true


## 读取路径值。
## [br]
## @api public
## [br]
## @since 5.0.0
## [br]
## @param path: 路径表达。
## [br]
## @param fallback: 路径不存在时返回的值。
## [br]
## @param copy_value: 为 true 时深拷贝集合结果。
## [br]
## @return 路径值或 fallback。
## [br]
## @schema path: Variant，路径表达。
## [br]
## @schema fallback: Variant，路径不存在时的回退值。
## [br]
## @schema return: Variant，路径值。
func get_value(path: Variant, fallback: Variant = null, copy_value: bool = true) -> Variant:
	var read_result: Dictionary = _read_path(normalize_path(path))
	if not GFVariantData.get_option_bool(read_result, "found", false):
		return GFVariantData.duplicate_variant(fallback) if copy_value else fallback

	var value: Variant = GFVariantData.get_option_value(read_result, "value")
	return GFVariantData.duplicate_variant(value) if copy_value else value


## 检查路径是否存在。
## [br]
## @api public
## [br]
## @since 5.0.0
## [br]
## @param path: 路径表达。
## [br]
## @return 路径存在时返回 true。
## [br]
## @schema path: Variant，路径表达。
func has_value(path: Variant) -> bool:
	return GFVariantData.get_option_bool(_read_path(normalize_path(path)), "found", false)


## 写入路径值。
## [br]
## @api public
## [br]
## @since 5.0.0
## [br]
## @param path: 路径表达。空路径要求 value 为 Dictionary，并替换整份状态。
## [br]
## @param value: 新值。
## [br]
## @return 成功写入且发生变化时返回 true。
## [br]
## @schema path: Variant，路径表达。
## [br]
## @schema value: Variant，要写入的值。
func set_value(path: Variant, value: Variant) -> bool:
	var segments: Array = normalize_path(path)
	if segments.is_empty():
		if value is Dictionary:
			var dictionary_value: Dictionary = value
			return set_state(dictionary_value)
		return false

	var old_result: Dictionary = _read_path(segments)
	var old_exists: bool = GFVariantData.get_option_bool(old_result, "found", false)
	var old_value: Variant = GFVariantData.get_option_value(old_result, "value")
	if old_exists and _variant_values_equal(old_value, value):
		return false

	if not _write_path(segments, GFVariantData.duplicate_variant(value)):
		return false

	_enqueue_change(_make_change(
		"changed" if old_exists else "added",
		segments,
		old_value,
		value,
		old_exists,
		true
	))
	_flush_if_ready()
	return true


## 批量写入多个路径值。
## [br]
## @api public
## [br]
## @since 5.0.0
## [br]
## @param values_by_path: 路径到值的字典。
## [br]
## @return 实际发生变化的路径数量。
## [br]
## @schema values_by_path: Dictionary，键为路径表达，值为要写入的 Variant。
func set_values(values_by_path: Dictionary) -> int:
	begin_batch()
	var changed_count: int = 0
	for path_variant: Variant in values_by_path.keys():
		if set_value(path_variant, values_by_path[path_variant]):
			changed_count += 1
	var _flushed_changes: Array[Dictionary] = end_batch()
	return changed_count


## 删除路径值。
## [br]
## @api public
## [br]
## @since 5.0.0
## [br]
## @param path: 路径表达。
## [br]
## @return 成功删除时返回 true。
## [br]
## @schema path: Variant，路径表达。
func erase_value(path: Variant) -> bool:
	var segments: Array = normalize_path(path)
	if segments.is_empty():
		return false

	var old_result: Dictionary = _read_path(segments)
	if not GFVariantData.get_option_bool(old_result, "found", false):
		return false

	var old_value: Variant = GFVariantData.get_option_value(old_result, "value")
	if not _erase_path(segments):
		return false

	_enqueue_change(_make_change("removed", segments, old_value, null, true, false))
	_flush_if_ready()
	return true


## 进入批量写入模式。
## [br]
## @api public
## [br]
## @since 5.0.0
func begin_batch() -> void:
	_batch_depth += 1


## 结束一层批量写入模式。最外层结束时自动 flush。
## [br]
## @api public
## [br]
## @since 5.0.0
## [br]
## @return 本次 flush 派发的变更。
## [br]
## @schema return: Array[Dictionary]，派发的变更记录。
func end_batch() -> Array[Dictionary]:
	if _batch_depth <= 0:
		return []

	_batch_depth -= 1
	if _batch_depth > 0:
		return []
	return flush()


## 当前是否处于批量写入模式。
## [br]
## @api public
## [br]
## @since 5.0.0
## [br]
## @return 正在批量写入时返回 true。
func is_batching() -> bool:
	return _batch_depth > 0


## 立即派发 dirty queue。flush 期间产生的新 dirty change 会在当前订阅者批次结束后继续派发，
## 不会重入当前订阅者列表。
## [br]
## @api public
## [br]
## @since 5.0.0
## [br]
## @return 本次派发的变更。
## [br]
## @schema return: Array[Dictionary]，派发的变更记录。
func flush() -> Array[Dictionary]:
	if _is_flushing:
		return []

	_prune_invalid_subscriptions()
	if _dirty_changes.is_empty():
		return []

	var dispatched_changes: Array[Dictionary] = []
	_is_flushing = true
	while not _dirty_changes.is_empty():
		var changes: Array[Dictionary] = _copy_changes(_dirty_changes)
		_dirty_changes.clear()
		_dirty_change_indices.clear()
		dispatched_changes.append_array(changes)

		state_changed.emit(changes, get_state())
		for change: Dictionary in changes:
			path_changed.emit(GFVariantData.get_option_string(change, "path"), change)
		_notify_subscribers(changes)

		if _batch_depth > 0:
			break

	_is_flushing = false
	return dispatched_changes


## 获取尚未派发的 dirty changes。
## [br]
## @api public
## [br]
## @since 5.0.0
## [br]
## @return dirty changes 副本。
## [br]
## @schema return: Array[Dictionary]，等待派发的变更记录。
func get_dirty_changes() -> Array[Dictionary]:
	return _copy_changes(_dirty_changes)


## 订阅指定路径变化。
## [br]
## @api public
## [br]
## @since 5.0.0
## [br]
## @param path: 路径表达。空路径配合 SUBSCRIBE_PREFIX 或 SUBSCRIBE_ANY 可观察整棵状态树。
## [br]
## @param callback: 回调签名为 func(change: Dictionary, store: GFReactiveStateStore)。
## [br]
## @param options: 可选项。支持 mode、owner、emit_current。
## [br]
## @return 取消订阅 Callable；callback 无效时返回空 Callable。
## [br]
## @schema path: Variant，路径表达。
## [br]
## @schema options: Dictionary，可选字段：mode 为 SUBSCRIBE_EXACT/SUBSCRIBE_PREFIX/SUBSCRIBE_ANY，owner 为 Object，emit_current 默认为 false。
func subscribe(path: Variant, callback: Callable, options: Dictionary = {}) -> Callable:
	if not callback.is_valid():
		push_error("[GFReactiveStateStore] subscribe 失败：callback 无效。")
		return Callable()

	var subscription_owner: Object = _get_options_owner(options)
	var subscription_id: int = _next_subscription_id
	_next_subscription_id += 1
	var segments: Array = normalize_path(path)
	var mode: int = _normalize_subscribe_mode(GFVariantData.get_option_int(options, "mode", SUBSCRIBE_EXACT))
	var exit_callable: Callable = Callable()
	if subscription_owner is Node:
		var owner_node: Node = subscription_owner
		exit_callable = Callable(self, "_on_subscription_owner_tree_exited").bind(subscription_id)
		if not owner_node.tree_exited.is_connected(exit_callable):
			var _connect_result: Variant = owner_node.tree_exited.connect(
				exit_callable,
				CONNECT_ONE_SHOT as Object.ConnectFlags
			)

	_subscriptions.append({
		"subscription_id": subscription_id,
		"path": _format_path_segments(segments),
		"path_segments": segments,
		"mode": mode,
		"callback": callback,
		"owner_ref": weakref(subscription_owner) if subscription_owner != null else null,
		"exit_callable": exit_callable,
	})

	if GFVariantData.get_option_bool(options, "emit_current", false):
		var current_change: Dictionary = _make_current_change(segments)
		callback.call(current_change, self)

	return _make_unsubscribe_callable(subscription_id)


## 按订阅 ID 取消订阅。
## [br]
## @api public
## [br]
## @since 5.0.0
## [br]
## @param subscription_id: 订阅 ID。
## [br]
## @return 找到并移除订阅时返回 true。
func unsubscribe(subscription_id: int) -> bool:
	var index: int = _find_subscription_index(subscription_id)
	if index == -1:
		return false

	_disconnect_subscription_owner_signal(_subscriptions[index])
	_subscriptions.remove_at(index)
	return true


## 清理订阅。owner 为空时清理全部订阅。
## [br]
## @api public
## [br]
## @since 5.0.0
## [br]
## @param owner: 可选订阅 owner。
func clear_subscriptions(owner: Object = null) -> void:
	if owner == null:
		for subscription: Dictionary in _subscriptions:
			_disconnect_subscription_owner_signal(subscription)
		_subscriptions.clear()
		return

	for index: int in range(_subscriptions.size() - 1, -1, -1):
		if _get_subscription_owner(_subscriptions[index]) == owner:
			_disconnect_subscription_owner_signal(_subscriptions[index])
			_subscriptions.remove_at(index)


## 获取有效订阅数量。
## [br]
## @api public
## [br]
## @since 5.0.0
## [br]
## @return 有效订阅数量。
func get_subscription_count() -> int:
	_prune_invalid_subscriptions()
	return _subscriptions.size()


## 释放 store 持有的订阅和 dirty queue。
## [br]
## @api public
## [br]
## @since 5.0.0
func dispose() -> void:
	clear_subscriptions()
	_dirty_changes.clear()
	_dirty_change_indices.clear()
	_batch_depth = 0
	_is_flushing = false


# --- 私有/辅助方法 ---

static func _format_path_segments(segments: Array) -> String:
	var path_text: String = ""
	for segment: Variant in segments:
		if segment is int:
			var segment_index: int = segment
			path_text += "[%d]" % segment_index
			continue

		var key_text: String = GFVariantData.to_text(segment)
		if path_text.is_empty():
			path_text = key_text
		else:
			path_text += "." + key_text
	return path_text


static func _variant_values_equal(left: Variant, right: Variant) -> bool:
	return GFVariantData.values_equal(left, right)


func _read_path(segments: Array) -> Dictionary:
	if segments.is_empty():
		return {
			"found": true,
			"value": _state,
		}

	var current: Variant = _state
	for segment: Variant in segments:
		if current is Dictionary:
			var dictionary: Dictionary = current
			var key_result: Dictionary = _find_dictionary_key(dictionary, segment)
			if not GFVariantData.get_option_bool(key_result, "found", false):
				return { "found": false }
			current = dictionary[GFVariantData.get_option_value(key_result, "key")]
			continue

		if current is Array and segment is int:
			var array: Array = current
			var index: int = segment
			if index < 0 or index >= array.size():
				return { "found": false }
			current = array[index]
			continue

		return { "found": false }

	return {
		"found": true,
		"value": current,
	}


func _write_path(segments: Array, new_value: Variant) -> bool:
	var current: Variant = _state
	for index: int in range(segments.size() - 1):
		var segment: Variant = segments[index]
		var next_segment: Variant = segments[index + 1]
		if current is Dictionary:
			var dictionary: Dictionary = current
			var key_result: Dictionary = _find_dictionary_key(dictionary, segment)
			var key: Variant = GFVariantData.get_option_value(key_result, "key", segment)
			if not GFVariantData.get_option_bool(key_result, "found", false):
				if next_segment is int:
					return false
				dictionary[key] = {}
			elif not _is_path_container(dictionary[key]):
				if next_segment is int:
					return false
				dictionary[key] = {}
			current = dictionary[key]
			continue

		if current is Array and segment is int:
			var array: Array = current
			var segment_index: int = segment
			if segment_index < 0 or segment_index >= array.size():
				return false
			if not _is_path_container(array[segment_index]):
				if next_segment is int:
					return false
				array[segment_index] = {}
			current = array[segment_index]
			continue

		return false

	var leaf: Variant = segments[segments.size() - 1]
	if current is Dictionary:
		var leaf_dictionary: Dictionary = current
		var leaf_result: Dictionary = _find_dictionary_key(leaf_dictionary, leaf)
		var leaf_key: Variant = GFVariantData.get_option_value(leaf_result, "key", leaf)
		leaf_dictionary[leaf_key] = new_value
		return true
	if current is Array and leaf is int:
		var leaf_array: Array = current
		var leaf_index: int = leaf
		if leaf_index < 0 or leaf_index >= leaf_array.size():
			return false
		leaf_array[leaf_index] = new_value
		return true
	return false


func _erase_path(segments: Array) -> bool:
	var parent_segments: Array = segments.slice(0, segments.size() - 1)
	var parent_result: Dictionary = _read_path(parent_segments)
	if not GFVariantData.get_option_bool(parent_result, "found", false):
		return false

	var parent: Variant = GFVariantData.get_option_value(parent_result, "value")
	var leaf: Variant = segments[segments.size() - 1]
	if parent is Dictionary:
		var dictionary: Dictionary = parent
		var key_result: Dictionary = _find_dictionary_key(dictionary, leaf)
		if not GFVariantData.get_option_bool(key_result, "found", false):
			return false
		return dictionary.erase(GFVariantData.get_option_value(key_result, "key"))
	if parent is Array and leaf is int:
		var array: Array = parent
		var leaf_index: int = leaf
		if leaf_index < 0 or leaf_index >= array.size():
			return false
		array.remove_at(leaf_index)
		return true
	return false


func _find_dictionary_key(dictionary: Dictionary, key: Variant) -> Dictionary:
	if dictionary.has(key):
		return {
			"found": true,
			"key": key,
		}

	if not (key is String or key is StringName):
		return {
			"found": false,
			"key": key,
		}

	var key_text: String = GFVariantData.to_text(key)
	for candidate_key: Variant in dictionary.keys():
		if not (candidate_key is String or candidate_key is StringName):
			continue
		if GFVariantData.to_text(candidate_key) == key_text:
			return {
				"found": true,
				"key": candidate_key,
			}

	return {
		"found": false,
		"key": key,
	}


func _is_path_container(value: Variant) -> bool:
	return value is Dictionary or value is Array


func _make_change(
	kind: String,
	segments: Array,
	old_value: Variant,
	new_value: Variant,
	old_exists: bool,
	new_exists: bool
) -> Dictionary:
	return {
		"kind": kind,
		"path": _format_path_segments(segments),
		"path_segments": GFVariantData.duplicate_variant(segments),
		"old_value": GFVariantData.duplicate_variant(old_value),
		"new_value": GFVariantData.duplicate_variant(new_value),
		"old_exists": old_exists,
		"new_exists": new_exists,
		"old_type": type_string(typeof(old_value)),
		"new_type": type_string(typeof(new_value)),
	}


func _make_current_change(segments: Array) -> Dictionary:
	var read_result: Dictionary = _read_path(segments)
	var exists: bool = GFVariantData.get_option_bool(read_result, "found", false)
	var current_value: Variant = GFVariantData.get_option_value(read_result, "value")
	return _make_change("current", segments, current_value, current_value, exists, exists)


func _enqueue_report_changes(diff_report: Dictionary, prefix_segments: Array) -> void:
	var changes: Array = GFVariantData.get_option_array(diff_report, "changes")
	for change_variant: Variant in changes:
		var change: Dictionary = GFVariantData.as_dictionary(change_variant)
		var segments: Array = prefix_segments.duplicate()
		segments.append_array(GFVariantData.get_option_array(change, "path_segments"))
		_enqueue_change(_make_change(
			GFVariantData.get_option_string(change, "kind", "changed"),
			segments,
			GFVariantData.get_option_value(change, "old_value"),
			GFVariantData.get_option_value(change, "new_value"),
			GFVariantData.get_option_string(change, "kind") != "added",
			GFVariantData.get_option_string(change, "kind") != "removed"
		))


func _enqueue_change(change: Dictionary) -> void:
	var path: String = GFVariantData.get_option_string(change, "path")
	if _dirty_change_indices.has(path):
		var change_index: int = GFVariantData.to_int(_dirty_change_indices[path])
		var existing: Dictionary = _dirty_changes[change_index]
		existing["new_value"] = GFVariantData.duplicate_variant(GFVariantData.get_option_value(change, "new_value"))
		existing["new_exists"] = GFVariantData.get_option_bool(change, "new_exists")
		existing["new_type"] = GFVariantData.get_option_string(change, "new_type")
		existing["kind"] = _merge_change_kind(
			GFVariantData.get_option_string(existing, "kind"),
			GFVariantData.get_option_string(change, "kind")
		)
		if _change_has_no_net_effect(existing):
			_remove_dirty_change_at(change_index)
		return

	_dirty_change_indices[path] = _dirty_changes.size()
	_dirty_changes.append(GFVariantData.to_dictionary(change))


func _merge_change_kind(previous_kind: String, next_kind: String) -> String:
	if previous_kind == "added":
		return "added"
	if previous_kind == "removed" and next_kind == "added":
		return "changed"
	return next_kind


func _change_has_no_net_effect(change: Dictionary) -> bool:
	var old_exists: bool = GFVariantData.get_option_bool(change, "old_exists")
	var new_exists: bool = GFVariantData.get_option_bool(change, "new_exists")
	if old_exists != new_exists:
		return false
	return _variant_values_equal(
		GFVariantData.get_option_value(change, "old_value"),
		GFVariantData.get_option_value(change, "new_value")
	)


func _remove_dirty_change_at(change_index: int) -> void:
	_dirty_changes.remove_at(change_index)
	_dirty_change_indices.clear()
	for index: int in range(_dirty_changes.size()):
		_dirty_change_indices[GFVariantData.get_option_string(_dirty_changes[index], "path")] = index


func _flush_if_ready() -> void:
	if _batch_depth > 0 or _is_flushing:
		return
	var _changes: Array[Dictionary] = flush()


func _copy_changes(changes: Array[Dictionary]) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for change: Dictionary in changes:
		result.append(GFVariantData.to_dictionary(change))
	return result


func _notify_subscribers(changes: Array[Dictionary]) -> void:
	var subscriptions_snapshot: Array = _subscriptions.duplicate()
	for subscription_variant: Variant in subscriptions_snapshot:
		var subscription: Dictionary = GFVariantData.as_dictionary(subscription_variant)
		var subscription_id: int = GFVariantData.get_option_int(subscription, "subscription_id", -1)
		if _find_subscription_index(subscription_id) == -1:
			continue
		var callback: Callable = _get_subscription_callback(subscription)
		if not callback.is_valid():
			var _invalid_callback_unsubscribed: bool = unsubscribe(subscription_id)
			continue
		for change: Dictionary in changes:
			if _find_subscription_index(subscription_id) == -1:
				break
			if _subscription_matches_change(subscription, change):
				callback.call(change, self)


func _subscription_matches_change(subscription: Dictionary, change: Dictionary) -> bool:
	if (
		GFVariantData.get_option_string(change, "kind") == "state_replaced"
		and GFVariantData.get_option_array(change, "path_segments").is_empty()
	):
		return true

	var mode: int = GFVariantData.get_option_int(subscription, "mode", SUBSCRIBE_EXACT)
	if mode == SUBSCRIBE_ANY:
		return true

	var subscription_segments: Array = GFVariantData.get_option_array(subscription, "path_segments")
	var change_segments: Array = GFVariantData.get_option_array(change, "path_segments")
	if mode == SUBSCRIBE_PREFIX:
		return _segments_are_prefix(subscription_segments, change_segments)
	return _segments_equal(subscription_segments, change_segments)


func _segments_are_prefix(prefix_segments: Array, segments: Array) -> bool:
	if prefix_segments.size() > segments.size():
		return false
	for index: int in range(prefix_segments.size()):
		if not _path_segments_equal(prefix_segments[index], segments[index]):
			return false
	return true


func _segments_equal(left: Array, right: Array) -> bool:
	if left.size() != right.size():
		return false
	return _segments_are_prefix(left, right)


func _path_segments_equal(left: Variant, right: Variant) -> bool:
	if left is int or right is int:
		return left == right
	return GFVariantData.to_text(left) == GFVariantData.to_text(right)


func _normalize_subscribe_mode(mode: int) -> int:
	if mode == SUBSCRIBE_PREFIX or mode == SUBSCRIBE_ANY:
		return mode
	return SUBSCRIBE_EXACT


func _get_options_owner(options: Dictionary) -> Object:
	var owner_value: Variant = GFVariantData.get_option_value(options, "owner")
	if owner_value is Object and is_instance_valid(owner_value):
		var subscription_owner: Object = owner_value
		return subscription_owner
	return null


func _make_unsubscribe_callable(subscription_id: int) -> Callable:
	var store_ref: WeakRef = weakref(self)
	return func() -> void:
		var raw_store: Variant = store_ref.get_ref()
		if not raw_store is GFReactiveStateStore:
			return
		var store: GFReactiveStateStore = raw_store
		var _unsubscribe_result: bool = store.unsubscribe(subscription_id)


func _find_subscription_index(subscription_id: int) -> int:
	for index: int in range(_subscriptions.size()):
		if GFVariantData.get_option_int(_subscriptions[index], "subscription_id", -1) == subscription_id:
			return index
	return -1


func _get_subscription_callback(subscription: Dictionary) -> Callable:
	var callback_value: Variant = GFVariantData.get_option_value(subscription, "callback", Callable())
	if callback_value is Callable:
		var callback: Callable = callback_value
		return callback
	return Callable()


func _get_subscription_owner(subscription: Dictionary) -> Object:
	var owner_ref_value: Variant = GFVariantData.get_option_value(subscription, "owner_ref")
	if not owner_ref_value is WeakRef:
		return null
	var owner_ref: WeakRef = owner_ref_value
	return _INSTANCE_GUARD._get_live_object_from_ref(owner_ref)


func _disconnect_subscription_owner_signal(subscription: Dictionary) -> void:
	var subscription_owner: Object = _get_subscription_owner(subscription)
	if not subscription_owner is Node:
		return
	var owner_node: Node = subscription_owner
	var exit_callable: Callable = _get_subscription_exit_callable(subscription)
	if exit_callable.is_valid() and owner_node.tree_exited.is_connected(exit_callable):
		owner_node.tree_exited.disconnect(exit_callable)


func _get_subscription_exit_callable(subscription: Dictionary) -> Callable:
	var callable_value: Variant = GFVariantData.get_option_value(subscription, "exit_callable", Callable())
	if callable_value is Callable:
		var callback: Callable = callable_value
		return callback
	return Callable()


func _prune_invalid_subscriptions() -> void:
	for index: int in range(_subscriptions.size() - 1, -1, -1):
		var subscription: Dictionary = _subscriptions[index]
		var callback: Callable = _get_subscription_callback(subscription)
		var has_owner: bool = GFVariantData.get_option_value(subscription, "owner_ref") is WeakRef
		if not callback.is_valid() or (has_owner and _get_subscription_owner(subscription) == null):
			_disconnect_subscription_owner_signal(subscription)
			_subscriptions.remove_at(index)


func _on_subscription_owner_tree_exited(subscription_id: int) -> void:
	var _unsubscribe_result: bool = unsubscribe(subscription_id)
