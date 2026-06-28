## GFSignalRuntimeProbe: 运行时信号发射追踪器。
##
## 以显式 watch 的方式连接节点信号，并把实际发射记录为只读事件快照。
## 它不修改被观察节点，不解释业务语义，也不应默认用于生产环境全局采样。
## [br]
## @api public
## [br]
## @category runtime_service
## [br]
## @since 3.17.0
class_name GFSignalRuntimeProbe
extends RefCounted


# --- 信号 ---

## 记录到信号发射事件后发出。
## [br]
## @api public
## [br]
## @param event: 发射事件快照。
## [br]
## @schema event: Dictionary，包含 timestamp_msec、process_frame、physics_frame、source_instance_id、source_node_path、signal_name、argument_count、arguments 和 connections。
signal signal_emitted(event: Dictionary)

## 开始监听一个节点信号后发出。
## [br]
## @api public
## [br]
## @param source_path: 信号来源节点路径。
## [br]
## @param signal_name: 信号名称。
signal signal_watch_started(source_path: String, signal_name: StringName)

## 停止监听一个节点信号后发出。
## [br]
## @api public
## [br]
## @param source_path: 信号来源节点路径。
## [br]
## @param signal_name: 信号名称。
signal signal_watch_stopped(source_path: String, signal_name: StringName)


# --- 常量 ---

## 默认保留的最近信号发射事件数量。
## [br]
## @api public
const DEFAULT_MAX_EVENTS: int = 256

const _MAX_SUPPORTED_ARGUMENT_COUNT: int = 16

## 默认单个信号最多追踪的参数数量。
## [br]
## @api public
const DEFAULT_MAX_ARGUMENT_COUNT: int = _MAX_SUPPORTED_ARGUMENT_COUNT

## 默认递归监听节点树深度上限。
## [br]
## @api public
const DEFAULT_MAX_WATCH_TREE_DEPTH: int = 64

## 默认递归监听节点树数量上限。
## [br]
## @api public
const DEFAULT_MAX_WATCH_TREE_NODES: int = 4096

const _INSTANCE_GUARD: Script = preload("res://addons/gf/kernel/core/gf_instance_guard.gd")


# --- 公共变量 ---

## 最多保留的最近事件数量。小于等于 0 表示不保留历史，只发出 signal_emitted。
## [br]
## @api public
var max_events: int = DEFAULT_MAX_EVENTS

## 单个信号最多支持追踪的参数数量。
## [br]
## @api public
var max_argument_count: int = DEFAULT_MAX_ARGUMENT_COUNT


# --- 私有变量 ---

var _watched: Dictionary = {}
var _events: Array[Dictionary] = []


# --- 公共方法 ---

## 监听单个节点的信号。
## [br]
## @api public
## [br]
## @param source: 需要观察的节点。
## [br]
## @param options: 选项，支持 include_signals、exclude_signals、include_internal、max_argument_count 与 connect_flags。
## [br]
## @return 监听报告。
## [br]
## @schema options: Dictionary，支持 include_signals、exclude_signals、include_internal、max_argument_count 和 connect_flags。
## [br]
## @schema return: Dictionary，包含 ok、watched_count、skipped_count 和 errors。
func watch_node(source: Node, options: Dictionary = {}) -> Dictionary:
	if source == null:
		return _make_report(false, 0, 0, ["source_is_null"])

	var include_names: Array[StringName] = GFVariantData.get_option_string_name_array(options, "include_signals")
	var exclude_names: Array[StringName] = GFVariantData.get_option_string_name_array(options, "exclude_signals")
	var include_internal: bool = GFVariantData.get_option_bool(options, "include_internal")
	var limit: int = clampi(GFVariantData.get_option_int(options, "max_argument_count", max_argument_count), 0, _MAX_SUPPORTED_ARGUMENT_COUNT)
	var connect_flags: int = GFVariantData.get_option_int(options, "connect_flags")
	var watched_count: int = 0
	var skipped_count: int = 0
	var errors: Array[String] = []

	for signal_info: Dictionary in source.get_signal_list():
		var signal_name: StringName = GFVariantData.get_option_string_name(signal_info, "name")
		if signal_name == &"":
			skipped_count += 1
			continue
		if not include_internal and String(signal_name).begins_with("_"):
			skipped_count += 1
			continue
		if not include_names.is_empty() and not include_names.has(signal_name):
			skipped_count += 1
			continue
		if exclude_names.has(signal_name):
			skipped_count += 1
			continue

		var argument_count: int = _get_signal_argument_count(signal_info)
		if argument_count > limit:
			skipped_count += 1
			errors.append("too_many_arguments:%s" % String(signal_name))
			continue

		var error: Error = _watch_signal(source, signal_name, argument_count, connect_flags)
		if error == OK:
			watched_count += 1
		elif error == ERR_ALREADY_EXISTS:
			skipped_count += 1
		else:
			skipped_count += 1
			errors.append("%s:%s" % [String(signal_name), error_string(error)])

	return _make_report(errors.is_empty(), watched_count, skipped_count, errors)


## 递归监听节点树。
## [br]
## @api public
## [br]
## @param root: 需要观察的根节点。
## [br]
## @param options: 选项，支持 watch_node() 选项以及 recursive、include_internal_nodes、max_node_depth 与 max_nodes。
## [br]
## @return 监听报告。
## [br]
## @schema options: Dictionary，支持 watch_node() 选项以及 recursive、include_internal_nodes、max_node_depth 和 max_nodes。
## [br]
## @schema return: Dictionary，包含 ok、watched_count、skipped_count 和 errors。
func watch_tree(root: Node, options: Dictionary = {}) -> Dictionary:
	if root == null:
		return _make_report(false, 0, 0, ["root_is_null"])

	var recursive: bool = GFVariantData.get_option_bool(options, "recursive", true)
	var include_internal_nodes: bool = GFVariantData.get_option_bool(options, "include_internal_nodes")
	var max_node_depth: int = maxi(GFVariantData.get_option_int(options, "max_node_depth", DEFAULT_MAX_WATCH_TREE_DEPTH), 0)
	var max_nodes: int = maxi(GFVariantData.get_option_int(options, "max_nodes", DEFAULT_MAX_WATCH_TREE_NODES), 0)
	var nodes: Array[Node] = []
	var tree_scan_state: Dictionary = _make_tree_scan_state()
	_collect_nodes(root, nodes, recursive, include_internal_nodes, 0, max_node_depth, max_nodes, tree_scan_state)

	var total_watched: int = 0
	var total_skipped: int = 0
	var errors: Array[String] = _get_tree_scan_errors(tree_scan_state, max_node_depth, max_nodes)
	for node: Node in nodes:
		var report: Dictionary = watch_node(node, options)
		total_watched += GFVariantData.get_option_int(report, "watched_count")
		total_skipped += GFVariantData.get_option_int(report, "skipped_count")
		for error_variant: Variant in GFVariantData.get_option_array(report, "errors"):
			errors.append(GFVariantData.to_text(error_variant))

	return _make_report(errors.is_empty(), total_watched, total_skipped, errors)


## 停止监听某个节点。
## [br]
## @api public
## [br]
## @param source: 需要停止观察的节点。
## [br]
## @return 断开的信号数量。
func unwatch_node(source: Node) -> int:
	if source == null:
		return 0

	var source_id: int = source.get_instance_id()
	var removed_count: int = 0
	for key: String in _watched.keys().duplicate():
		var entry: Dictionary = _get_watch_entry(key)
		if entry.is_empty() or GFVariantData.get_option_int(entry, "source_id") != source_id:
			continue
		if _disconnect_entry(entry):
			removed_count += 1
		var _erased: bool = _watched.erase(key)
	return removed_count


## 停止所有监听。
## [br]
## @api public
## [br]
## @return 断开的信号数量。
func unwatch_all() -> int:
	var removed_count: int = 0
	for key: String in _watched.keys().duplicate():
		var entry: Dictionary = _get_watch_entry(key)
		if not entry.is_empty() and _disconnect_entry(entry):
			removed_count += 1
		var _erased: bool = _watched.erase(key)
	return removed_count


## 清空最近事件。
## [br]
## @api public
func clear_events() -> void:
	_events.clear()


## 获取最近事件副本。
## [br]
## @api public
## [br]
## @return 事件快照数组。
## [br]
## @schema return: Array[Dictionary]，每个元素包含 timestamp_msec、process_frame、physics_frame、source_instance_id、source_node_path、signal_name、argument_count、arguments 和 connections。
func get_events() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for event: Dictionary in _events:
		result.append(event.duplicate(true))
	return result


## 获取被监听的信号数量。
## [br]
## @api public
## [br]
## @return 当前有效监听数量。
func get_watch_count() -> int:
	_prune_invalid_watches()
	return _watched.size()


## 获取调试快照。
## [br]
## @api public
## [br]
## @return 调试信息字典。
## [br]
## @schema return: Dictionary，包含 watch_count、event_count、max_events、max_argument_count 和 watches。
func get_debug_snapshot() -> Dictionary:
	_prune_invalid_watches()
	return {
		"watch_count": _watched.size(),
		"event_count": _events.size(),
		"max_events": max_events,
		"max_argument_count": max_argument_count,
		"watches": _describe_watches(),
	}


# --- 私有/辅助方法 ---

func _watch_signal(source: Node, signal_name: StringName, argument_count: int, connect_flags: int) -> Error:
	var key: String = _make_watch_key(source.get_instance_id(), signal_name)
	if _watched.has(key):
		return ERR_ALREADY_EXISTS

	var source_path: String = _get_node_path_text(source)
	var callback: Callable = _make_emit_callable(argument_count).bind(source.get_instance_id(), source_path, signal_name)
	if not callback.is_valid():
		return ERR_INVALID_PARAMETER
	if source.is_connected(signal_name, callback):
		return ERR_ALREADY_EXISTS

	var error: Error = source.connect(signal_name, callback, connect_flags)
	if error != OK:
		return error

	_watched[key] = {
		"source_ref": weakref(source),
		"source_id": source.get_instance_id(),
		"source_path": source_path,
		"signal_name": signal_name,
		"argument_count": argument_count,
		"callable": callback,
	}
	signal_watch_started.emit(source_path, signal_name)
	return OK


func _disconnect_entry(entry: Dictionary) -> bool:
	var source_ref: WeakRef = _get_dictionary_weak_ref(entry, "source_ref")
	var source: Node = _get_live_node_from_ref(source_ref)
	var signal_name: StringName = GFVariantData.get_option_string_name(entry, "signal_name")
	var callback: Callable = _get_dictionary_callable(entry, "callable")
	if source == null or signal_name == &"" or not callback.is_valid():
		return false
	if source.is_connected(signal_name, callback):
		source.disconnect(signal_name, callback)
		signal_watch_stopped.emit(GFVariantData.get_option_string(entry, "source_path"), signal_name)
		return true
	return false


func _record_signal(source_id: int, source_path: String, signal_name: StringName, arguments: Array) -> void:
	var source: Node = _get_live_node_from_id(source_id)
	var event: Dictionary = {
		"timestamp_msec": Time.get_ticks_msec(),
		"process_frame": Engine.get_process_frames(),
		"physics_frame": Engine.get_physics_frames(),
		"source_instance_id": source_id,
		"source_node_path": _get_node_path_text(source) if source != null else source_path,
		"signal_name": String(signal_name),
		"argument_count": arguments.size(),
		"arguments": _snapshot_signal_arguments(arguments),
		"connections": _describe_signal_connections(source, signal_name),
	}
	if max_events > 0:
		_events.append(event)
		while _events.size() > max_events:
			_events.pop_front()
	signal_emitted.emit(event.duplicate(true))


func _snapshot_signal_arguments(arguments: Array) -> Array:
	var result: Array = []
	for argument: Variant in arguments:
		result.append(_snapshot_signal_argument(argument, 0))
	return result


func _snapshot_signal_argument(value: Variant, depth: int) -> Variant:
	if depth > 8:
		return {
			"type": "truncated",
		}
	if value is Object:
		var object_value: Object = value
		return _snapshot_object_argument(object_value)
	if value is Array:
		var source_array: Array = value
		var array_result: Array = []
		for item: Variant in source_array:
			array_result.append(_snapshot_signal_argument(item, depth + 1))
		return array_result
	if value is Dictionary:
		var source_dictionary: Dictionary = value
		var dictionary_result: Dictionary = {}
		for raw_key: Variant in source_dictionary.keys():
			var key: Variant = _snapshot_dictionary_key(raw_key, depth + 1)
			dictionary_result[key] = _snapshot_signal_argument(source_dictionary[raw_key], depth + 1)
		return dictionary_result
	if typeof(value) == TYPE_CALLABLE or typeof(value) == TYPE_SIGNAL or typeof(value) == TYPE_RID:
		return {
			"type": type_string(typeof(value)),
			"value": str(value),
		}
	return GFVariantData.duplicate_variant(value, true, true)


func _snapshot_dictionary_key(value: Variant, depth: int) -> Variant:
	var snapshot: Variant = _snapshot_signal_argument(value, depth)
	if snapshot is Array or snapshot is Dictionary:
		return str(snapshot)
	return snapshot


func _snapshot_object_argument(object_value: Object) -> Dictionary:
	var result: Dictionary = {
		"type": "Object",
		"class": object_value.get_class(),
		"instance_id": object_value.get_instance_id(),
		"text": str(object_value),
	}
	if object_value is Resource:
		var resource: Resource = object_value
		result["type"] = "Resource"
		result["resource_path"] = resource.resource_path
	var script_value: Variant = object_value.get_script()
	if script_value is Resource:
		var script_resource: Resource = script_value
		result["script_path"] = script_resource.resource_path
	return result


func _describe_signal_connections(source: Node, signal_name: StringName) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if source == null or signal_name == &"":
		return result

	for connection_info: Dictionary in source.get_signal_connection_list(signal_name):
		var callable: Callable = _get_dictionary_callable(connection_info, "callable")
		var target: Object = callable.get_object() if callable.is_valid() else null
		var method_name: String = ""
		if callable.is_valid():
			method_name = String(callable.get_method())
		result.append({
			"target": str(target),
			"method_name": method_name,
			"flags": GFVariantData.get_option_int(connection_info, "flags"),
		})
	return result


func _describe_watches() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry_variant: Variant in _watched.values():
		var entry: Dictionary = GFVariantData.as_dictionary(entry_variant)
		if entry.is_empty():
			continue
		result.append({
			"source_path": GFVariantData.get_option_string(entry, "source_path"),
			"signal_name": GFVariantData.get_option_string(entry, "signal_name"),
			"argument_count": GFVariantData.get_option_int(entry, "argument_count"),
		})
	return result


func _make_emit_callable(argument_count: int) -> Callable:
	match argument_count:
		0:
			return Callable(self, "_on_signal_emitted_0")
		1:
			return Callable(self, "_on_signal_emitted_1")
		2:
			return Callable(self, "_on_signal_emitted_2")
		3:
			return Callable(self, "_on_signal_emitted_3")
		4:
			return Callable(self, "_on_signal_emitted_4")
		5:
			return Callable(self, "_on_signal_emitted_5")
		6:
			return Callable(self, "_on_signal_emitted_6")
		7:
			return Callable(self, "_on_signal_emitted_7")
		8:
			return Callable(self, "_on_signal_emitted_8")
		9:
			return Callable(self, "_on_signal_emitted_9")
		10:
			return Callable(self, "_on_signal_emitted_10")
		11:
			return Callable(self, "_on_signal_emitted_11")
		12:
			return Callable(self, "_on_signal_emitted_12")
		13:
			return Callable(self, "_on_signal_emitted_13")
		14:
			return Callable(self, "_on_signal_emitted_14")
		15:
			return Callable(self, "_on_signal_emitted_15")
		16:
			return Callable(self, "_on_signal_emitted_16")
		_:
			return Callable()


func _get_signal_argument_count(signal_info: Dictionary) -> int:
	var arguments: Array = GFVariantData.get_option_array(signal_info, "args")
	return arguments.size()


func _collect_nodes(
	root: Node,
	result: Array[Node],
	recursive: bool,
	include_internal_nodes: bool,
	depth: int,
	max_node_depth: int,
	max_nodes: int,
	scan_state: Dictionary
) -> void:
	if not _can_collect_more_nodes(result, max_nodes):
		scan_state["node_limit_reached"] = true
		return

	result.append(root)
	if not recursive:
		return

	var child_count: int = root.get_child_count(include_internal_nodes)
	if max_node_depth > 0 and depth >= max_node_depth:
		if child_count > 0:
			scan_state["depth_limit_reached"] = true
		return

	for child: Node in root.get_children(include_internal_nodes):
		if not _can_collect_more_nodes(result, max_nodes):
			scan_state["node_limit_reached"] = true
			break
		_collect_nodes(child, result, recursive, include_internal_nodes, depth + 1, max_node_depth, max_nodes, scan_state)


func _can_collect_more_nodes(result: Array[Node], max_nodes: int) -> bool:
	return max_nodes <= 0 or result.size() < max_nodes


func _make_tree_scan_state() -> Dictionary:
	return {
		"depth_limit_reached": false,
		"node_limit_reached": false,
	}


func _get_tree_scan_errors(scan_state: Dictionary, max_node_depth: int, max_nodes: int) -> Array[String]:
	var errors: Array[String] = []
	if GFVariantData.get_option_bool(scan_state, "depth_limit_reached"):
		errors.append("max_node_depth_reached:%d" % max_node_depth)
	if GFVariantData.get_option_bool(scan_state, "node_limit_reached"):
		errors.append("max_nodes_reached:%d" % max_nodes)
	return errors


func _prune_invalid_watches() -> void:
	for key: String in _watched.keys().duplicate():
		var entry: Dictionary = _get_watch_entry(key)
		var source_ref: WeakRef = _get_dictionary_weak_ref(entry, "source_ref")
		if _get_live_object_from_ref(source_ref) == null:
			var _erased: bool = _watched.erase(key)


func _get_watch_entry(key: String) -> Dictionary:
	return GFVariantData.get_option_dictionary(_watched, key)


func _get_live_node_from_ref(source_ref: WeakRef) -> Node:
	var result: Variant = _INSTANCE_GUARD.call("_get_live_node_from_ref", source_ref)
	if result is Node:
		var node: Node = result
		return node
	return null


func _get_live_object_from_ref(source_ref: WeakRef) -> Object:
	var result: Variant = _INSTANCE_GUARD.call("_get_live_object_from_ref", source_ref)
	if result is Object:
		var object: Object = result
		return object
	return null


static func _get_dictionary_weak_ref(source: Dictionary, key: Variant) -> WeakRef:
	return _variant_to_weak_ref(GFVariantData.get_option_value(source, key))


static func _get_dictionary_callable(source: Dictionary, key: Variant) -> Callable:
	return _variant_to_callable(GFVariantData.get_option_value(source, key, Callable()))


static func _variant_to_weak_ref(value: Variant) -> WeakRef:
	if value is WeakRef:
		var source_ref: WeakRef = value
		return source_ref
	return null


static func _variant_to_callable(value: Variant) -> Callable:
	if value is Callable:
		var callback: Callable = value
		return callback
	return Callable()


func _get_node_path_text(node: Node) -> String:
	if node == null:
		return ""
	if node.is_inside_tree():
		return str(node.get_path())
	return node.name


func _get_live_node_from_id(instance_id: int) -> Node:
	var result: Variant = _INSTANCE_GUARD.call("_get_live_node_from_id", instance_id)
	if result is Node:
		var node: Node = result
		return node
	return null


func _make_watch_key(source_id: int, signal_name: StringName) -> String:
	return "%d:%s" % [source_id, String(signal_name)]


func _make_report(ok: bool, watched_count: int, skipped_count: int, errors: Array[String]) -> Dictionary:
	return {
		"ok": ok,
		"watched_count": watched_count,
		"skipped_count": skipped_count,
		"errors": errors.duplicate(),
	}


# --- 信号处理函数 ---

func _on_signal_emitted_0(source_id: int, source_path: String, signal_name: StringName) -> void:
	_record_signal(source_id, source_path, signal_name, [])


func _on_signal_emitted_1(arg0: Variant, source_id: int, source_path: String, signal_name: StringName) -> void:
	_record_signal(source_id, source_path, signal_name, [arg0])


func _on_signal_emitted_2(
	arg0: Variant,
	arg1: Variant,
	source_id: int,
	source_path: String,
	signal_name: StringName
) -> void:
	_record_signal(source_id, source_path, signal_name, [arg0, arg1])


func _on_signal_emitted_3(
	arg0: Variant,
	arg1: Variant,
	arg2: Variant,
	source_id: int,
	source_path: String,
	signal_name: StringName
) -> void:
	_record_signal(source_id, source_path, signal_name, [arg0, arg1, arg2])


func _on_signal_emitted_4(
	arg0: Variant,
	arg1: Variant,
	arg2: Variant,
	arg3: Variant,
	source_id: int,
	source_path: String,
	signal_name: StringName
) -> void:
	_record_signal(source_id, source_path, signal_name, [arg0, arg1, arg2, arg3])


func _on_signal_emitted_5(
	arg0: Variant,
	arg1: Variant,
	arg2: Variant,
	arg3: Variant,
	arg4: Variant,
	source_id: int,
	source_path: String,
	signal_name: StringName
) -> void:
	_record_signal(source_id, source_path, signal_name, [arg0, arg1, arg2, arg3, arg4])


func _on_signal_emitted_6(
	arg0: Variant,
	arg1: Variant,
	arg2: Variant,
	arg3: Variant,
	arg4: Variant,
	arg5: Variant,
	source_id: int,
	source_path: String,
	signal_name: StringName
) -> void:
	_record_signal(source_id, source_path, signal_name, [arg0, arg1, arg2, arg3, arg4, arg5])


func _on_signal_emitted_7(
	arg0: Variant,
	arg1: Variant,
	arg2: Variant,
	arg3: Variant,
	arg4: Variant,
	arg5: Variant,
	arg6: Variant,
	source_id: int,
	source_path: String,
	signal_name: StringName
) -> void:
	_record_signal(source_id, source_path, signal_name, [arg0, arg1, arg2, arg3, arg4, arg5, arg6])


func _on_signal_emitted_8(
	arg0: Variant,
	arg1: Variant,
	arg2: Variant,
	arg3: Variant,
	arg4: Variant,
	arg5: Variant,
	arg6: Variant,
	arg7: Variant,
	source_id: int,
	source_path: String,
	signal_name: StringName
) -> void:
	_record_signal(source_id, source_path, signal_name, [arg0, arg1, arg2, arg3, arg4, arg5, arg6, arg7])


func _on_signal_emitted_9(
	arg0: Variant,
	arg1: Variant,
	arg2: Variant,
	arg3: Variant,
	arg4: Variant,
	arg5: Variant,
	arg6: Variant,
	arg7: Variant,
	arg8: Variant,
	source_id: int,
	source_path: String,
	signal_name: StringName
) -> void:
	_record_signal(source_id, source_path, signal_name, [arg0, arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8])


func _on_signal_emitted_10(
	arg0: Variant,
	arg1: Variant,
	arg2: Variant,
	arg3: Variant,
	arg4: Variant,
	arg5: Variant,
	arg6: Variant,
	arg7: Variant,
	arg8: Variant,
	arg9: Variant,
	source_id: int,
	source_path: String,
	signal_name: StringName
) -> void:
	_record_signal(source_id, source_path, signal_name, [
		arg0, arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9,
	])


func _on_signal_emitted_11(
	arg0: Variant,
	arg1: Variant,
	arg2: Variant,
	arg3: Variant,
	arg4: Variant,
	arg5: Variant,
	arg6: Variant,
	arg7: Variant,
	arg8: Variant,
	arg9: Variant,
	arg10: Variant,
	source_id: int,
	source_path: String,
	signal_name: StringName
) -> void:
	_record_signal(source_id, source_path, signal_name, [
		arg0, arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9, arg10,
	])


func _on_signal_emitted_12(
	arg0: Variant,
	arg1: Variant,
	arg2: Variant,
	arg3: Variant,
	arg4: Variant,
	arg5: Variant,
	arg6: Variant,
	arg7: Variant,
	arg8: Variant,
	arg9: Variant,
	arg10: Variant,
	arg11: Variant,
	source_id: int,
	source_path: String,
	signal_name: StringName
) -> void:
	_record_signal(source_id, source_path, signal_name, [
		arg0, arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9, arg10, arg11,
	])


func _on_signal_emitted_13(
	arg0: Variant,
	arg1: Variant,
	arg2: Variant,
	arg3: Variant,
	arg4: Variant,
	arg5: Variant,
	arg6: Variant,
	arg7: Variant,
	arg8: Variant,
	arg9: Variant,
	arg10: Variant,
	arg11: Variant,
	arg12: Variant,
	source_id: int,
	source_path: String,
	signal_name: StringName
) -> void:
	_record_signal(source_id, source_path, signal_name, [
		arg0, arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9, arg10, arg11, arg12,
	])


func _on_signal_emitted_14(
	arg0: Variant,
	arg1: Variant,
	arg2: Variant,
	arg3: Variant,
	arg4: Variant,
	arg5: Variant,
	arg6: Variant,
	arg7: Variant,
	arg8: Variant,
	arg9: Variant,
	arg10: Variant,
	arg11: Variant,
	arg12: Variant,
	arg13: Variant,
	source_id: int,
	source_path: String,
	signal_name: StringName
) -> void:
	_record_signal(source_id, source_path, signal_name, [
		arg0, arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9, arg10, arg11, arg12, arg13,
	])


func _on_signal_emitted_15(
	arg0: Variant,
	arg1: Variant,
	arg2: Variant,
	arg3: Variant,
	arg4: Variant,
	arg5: Variant,
	arg6: Variant,
	arg7: Variant,
	arg8: Variant,
	arg9: Variant,
	arg10: Variant,
	arg11: Variant,
	arg12: Variant,
	arg13: Variant,
	arg14: Variant,
	source_id: int,
	source_path: String,
	signal_name: StringName
) -> void:
	_record_signal(source_id, source_path, signal_name, [
		arg0, arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9, arg10, arg11, arg12, arg13,
		arg14,
	])


func _on_signal_emitted_16(
	arg0: Variant,
	arg1: Variant,
	arg2: Variant,
	arg3: Variant,
	arg4: Variant,
	arg5: Variant,
	arg6: Variant,
	arg7: Variant,
	arg8: Variant,
	arg9: Variant,
	arg10: Variant,
	arg11: Variant,
	arg12: Variant,
	arg13: Variant,
	arg14: Variant,
	arg15: Variant,
	source_id: int,
	source_path: String,
	signal_name: StringName
) -> void:
	_record_signal(source_id, source_path, signal_name, [
		arg0, arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9, arg10, arg11, arg12, arg13,
		arg14, arg15,
	])
