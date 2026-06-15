@tool

## GFSceneSignalAudit: 开发期场景信号连接审计工具。
##
## 扫描 PackedScene 中由编辑器保存的信号连接，报告缺失节点、缺失信号、
## 缺失方法和可选的参数数量不匹配。该工具只返回结构化报告，不修改场景，
## 也不参与运行时 GFArchitecture 生命周期。
## [br]
## @api public
## [br]
## @category editor_api
## [br]
## @since 3.17.0
## [br]
## @layer kernel/editor
class_name GFSceneSignalAudit
extends RefCounted


# --- 枚举 ---

## 场景信号连接审计问题类型。
## [br]
## @api public
enum IssueType {
	## 场景资源加载失败。
	SCENE_LOAD_FAILED,
	## 无法读取场景保存的连接状态。
	SCENE_STATE_UNAVAILABLE,
	## 场景实例化失败。
	SCENE_INSTANTIATION_FAILED,
	## 连接源节点缺失。
	MISSING_SOURCE,
	## 连接目标节点缺失。
	MISSING_TARGET,
	## 连接源信号缺失。
	MISSING_SIGNAL,
	## 连接目标方法缺失。
	MISSING_METHOD,
	## 信号参数数量与目标方法不匹配。
	PARAMETER_COUNT_MISMATCH,
}


# --- 常量 ---

## 默认最大目录扫描深度。
## [br]
## @api public
const DEFAULT_MAX_SCAN_DEPTH: int = 32

## 默认最大扫描场景路径数量。
## [br]
## @api public
const DEFAULT_MAX_SCENE_PATHS: int = 10000

## 默认最大运行时信号图节点深度。
## [br]
## @api public
const DEFAULT_MAX_SIGNAL_GRAPH_DEPTH: int = 64

## 默认最大运行时信号图节点数量。
## [br]
## @api public
const DEFAULT_MAX_SIGNAL_GRAPH_NODES: int = 10000
const _GF_VARIANT_ACCESS_SCRIPT = preload("res://addons/gf/kernel/core/gf_variant_access.gd")


# --- 公共方法 ---

## 审计指定目录下的场景文件。
## [br]
## @api public
## [br]
## @param root_path: 需要扫描的目录，通常为 `res://`。
## [br]
## @param options: 审计选项，支持 `include_hidden`、`respect_gdignore`、`check_parameter_count`、`max_scan_depth` 与 `max_scene_paths`。
## [br]
## @schema options: Dictionary with include_hidden, respect_gdignore, check_parameter_count, max_scan_depth, and max_scene_paths.
## [br]
## @return 审计汇总报告。
## [br]
## @schema return: Dictionary containing ok, root_path, scene_count, issue_count, scanned_paths, and issues.
static func audit_directory(root_path: String = "res://", options: Dictionary = {}) -> Dictionary:
	var scene_paths: PackedStringArray = collect_scene_paths(root_path, options)
	var report: Dictionary = audit_scene_paths(scene_paths, options)
	report["root_path"] = root_path
	return report


## 审计一组场景路径并返回汇总报告。
## [br]
## @api public
## [br]
## @param scene_paths: 需要审计的 PackedScene 路径列表。
## [br]
## @param options: 审计选项，支持 `check_parameter_count`。
## [br]
## @schema options: Dictionary with optional check_parameter_count.
## [br]
## @return 审计汇总报告。
## [br]
## @schema return: Dictionary containing ok, scene_count, issue_count, scanned_paths, and issues.
static func audit_scene_paths(scene_paths: PackedStringArray, options: Dictionary = {}) -> Dictionary:
	var issues: Array[Dictionary] = []
	var scanned_paths: PackedStringArray = PackedStringArray()
	for scene_path: String in scene_paths:
		_append_packed_string(scanned_paths, scene_path)
		issues.append_array(audit_scene(scene_path, options))

	return {
		"ok": issues.is_empty(),
		"scene_count": scanned_paths.size(),
		"issue_count": issues.size(),
		"scanned_paths": scanned_paths,
		"issues": issues,
	}


## 审计单个 PackedScene 的编辑器信号连接。
## [br]
## @api public
## [br]
## @param scene_path: 需要审计的 PackedScene 路径。
## [br]
## @param options: 审计选项，支持 `check_parameter_count`。
## [br]
## @schema options: Dictionary with optional check_parameter_count.
## [br]
## @return 场景连接问题列表。
## [br]
## @schema return: Array of Dictionary scene signal audit issues.
static func audit_scene(scene_path: String, options: Dictionary = {}) -> Array[Dictionary]:
	var packed_scene: PackedScene = _variant_to_packed_scene(load(scene_path))
	if packed_scene == null:
		return [_make_scene_issue(
			IssueType.SCENE_LOAD_FAILED,
			scene_path,
			"无法加载场景资源。"
		)]

	var state: SceneState = packed_scene.get_state()
	if state == null:
		return [_make_scene_issue(
			IssueType.SCENE_STATE_UNAVAILABLE,
			scene_path,
			"无法读取场景状态。"
		)]

	if state.get_connection_count() == 0:
		return []

	var root: Node = _variant_to_node(packed_scene.instantiate(PackedScene.GEN_EDIT_STATE_DISABLED))
	if root == null:
		return [_make_scene_issue(
			IssueType.SCENE_INSTANTIATION_FAILED,
			scene_path,
			"无法实例化场景用于检查连接目标。"
		)]

	var issues: Array[Dictionary] = []
	var check_parameter_count: bool = _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(options, "check_parameter_count", true)
	for connection_index: int in range(state.get_connection_count()):
		var source_path: NodePath = state.get_connection_source(connection_index)
		var target_path: NodePath = state.get_connection_target(connection_index)
		var signal_name: StringName = state.get_connection_signal(connection_index)
		var method_name: StringName = state.get_connection_method(connection_index)
		var source_node: Node = _get_node_or_root(root, source_path)
		var target_node: Node = _get_node_or_root(root, target_path)

		if source_node == null:
			issues.append(_make_connection_issue(
				IssueType.MISSING_SOURCE,
				scene_path,
				connection_index,
				source_path,
				target_path,
				signal_name,
				method_name,
				"连接源节点不存在。"
			))
			continue

		if target_node == null:
			issues.append(_make_connection_issue(
				IssueType.MISSING_TARGET,
				scene_path,
				connection_index,
				source_path,
				target_path,
				signal_name,
				method_name,
				"连接目标节点不存在。"
			))
			continue

		if not source_node.has_signal(signal_name):
			issues.append(_make_connection_issue(
				IssueType.MISSING_SIGNAL,
				scene_path,
				connection_index,
				source_path,
				target_path,
				signal_name,
				method_name,
				"连接源节点没有该信号。"
			))
			continue

		if not target_node.has_method(method_name):
			issues.append(_make_connection_issue(
				IssueType.MISSING_METHOD,
				scene_path,
				connection_index,
				source_path,
				target_path,
				signal_name,
				method_name,
				"连接目标节点没有该方法。"
			))
			continue

		if check_parameter_count:
			var mismatch_issue: Dictionary = _build_parameter_count_issue(
				scene_path,
				connection_index,
				state,
				source_node,
				target_node
			)
			if not mismatch_issue.is_empty():
				issues.append(mismatch_issue)

	root.free()
	return issues


## 收集目录下可审计的 `.tscn` 场景路径。
## [br]
## @api public
## [br]
## @param root_path: 需要扫描的目录。
## [br]
## @param options: 收集选项，支持 `include_hidden`、`respect_gdignore`、`max_scan_depth` 与 `max_scene_paths`。
## [br]
## @schema options: Dictionary with include_hidden, respect_gdignore, max_scan_depth, and max_scene_paths.
## [br]
## @return 场景路径列表。
static func collect_scene_paths(root_path: String = "res://", options: Dictionary = {}) -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	var include_hidden: bool = _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(options, "include_hidden", false)
	var respect_gdignore: bool = _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(options, "respect_gdignore", true)
	var max_scan_depth: int = maxi(_GF_VARIANT_ACCESS_SCRIPT.get_option_int(options, "max_scan_depth", DEFAULT_MAX_SCAN_DEPTH), 0)
	var max_scene_paths: int = maxi(_GF_VARIANT_ACCESS_SCRIPT.get_option_int(options, "max_scene_paths", DEFAULT_MAX_SCENE_PATHS), 0)
	var scan_state: Dictionary = _make_scan_state()
	_collect_scene_paths_recursive(
		root_path,
		result,
		include_hidden,
		respect_gdignore,
		0,
		max_scan_depth,
		max_scene_paths,
		scan_state
	)
	result.sort()
	return result


## 构建运行中节点树的信号连接图快照。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @param root: 需要扫描的根节点。
## [br]
## @param options: 选项，支持 `include_internal`、`persistent_only`、`include_empty_signals`、`include_external_targets`、`participating_nodes_only`、`max_node_depth` 与 `max_nodes`。
## [br]
## @schema options: Dictionary with include_internal, persistent_only, include_empty_signals, include_external_targets, participating_nodes_only, max_node_depth, and max_nodes.
## [br]
## @return 信号连接图报告。
## [br]
## @schema return: Dictionary containing ok, root_path, node_count, signal_count, connection_count, nodes, signals, connections, and truncated.
static func build_signal_graph(root: Node, options: Dictionary = {}) -> Dictionary:
	if root == null:
		return {
			"ok": false,
			"root_path": "",
			"node_count": 0,
			"signal_count": 0,
			"connection_count": 0,
			"nodes": [],
			"signals": [],
			"connections": [],
			"truncated": false,
			"message": "root 为空。",
		}

	var include_internal: bool = _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(options, "include_internal", false)
	var persistent_only: bool = _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(options, "persistent_only", false)
	var include_empty_signals: bool = _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(options, "include_empty_signals", false)
	var include_external_targets: bool = _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(options, "include_external_targets", true)
	var participating_nodes_only: bool = _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(options, "participating_nodes_only", false)
	var max_node_depth: int = maxi(_GF_VARIANT_ACCESS_SCRIPT.get_option_int(options, "max_node_depth", DEFAULT_MAX_SIGNAL_GRAPH_DEPTH), 0)
	var max_nodes: int = maxi(_GF_VARIANT_ACCESS_SCRIPT.get_option_int(options, "max_nodes", DEFAULT_MAX_SIGNAL_GRAPH_NODES), 0)
	var nodes: Array[Node] = []
	var scan_state: Dictionary = _make_signal_graph_scan_state()
	_collect_signal_graph_nodes(root, nodes, include_internal, 0, max_node_depth, max_nodes, scan_state)

	var node_entries: Array[Dictionary] = []
	var candidate_node_entries: Array[Dictionary] = []
	var participating_node_paths: Dictionary = {}
	var signal_entries: Array[Dictionary] = []
	var connection_entries: Array[Dictionary] = []
	for node: Node in nodes:
		var node_entry: Dictionary = _make_runtime_node_entry(root, node)
		candidate_node_entries.append(node_entry)
		for signal_info: Dictionary in node.get_signal_list():
			var signal_name: StringName = _GF_VARIANT_ACCESS_SCRIPT.get_option_string_name(signal_info, "name")
			if signal_name == &"":
				continue

			var raw_connections: Array = node.get_signal_connection_list(signal_name)
			var connections: Array[Dictionary] = []
			for connection_info: Dictionary in raw_connections:
				if persistent_only and (_GF_VARIANT_ACCESS_SCRIPT.get_option_int(connection_info, "flags") & CONNECT_PERSIST) == 0:
					continue
				if not include_external_targets and _is_external_connection(root, connection_info):
					continue
				connections.append(connection_info)

			if include_empty_signals or not connections.is_empty():
				signal_entries.append({
					"node_path": _GF_VARIANT_ACCESS_SCRIPT.get_option_string(node_entry, "node_path"),
					"signal_name": String(signal_name),
					"argument_count": _get_signal_argument_count(node, signal_name),
					"connection_count": connections.size(),
				})
				if participating_nodes_only:
					participating_node_paths[_GF_VARIANT_ACCESS_SCRIPT.get_option_string(node_entry, "node_path")] = true

			for connection_info: Dictionary in connections:
				var connection_entry: Dictionary = _make_runtime_connection_entry(root, node, signal_name, connection_info)
				connection_entries.append(connection_entry)
				if participating_nodes_only:
					participating_node_paths[_GF_VARIANT_ACCESS_SCRIPT.get_option_string(connection_entry, "source_node_path")] = true
					var target_path: String = _GF_VARIANT_ACCESS_SCRIPT.get_option_string(connection_entry, "target_node_path")
					if not target_path.is_empty():
						participating_node_paths[target_path] = true

	if participating_nodes_only:
		for candidate_node_entry: Dictionary in candidate_node_entries:
			if participating_node_paths.has(_GF_VARIANT_ACCESS_SCRIPT.get_option_string(candidate_node_entry, "node_path")):
				node_entries.append(candidate_node_entry)
	else:
		node_entries = candidate_node_entries

	return {
		"ok": true,
		"root_path": root.get_path(),
		"node_count": node_entries.size(),
		"signal_count": signal_entries.size(),
		"connection_count": connection_entries.size(),
		"nodes": node_entries,
		"signals": signal_entries,
		"connections": connection_entries,
		"truncated": _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(scan_state, "truncated", false),
	}


## 为信号图报告构建按节点分组的索引。
## [br]
## @api public
## [br]
## @param graph: build_signal_graph() 返回的报告。
## [br]
## @schema graph: Dictionary returned by build_signal_graph().
## [br]
## @return 节点索引，包含 incoming/outgoing/signals。
## [br]
## @schema return: Dictionary containing node_count, connection_count, nodes, outgoing, incoming, and signals.
static func index_signal_graph(graph: Dictionary) -> Dictionary:
	var nodes_by_path: Dictionary = {}
	var outgoing: Dictionary = {}
	var incoming: Dictionary = {}
	var signals_by_node: Dictionary = {}

	for node_variant: Variant in _GF_VARIANT_ACCESS_SCRIPT.get_option_array(graph, "nodes"):
		var node_entry: Dictionary = _GF_VARIANT_ACCESS_SCRIPT.as_dictionary(node_variant)
		if node_entry.is_empty():
			continue
		var node_path: String = _GF_VARIANT_ACCESS_SCRIPT.get_option_string(node_entry, "node_path")
		nodes_by_path[node_path] = node_entry.duplicate(true)
		outgoing[node_path] = []
		incoming[node_path] = []
		signals_by_node[node_path] = []

	for signal_variant: Variant in _GF_VARIANT_ACCESS_SCRIPT.get_option_array(graph, "signals"):
		var signal_entry: Dictionary = _GF_VARIANT_ACCESS_SCRIPT.as_dictionary(signal_variant)
		if signal_entry.is_empty():
			continue
		var node_path: String = _GF_VARIANT_ACCESS_SCRIPT.get_option_string(signal_entry, "node_path")
		if not signals_by_node.has(node_path):
			signals_by_node[node_path] = []
		var signal_group: Array = _ensure_dictionary_array(signals_by_node, node_path)
		signal_group.append(signal_entry.duplicate(true))

	for connection_variant: Variant in _GF_VARIANT_ACCESS_SCRIPT.get_option_array(graph, "connections"):
		var connection: Dictionary = _GF_VARIANT_ACCESS_SCRIPT.as_dictionary(connection_variant)
		if connection.is_empty():
			continue
		var source_path: String = _GF_VARIANT_ACCESS_SCRIPT.get_option_string(connection, "source_node_path")
		var target_path: String = _GF_VARIANT_ACCESS_SCRIPT.get_option_string(connection, "target_node_path")
		_append_signal_graph_index_entry(outgoing, source_path, connection)
		_append_signal_graph_index_entry(incoming, target_path, connection)

	return {
		"node_count": nodes_by_path.size(),
		"connection_count": _GF_VARIANT_ACCESS_SCRIPT.get_option_int(graph, "connection_count"),
		"nodes": nodes_by_path,
		"outgoing": outgoing,
		"incoming": incoming,
		"signals": signals_by_node,
	}


# --- 私有/辅助方法 ---

static func _collect_signal_graph_nodes(
	root: Node,
	result: Array[Node],
	include_internal: bool,
	depth: int,
	max_node_depth: int,
	max_nodes: int,
	scan_state: Dictionary
) -> void:
	if not _can_collect_more_signal_graph_nodes(result, max_nodes):
		_warn_signal_graph_node_limit(max_nodes, scan_state)
		return

	result.append(root)
	var child_count: int = root.get_child_count(include_internal)
	if max_node_depth > 0 and depth >= max_node_depth:
		if child_count > 0:
			_warn_signal_graph_depth_limit(root, max_node_depth, scan_state)
		return

	for child: Node in root.get_children(include_internal):
		if not _can_collect_more_signal_graph_nodes(result, max_nodes):
			_warn_signal_graph_node_limit(max_nodes, scan_state)
			break
		_collect_signal_graph_nodes(child, result, include_internal, depth + 1, max_node_depth, max_nodes, scan_state)


static func _collect_scene_paths_recursive(
	root_path: String,
	result: PackedStringArray,
	include_hidden: bool,
	respect_gdignore: bool,
	depth: int,
	max_scan_depth: int,
	max_scene_paths: int,
	scan_state: Dictionary
) -> void:
	if not _can_collect_more_scene_paths(result, max_scene_paths):
		_warn_scene_path_limit(max_scene_paths, scan_state)
		return

	var dir: DirAccess = DirAccess.open(root_path)
	if dir == null:
		return

	dir.include_hidden = include_hidden
	dir.include_navigational = false
	var list_error: Error = dir.list_dir_begin()
	if list_error != OK:
		return

	var entry: String = dir.get_next()
	while not entry.is_empty():
		if not _can_collect_more_scene_paths(result, max_scene_paths):
			_warn_scene_path_limit(max_scene_paths, scan_state)
			break

		var child_path: String = root_path.path_join(entry)
		if dir.current_is_dir():
			if _should_scan_directory(
				child_path,
				entry,
				include_hidden,
				respect_gdignore,
				depth,
				max_scan_depth,
				scan_state
			):
				_collect_scene_paths_recursive(
					child_path,
					result,
					include_hidden,
					respect_gdignore,
					depth + 1,
					max_scan_depth,
					max_scene_paths,
					scan_state
				)
		elif entry.ends_with(".tscn"):
			_append_packed_string(result, child_path)
		entry = dir.get_next()
	dir.list_dir_end()


static func _should_scan_directory(
	path: String,
	dir_name: String,
	include_hidden: bool,
	respect_gdignore: bool,
	current_depth: int,
	max_scan_depth: int,
	scan_state: Dictionary
) -> bool:
	if not include_hidden and dir_name.begins_with("."):
		return false
	if respect_gdignore and FileAccess.file_exists(path.path_join(".gdignore")):
		return false
	if max_scan_depth > 0 and current_depth >= max_scan_depth:
		_warn_scene_depth_limit(path, max_scan_depth, scan_state)
		return false
	return true


static func _can_collect_more_scene_paths(result: PackedStringArray, max_scene_paths: int) -> bool:
	return max_scene_paths <= 0 or result.size() < max_scene_paths


static func _can_collect_more_signal_graph_nodes(result: Array[Node], max_nodes: int) -> bool:
	return max_nodes <= 0 or result.size() < max_nodes


static func _make_scan_state() -> Dictionary:
	return {
		"count_warning_emitted": false,
		"depth_warning_emitted": false,
	}


static func _make_signal_graph_scan_state() -> Dictionary:
	return {
		"truncated": false,
		"count_warning_emitted": false,
		"depth_warning_emitted": false,
	}


static func _warn_scene_path_limit(max_scene_paths: int, scan_state: Dictionary) -> void:
	if max_scene_paths <= 0 or _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(scan_state, "count_warning_emitted", false):
		return
	scan_state["count_warning_emitted"] = true
	push_warning("[GFSceneSignalAudit] collect_scene_paths 已达到 max_scene_paths=%d，后续场景已跳过。" % max_scene_paths)


static func _warn_scene_depth_limit(path: String, max_scan_depth: int, scan_state: Dictionary) -> void:
	if max_scan_depth <= 0 or _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(scan_state, "depth_warning_emitted", false):
		return
	scan_state["depth_warning_emitted"] = true
	push_warning("[GFSceneSignalAudit] collect_scene_paths 已达到 max_scan_depth=%d，已跳过更深目录：%s。" % [max_scan_depth, path])


static func _warn_signal_graph_node_limit(max_nodes: int, scan_state: Dictionary) -> void:
	if max_nodes <= 0 or _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(scan_state, "count_warning_emitted", false):
		return
	scan_state["count_warning_emitted"] = true
	scan_state["truncated"] = true
	push_warning("[GFSceneSignalAudit] build_signal_graph 已达到 max_nodes=%d，后续节点已跳过。" % max_nodes)


static func _warn_signal_graph_depth_limit(node: Node, max_node_depth: int, scan_state: Dictionary) -> void:
	if max_node_depth <= 0 or _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(scan_state, "depth_warning_emitted", false):
		return
	scan_state["depth_warning_emitted"] = true
	scan_state["truncated"] = true
	push_warning("[GFSceneSignalAudit] build_signal_graph 已达到 max_node_depth=%d，已跳过更深节点：%s。" % [
		max_node_depth,
		_relative_node_path(node, node),
	])


static func _get_node_or_root(root: Node, path: NodePath) -> Node:
	if path.is_empty() or String(path) == ".":
		return root
	return root.get_node_or_null(path)


static func _make_runtime_connection_entry(
	root: Node,
	source_node: Node,
	signal_name: StringName,
	connection_info: Dictionary
) -> Dictionary:
	var callback: Callable = _get_dictionary_callable(connection_info, "callable")
	var target_object: Object = callback.get_object() if callback.is_valid() else null
	var target_node: Node = _variant_to_node(target_object)
	var target_path: String = ""
	if target_node != null:
		target_path = _relative_node_path(root, target_node)

	var flags: int = _GF_VARIANT_ACCESS_SCRIPT.get_option_int(connection_info, "flags")

	return {
		"source_node_path": _relative_node_path(root, source_node),
		"target_node_path": target_path,
		"signal_name": String(signal_name),
		"method_name": String(callback.get_method()) if callback.is_valid() else "",
		"flags": flags,
		"is_persistent": (flags & CONNECT_PERSIST) != 0,
	}


static func _is_external_connection(root: Node, connection_info: Dictionary) -> bool:
	var callback: Callable = _get_dictionary_callable(connection_info, "callable")
	if not callback.is_valid():
		return false

	var target_object: Object = callback.get_object()
	var target_node: Node = _variant_to_node(target_object)
	if target_node == null:
		return true

	return target_node != root and not root.is_ancestor_of(target_node)


static func _make_runtime_node_entry(root: Node, node: Node) -> Dictionary:
	var script: Script = _variant_to_script(node.get_script())
	return {
		"node_path": _relative_node_path(root, node),
		"name": node.name,
		"type": node.get_class(),
		"script_path": script.resource_path if script != null else "",
		"child_count": node.get_child_count(),
		"signal_count": node.get_signal_list().size(),
	}


static func _relative_node_path(root: Node, node: Node) -> String:
	if root == node:
		return "."
	if root.is_ancestor_of(node):
		return String(root.get_path_to(node))
	return String(node.get_path())


static func _build_parameter_count_issue(
	scene_path: String,
	connection_index: int,
	state: SceneState,
	source_node: Node,
	target_node: Node
) -> Dictionary:
	var source_path: NodePath = state.get_connection_source(connection_index)
	var target_path: NodePath = state.get_connection_target(connection_index)
	var signal_name: StringName = state.get_connection_signal(connection_index)
	var method_name: StringName = state.get_connection_method(connection_index)
	var signal_arg_count: int = _get_signal_argument_count(source_node, signal_name)
	if signal_arg_count < 0:
		return {}

	var method_info: Dictionary = _get_method_info(target_node, method_name)
	if method_info.is_empty():
		return {}

	var binds: Array = state.get_connection_binds(connection_index)
	var unbind_count: int = int(state.get_connection_unbinds(connection_index))
	var delivered_arg_count: int = maxi(signal_arg_count - unbind_count, 0) + binds.size()
	var method_args: Array = _GF_VARIANT_ACCESS_SCRIPT.get_option_array(method_info, "args")
	var method_defaults: Array = _GF_VARIANT_ACCESS_SCRIPT.get_option_array(method_info, "default_args")
	var required_arg_count: int = maxi(method_args.size() - method_defaults.size(), 0)
	var maximum_arg_count: int = method_args.size()
	var accepts_extra_args: bool = (_GF_VARIANT_ACCESS_SCRIPT.get_option_int(method_info, "flags") & METHOD_FLAG_VARARG) != 0
	if delivered_arg_count >= required_arg_count and (accepts_extra_args or delivered_arg_count <= maximum_arg_count):
		return {}

	var issue: Dictionary = _make_connection_issue(
		IssueType.PARAMETER_COUNT_MISMATCH,
		scene_path,
		connection_index,
		source_path,
		target_path,
		signal_name,
		method_name,
		"连接传入参数数量与目标方法签名不匹配。"
	)
	issue["signal_arg_count"] = signal_arg_count
	issue["bind_arg_count"] = binds.size()
	issue["unbind_count"] = unbind_count
	issue["delivered_arg_count"] = delivered_arg_count
	issue["required_arg_count"] = required_arg_count
	issue["maximum_arg_count"] = maximum_arg_count
	return issue


static func _get_signal_argument_count(source_node: Node, signal_name: StringName) -> int:
	for signal_info: Dictionary in source_node.get_signal_list():
		if _GF_VARIANT_ACCESS_SCRIPT.get_option_string_name(signal_info, "name") == signal_name:
			var args: Array = _GF_VARIANT_ACCESS_SCRIPT.get_option_array(signal_info, "args")
			return args.size()
	return -1


static func _get_method_info(target_node: Node, method_name: StringName) -> Dictionary:
	for method_info: Dictionary in target_node.get_method_list():
		if _GF_VARIANT_ACCESS_SCRIPT.get_option_string_name(method_info, "name") == method_name:
			return method_info
	return {}


static func _append_signal_graph_index_entry(index: Dictionary, node_path: String, connection: Dictionary) -> void:
	var entries: Array = _ensure_dictionary_array(index, node_path)
	entries.append(connection.duplicate(true))


static func _ensure_dictionary_array(source: Dictionary, key: Variant) -> Array:
	var value: Variant = _GF_VARIANT_ACCESS_SCRIPT.get_option_value(source, key, [])
	if value is Array:
		return value

	var entries: Array = []
	source[key] = entries
	return entries


static func _get_dictionary_callable(source: Dictionary, key: Variant) -> Callable:
	return _variant_to_callable(_GF_VARIANT_ACCESS_SCRIPT.get_option_value(source, key, Callable()))


static func _append_packed_string(target: PackedStringArray, value: String) -> void:
	var _append_success: bool = target.append(value)


static func _variant_to_callable(value: Variant) -> Callable:
	if value is Callable:
		return value
	return Callable()


static func _variant_to_node(value: Variant) -> Node:
	if value is Node:
		return value
	return null


static func _variant_to_packed_scene(value: Variant) -> PackedScene:
	if value is PackedScene:
		return value
	return null


static func _variant_to_script(value: Variant) -> Script:
	if value is Script:
		return value
	return null


static func _make_scene_issue(issue_type: IssueType, scene_path: String, message: String) -> Dictionary:
	return {
		"type": issue_type,
		"type_name": _issue_type_name(issue_type),
		"scene_path": scene_path,
		"connection_index": -1,
		"message": message,
	}


static func _make_connection_issue(
	issue_type: IssueType,
	scene_path: String,
	connection_index: int,
	source_path: NodePath,
	target_path: NodePath,
	signal_name: StringName,
	method_name: StringName,
	message: String
) -> Dictionary:
	return {
		"type": issue_type,
		"type_name": _issue_type_name(issue_type),
		"scene_path": scene_path,
		"connection_index": connection_index,
		"source_node_path": String(source_path),
		"target_node_path": String(target_path),
		"signal_name": String(signal_name),
		"method_name": String(method_name),
		"message": message,
	}


static func _issue_type_name(issue_type: IssueType) -> String:
	match issue_type:
		IssueType.SCENE_LOAD_FAILED:
			return "scene_load_failed"
		IssueType.SCENE_STATE_UNAVAILABLE:
			return "scene_state_unavailable"
		IssueType.SCENE_INSTANTIATION_FAILED:
			return "scene_instantiation_failed"
		IssueType.MISSING_SOURCE:
			return "missing_source"
		IssueType.MISSING_TARGET:
			return "missing_target"
		IssueType.MISSING_SIGNAL:
			return "missing_signal"
		IssueType.MISSING_METHOD:
			return "missing_method"
		IssueType.PARAMETER_COUNT_MISMATCH:
			return "parameter_count_mismatch"
	return "unknown"
