extends GutTest


# --- 常量 ---

const VALID_SCENE: String = "res://tests/gf_core/fixtures/scene_signal_audit_valid.tscn"
const MISSING_METHOD_SCENE: String = "res://tests/gf_core/fixtures/scene_signal_audit_missing_method.tscn"
const MISSING_TARGET_SCENE: String = "res://tests/gf_core/fixtures/scene_signal_audit_missing_target.tscn"
const PARAMETER_MISMATCH_SCENE: String = "res://tests/gf_core/fixtures/scene_signal_audit_parameter_mismatch.tscn"
const GF_SCENE_SIGNAL_AUDIT = preload("res://addons/gf/kernel/editor/gf_scene_signal_audit.gd")
const GF_VARIANT_ACCESS = preload("res://addons/gf/kernel/core/gf_variant_access.gd")


# --- 测试用例 ---

func test_audit_scene_accepts_valid_editor_connection() -> void:
	var issues: Array[Dictionary] = GF_SCENE_SIGNAL_AUDIT.audit_scene(VALID_SCENE)

	assert_eq(issues, [], "有效编辑器连接不应产生审计问题。")


func test_audit_scene_reports_missing_method() -> void:
	var issues: Array[Dictionary] = GF_SCENE_SIGNAL_AUDIT.audit_scene(MISSING_METHOD_SCENE)
	var issue: Dictionary = issues[0]

	assert_eq(issues.size(), 1, "缺失目标方法应产生一个问题。")
	assert_eq(GF_VARIANT_ACCESS.get_option_int(issue, "type"), GF_SCENE_SIGNAL_AUDIT.IssueType.MISSING_METHOD, "问题类型应为缺失方法。")
	assert_eq(GF_VARIANT_ACCESS.get_option_string(issue, "method_name"), "missing_method", "报告应保留缺失的方法名。")


func test_audit_scene_reports_missing_target() -> void:
	var issues: Array[Dictionary] = GF_SCENE_SIGNAL_AUDIT.audit_scene(MISSING_TARGET_SCENE)
	var issue: Dictionary = issues[0]

	assert_eq(issues.size(), 1, "缺失目标节点应产生一个问题。")
	assert_eq(GF_VARIANT_ACCESS.get_option_int(issue, "type"), GF_SCENE_SIGNAL_AUDIT.IssueType.MISSING_TARGET, "问题类型应为缺失目标。")
	assert_eq(GF_VARIANT_ACCESS.get_option_string(issue, "target_node_path"), "MissingReceiver", "报告应保留缺失的节点路径。")


func test_audit_scene_reports_parameter_mismatch() -> void:
	var issues: Array[Dictionary] = GF_SCENE_SIGNAL_AUDIT.audit_scene(PARAMETER_MISMATCH_SCENE)
	var issue: Dictionary = issues[0]

	assert_eq(issues.size(), 1, "信号参数不足时应产生一个问题。")
	assert_eq(GF_VARIANT_ACCESS.get_option_int(issue, "type"), GF_SCENE_SIGNAL_AUDIT.IssueType.PARAMETER_COUNT_MISMATCH, "问题类型应为参数数量不匹配。")
	assert_eq(GF_VARIANT_ACCESS.get_option_int(issue, "delivered_arg_count"), 0, "Button.pressed 不传入参数。")
	assert_eq(GF_VARIANT_ACCESS.get_option_int(issue, "required_arg_count"), 1, "目标方法需要一个必填参数。")


func test_audit_scene_paths_returns_summary() -> void:
	var report: Dictionary = GF_SCENE_SIGNAL_AUDIT.audit_scene_paths(PackedStringArray([
		VALID_SCENE,
		MISSING_METHOD_SCENE,
		PARAMETER_MISMATCH_SCENE,
	]))

	assert_false(GF_VARIANT_ACCESS.get_option_bool(report, "ok"), "包含问题场景时汇总应标记失败。")
	assert_eq(GF_VARIANT_ACCESS.get_option_int(report, "scene_count"), 3, "汇总应记录扫描场景数。")
	assert_eq(GF_VARIANT_ACCESS.get_option_int(report, "issue_count"), 2, "汇总应统计所有问题。")
	assert_eq(GF_VARIANT_ACCESS.get_option_packed_string_array(report, "scanned_paths").size(), 3, "汇总应保留已扫描路径。")


func test_collect_scene_paths_respects_gdignore() -> void:
	var paths: PackedStringArray = GF_SCENE_SIGNAL_AUDIT.collect_scene_paths("res://tests/gf_core/fixtures")

	assert_true(paths.has(VALID_SCENE), "收集器应包含普通 fixture 场景。")
	assert_false(paths.has("res://tests/gf_core/fixtures/scene_signal_audit_ignored/ignored_scene.tscn"), "默认应跳过包含 .gdignore 的目录。")


func test_collect_scene_paths_respects_path_limit() -> void:
	var directory: String = "user://gf_scene_signal_audit_scan"
	var first_path: String = directory.path_join("first.tscn")
	var second_path: String = directory.path_join("second.tscn")
	var make_error: Error = DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	assert_true(make_error == OK or make_error == ERR_ALREADY_EXISTS, "测试应能创建 user:// 临时目录。")
	_write_empty_user_file(first_path)
	_write_empty_user_file(second_path)

	var paths: PackedStringArray = GF_SCENE_SIGNAL_AUDIT.collect_scene_paths(directory, {
		"max_scene_paths": 1,
	})

	assert_eq(DirAccess.remove_absolute(ProjectSettings.globalize_path(first_path)), OK, "测试应能删除第一个临时场景。")
	assert_eq(DirAccess.remove_absolute(ProjectSettings.globalize_path(second_path)), OK, "测试应能删除第二个临时场景。")
	assert_eq(DirAccess.remove_absolute(ProjectSettings.globalize_path(directory)), OK, "测试应能删除临时目录。")

	assert_eq(paths.size(), 1, "场景路径收集应遵守 max_scene_paths 上限。")
	assert_push_warning("[GFSceneSignalAudit] collect_scene_paths 已达到 max_scene_paths=1，后续场景已跳过。")


func test_build_signal_graph_reports_runtime_connections() -> void:
	var root: Node = Node.new()
	var emitter: GraphEmitter = GraphEmitter.new()
	var receiver: GraphReceiver = GraphReceiver.new()
	root.name = "Root"
	emitter.name = "Emitter"
	receiver.name = "Receiver"
	add_child_autofree(root)
	root.add_child(emitter)
	root.add_child(receiver)
	var connect_error: int = emitter.ping.connect(receiver.receive)
	assert_eq(connect_error, OK, "测试应能连接运行时信号。")

	var graph: Dictionary = GF_SCENE_SIGNAL_AUDIT.build_signal_graph(root)

	assert_true(GF_VARIANT_ACCESS.get_option_bool(graph, "ok"), "运行时信号图应成功构建。")
	assert_eq(GF_VARIANT_ACCESS.get_option_int(graph, "connection_count"), 1, "信号图应记录运行时连接数量。")
	var connections: Array = GF_VARIANT_ACCESS.get_option_array(graph, "connections")
	var connection: Dictionary = GF_VARIANT_ACCESS.as_dictionary(connections[0])
	assert_eq(GF_VARIANT_ACCESS.get_option_string(connection, "source_node_path"), "Emitter", "连接应记录相对源节点路径。")
	assert_eq(GF_VARIANT_ACCESS.get_option_string(connection, "target_node_path"), "Receiver", "连接应记录相对目标节点路径。")
	assert_eq(GF_VARIANT_ACCESS.get_option_string(connection, "method_name"), "receive", "连接应记录目标方法名。")


func test_build_signal_graph_can_focus_participating_nodes() -> void:
	var root: Node = Node.new()
	var emitter: GraphEmitter = GraphEmitter.new()
	var receiver: GraphReceiver = GraphReceiver.new()
	var idle: Node = Node.new()
	root.name = "Root"
	emitter.name = "Emitter"
	receiver.name = "Receiver"
	idle.name = "Idle"
	add_child_autofree(root)
	root.add_child(emitter)
	root.add_child(receiver)
	root.add_child(idle)
	var connect_error: int = emitter.ping.connect(receiver.receive)
	assert_eq(connect_error, OK, "测试应能连接运行时信号。")

	var graph: Dictionary = GF_SCENE_SIGNAL_AUDIT.build_signal_graph(root, {
		"participating_nodes_only": true,
	})
	var node_paths: PackedStringArray = _get_graph_node_paths(graph)

	assert_eq(GF_VARIANT_ACCESS.get_option_int(graph, "node_count"), 2, "聚焦模式只应统计参与信号图的节点。")
	assert_true(node_paths.has("Emitter"), "聚焦模式应包含信号来源节点。")
	assert_true(node_paths.has("Receiver"), "聚焦模式应包含信号目标节点。")
	assert_false(node_paths.has("."), "聚焦模式不应包含未参与信号连接的根节点。")
	assert_false(node_paths.has("Idle"), "聚焦模式不应包含无信号参与的普通节点。")


func test_build_signal_graph_reports_truncation_when_node_limit_is_reached() -> void:
	var root: Node = Node.new()
	root.name = "Root"
	root.add_child(Node.new())
	root.add_child(Node.new())
	add_child_autofree(root)

	var graph: Dictionary = GF_SCENE_SIGNAL_AUDIT.build_signal_graph(root, {
		"max_nodes": 1,
	})

	assert_eq(GF_VARIANT_ACCESS.get_option_int(graph, "node_count"), 1, "信号图应遵守 max_nodes 上限。")
	assert_true(GF_VARIANT_ACCESS.get_option_bool(graph, "truncated"), "信号图被截断时应返回 truncated 标记。")
	assert_push_warning("[GFSceneSignalAudit] build_signal_graph 已达到 max_nodes=1，后续节点已跳过。")


func test_signal_graph_index_groups_runtime_connections() -> void:
	var root: Node = Node.new()
	var emitter: GraphEmitter = GraphEmitter.new()
	var receiver: GraphReceiver = GraphReceiver.new()
	root.name = "Root"
	emitter.name = "Emitter"
	receiver.name = "Receiver"
	add_child_autofree(root)
	root.add_child(emitter)
	root.add_child(receiver)
	var connect_error: int = emitter.ping.connect(receiver.receive)
	assert_eq(connect_error, OK, "测试应能连接运行时信号。")

	var graph: Dictionary = GF_SCENE_SIGNAL_AUDIT.build_signal_graph(root)
	var index: Dictionary = GF_SCENE_SIGNAL_AUDIT.index_signal_graph(graph)
	var outgoing: Dictionary = GF_VARIANT_ACCESS.get_option_dictionary(index, "outgoing")
	var incoming: Dictionary = GF_VARIANT_ACCESS.get_option_dictionary(index, "incoming")
	var nodes: Dictionary = GF_VARIANT_ACCESS.get_option_dictionary(index, "nodes")

	assert_true(nodes.has("Emitter"), "索引应包含节点条目。")
	assert_eq(GF_VARIANT_ACCESS.as_array(outgoing["Emitter"]).size(), 1, "索引应按源节点归类输出连接。")
	assert_eq(GF_VARIANT_ACCESS.as_array(incoming["Receiver"]).size(), 1, "索引应按目标节点归类输入连接。")


func test_build_signal_graph_can_filter_external_targets() -> void:
	var root: Node = Node.new()
	var emitter: GraphEmitter = GraphEmitter.new()
	var receiver: GraphReceiver = GraphReceiver.new()
	root.name = "Root"
	emitter.name = "Emitter"
	receiver.name = "ExternalReceiver"
	add_child_autofree(root)
	add_child_autofree(receiver)
	root.add_child(emitter)
	var connect_error: int = emitter.ping.connect(receiver.receive)
	assert_eq(connect_error, OK, "测试应能连接外部目标信号。")

	var graph: Dictionary = GF_SCENE_SIGNAL_AUDIT.build_signal_graph(root, {
		"include_external_targets": false,
	})

	assert_true(GF_VARIANT_ACCESS.get_option_bool(graph, "ok"), "信号图应成功构建。")
	assert_eq(GF_VARIANT_ACCESS.get_option_int(graph, "connection_count"), 0, "关闭外部目标时不应记录根节点外的连接。")


# --- 私有/辅助方法 ---

func _write_empty_user_file(path: String) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	assert_not_null(file, "测试应能创建 user:// 临时文件。")
	if file == null:
		return
	var _store_string_result_183: Variant = file.store_string("")
	file.close()


func _get_graph_node_paths(graph: Dictionary) -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	for node_variant: Variant in GF_VARIANT_ACCESS.get_option_array(graph, "nodes"):
		var node_entry: Dictionary = GF_VARIANT_ACCESS.as_dictionary(node_variant)
		var _path_appended: bool = result.append(GF_VARIANT_ACCESS.get_option_string(node_entry, "node_path"))
	result.sort()
	return result


# --- 辅助子类 ---

class GraphEmitter:
	extends Node

	signal ping(value: int)


class GraphReceiver:
	extends Node

	var last_value: int = 0

	func receive(value: int) -> void:
		last_value = value
