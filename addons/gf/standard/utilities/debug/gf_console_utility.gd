## GFConsoleUtility: 运行时开发者控制台。
##
## 提供命令注册、解析与执行能力，并在初始化时构建覆盖全屏的调试 GUI。
## 默认通过快捷键呼出，同时会消费 `GFLogUtility` 的日志信号进行彩色输出。
## [br]
## @api public
## [br]
## @category runtime_service
## [br]
## @since 3.17.0
class_name GFConsoleUtility
extends GFUtility


# --- 枚举 ---

## 控制台命令风险等级。
## [br]
## @api public
enum CommandTier {
	## 只读观察类命令。
	OBSERVE,
	## 会改变运行时状态的控制类命令。
	CONTROL,
	## 删档、跳关、重连等高风险命令。
	DANGER,
}


# --- 常量 ---

## DANGER 命令的确认参数。
## [br]
## @api public
const DANGER_CONFIRMATION_ARGUMENT: String = "--confirm"


# --- 公共变量 ---

## 呼出或隐藏控制台的快捷键；默认为 `KEY_F1`。
## [br]
## @api public
var toggle_key: Key = KEY_F1

## 控制台最多保留的输出行数，避免高频日志无限增长。
## [br]
## @api public
var max_output_lines: int = 1000:
	set(value):
		max_output_lines = maxi(value, 1)
		if is_instance_valid(_console_gui):
			_console_gui.max_output_lines = max_output_lines

## 控制台最多保留的历史命令数量。
## [br]
## @api public
var max_history_size: int = 100:
	set(value):
		max_history_size = maxi(value, 1)
		if is_instance_valid(_console_gui):
			_console_gui.max_history_size = max_history_size

## 控制台背景透明度，范围 0 到 1。
## [br]
## @api public
var background_alpha: float = 0.85:
	set(value):
		background_alpha = clampf(value, 0.0, 1.0)
		if is_instance_valid(_console_gui):
			_console_gui.background_alpha = background_alpha

## 是否使用可拖拽、可缩放的窗口模式。默认 false 保持全屏覆盖。
## [br]
## @api public
var windowed: bool = false:
	set(value):
		windowed = value
		if is_instance_valid(_console_gui):
			_console_gui.windowed = windowed

## 窗口模式初始尺寸相对视口比例。
## [br]
## @api public
var initial_window_size_ratio: Vector2 = Vector2(0.72, 0.55):
	set(value):
		initial_window_size_ratio = Vector2(
			clampf(value.x, 0.2, 1.0),
			clampf(value.y, 0.2, 1.0)
		)
		if is_instance_valid(_console_gui):
			_console_gui.initial_window_size_ratio = initial_window_size_ratio

## 窗口模式最小尺寸。
## [br]
## @api public
var minimum_window_size: Vector2 = Vector2(360.0, 220.0):
	set(value):
		minimum_window_size = Vector2(maxf(value.x, 120.0), maxf(value.y, 80.0))
		if is_instance_valid(_console_gui):
			_console_gui.minimum_window_size = minimum_window_size

## 是否把控制台放在较高 CanvasLayer 层级。
## [br]
## @api public
var keep_topmost: bool = true:
	set(value):
		keep_topmost = value
		if is_instance_valid(_console_gui):
			_console_gui.keep_topmost = keep_topmost

## 是否只在 debug 构建中创建控制台 GUI。发布构建需要显式关闭此项才会创建控制台。
## [br]
## @api public
var debug_only: bool = true

## 允许执行的最高命令风险等级。
## [br]
## @api public
var max_command_tier: CommandTier = CommandTier.CONTROL

## 执行 DANGER 命令时是否要求传入 `--confirm` 参数。
## [br]
## @api public
var require_danger_confirmation: bool = true


# --- 私有变量 ---

# 已注册命令表。
var _commands: Dictionary = {}

# 控制台 GUI 实例。
var _console_gui: _GFConsoleGUI

# 当前已连接的日志工具。
var _connected_log_util: GFLogUtility = null


# --- GF 生命周期方法 ---

## 初始化控制台命令表和运行时 GUI。
## [br]
## @api public
func init() -> void:
	if debug_only and not OS.is_debug_build():
		return

	register_command("help", _cmd_help, "显示所有可用指令。")
	register_command("clear", _cmd_clear, "清空控制台输出。")
	register_command("scene.tree", _cmd_scene_tree, "输出只读场景树摘要。", {
		"tier": CommandTier.OBSERVE,
	})
	register_command("scene.node", _cmd_scene_node, "查看节点的只读摘要。", {
		"tier": CommandTier.OBSERVE,
	})

	_console_gui = _GFConsoleGUI.new()
	_console_gui.name = "GFConsoleOverlay"
	_console_gui.toggle_key = toggle_key
	_console_gui.max_output_lines = max_output_lines
	_console_gui.max_history_size = max_history_size
	_console_gui.background_alpha = background_alpha
	_console_gui.windowed = windowed
	_console_gui.initial_window_size_ratio = initial_window_size_ratio
	_console_gui.minimum_window_size = minimum_window_size
	_console_gui.keep_topmost = keep_topmost
	_console_gui.command_name_provider = Callable(self, "get_command_names")
	_connect_signal(_console_gui.command_submitted, _on_command_submitted)

	var tree: SceneTree = _get_main_scene_tree()
	if tree != null:
		tree.root.call_deferred("add_child", _console_gui)


## 连接日志工具信号。
## [br]
## @api public
func ready() -> void:
	var log_util: GFLogUtility = _get_log_utility()
	if log_util == null or not log_util.has_signal("log_emitted"):
		return

	if _connected_log_util != null and _connected_log_util != log_util:
		if _connected_log_util.log_emitted.is_connected(_on_log_emitted):
			_connected_log_util.log_emitted.disconnect(_on_log_emitted)

	if not log_util.log_emitted.is_connected(_on_log_emitted):
		_connect_signal(log_util.log_emitted, _on_log_emitted)

	_connected_log_util = log_util


## 释放 GUI 并断开日志信号。
## [br]
## @api public
func dispose() -> void:
	if _connected_log_util != null and _connected_log_util.log_emitted.is_connected(_on_log_emitted):
		_connected_log_util.log_emitted.disconnect(_on_log_emitted)

	_connected_log_util = null

	if is_instance_valid(_console_gui):
		var parent: Node = _console_gui.get_parent()
		if parent != null:
			parent.remove_child(_console_gui)
		_console_gui.queue_free()

	_console_gui = null


# --- 公共方法 ---

## 注册控制台命令。
## [br]
## @api public
## [br]
## @param cmd_name: 指令名称。
## [br]
## @param callback: 指令回调，签名为 `func(args: PackedStringArray) -> void`。
## [br]
## @param description: 指令说明文本。
## [br]
## @param metadata: 项目自定义元数据。
## [br]
## @schema metadata: Dictionary，支持 tier 等项目自定义命令元数据。
func register_command(cmd_name: String, callback: Callable, description: String, metadata: Dictionary = {}) -> void:
	_commands[cmd_name] = {
		"callback": callback,
		"description": description,
		"metadata": metadata.duplicate(true),
	}


## 注册资源化控制台命令。
## [br]
## @api public
## [br]
## @param definition: 命令资源定义。
## [br]
## @param callback: 指令回调，签名为 `func(args: PackedStringArray) -> void`。
func register_command_definition(definition: GFConsoleCommandDefinition, callback: Callable) -> void:
	if definition == null or not callback.is_valid():
		return

	for cmd_name: String in definition.get_all_names():
		register_command(cmd_name, callback, definition.description, {
			"definition": definition,
			"primary_command_name": definition.command_name,
		})


## 注销控制台命令。
## [br]
## @api public
## [br]
## @param cmd_name: 指令名称。
func unregister_command(cmd_name: String) -> void:
	_erase_dictionary_key(_commands, cmd_name)


## 检查控制台命令是否已注册。
## [br]
## @api public
## [br]
## @param cmd_name: 指令名称。
## [br]
## @return 已注册返回 true。
func has_command(cmd_name: String) -> bool:
	return _commands.has(cmd_name)


## 获取当前已注册命令名称。
## [br]
## @api public
## [br]
## @return 排序后的命令名称数组。
func get_command_names() -> PackedStringArray:
	var names: PackedStringArray = PackedStringArray()
	for cmd_name: String in _commands.keys():
		_append_packed_string(names, cmd_name)
	names.sort()
	return names


## 获取控制台命令目录。
## [br]
## @api public
## [br]
## @return 命令元数据字典。
## [br]
## @schema return: Dictionary[String, Dictionary]，每个值包含 description、metadata 和 tier。
func get_command_catalog() -> Dictionary:
	var result: Dictionary = {}
	for cmd_name: String in get_command_names():
		var entry: Dictionary = _get_command_entry(cmd_name)
		result[cmd_name] = {
			"description": GFVariantData.get_option_string(entry, "description"),
			"metadata": GFVariantData.get_option_dictionary(entry, "metadata"),
			"tier": _get_command_tier(entry),
		}
	return result


## 根据前缀获取命令补全候选。
## [br]
## @api public
## [br]
## @param prefix: 命令名前缀。
## [br]
## @return 排序后的候选命令名数组。
func suggest_commands(prefix: String) -> PackedStringArray:
	var suggestions: PackedStringArray = PackedStringArray()
	for cmd_name: String in get_command_names():
		if prefix.is_empty() or cmd_name.begins_with(prefix):
			_append_packed_string(suggestions, cmd_name)
	return suggestions


## 根据字符串相似度获取可能的命令名，用于未知命令诊断。
## [br]
## @api public
## [br]
## @param cmd_name: 用户输入的命令名。
## [br]
## @param limit: 最多返回的候选数量。
## [br]
## @param threshold: 最低相似度，范围 0 到 1。
## [br]
## @return 按相似度降序排列的候选命令名。
func suggest_similar_commands(cmd_name: String, limit: int = 3, threshold: float = 0.5) -> PackedStringArray:
	if cmd_name.is_empty() or _commands.is_empty() or limit <= 0:
		return PackedStringArray()

	var scored: Array[Array] = []
	for registered_name: String in _commands.keys():
		var score: float = cmd_name.similarity(registered_name)
		if score >= threshold:
			scored.append([score, registered_name])
	scored.sort_custom(func(a: Array, b: Array) -> bool:
		return GFVariantData.to_float(a[0]) > GFVariantData.to_float(b[0])
	)

	var suggestions: PackedStringArray = PackedStringArray()
	var result_count: int = mini(limit, scored.size())
	for index: int in range(result_count):
		var score_entry: Array = scored[index]
		if score_entry.size() >= 2:
			_append_packed_string(suggestions, GFVariantData.to_text(score_entry[1]))
	return suggestions


## 解析并执行一条原始输入。
## [br]
## @api public
## [br]
## @param raw_input: 用户输入的完整字符串。
## [br]
## @return 找到并成功执行命令时返回 `true`。
func execute_command(raw_input: String) -> bool:
	var trimmed: String = raw_input.strip_edges()
	if trimmed.is_empty():
		return false

	var parts: PackedStringArray = _parse_command_line(trimmed)
	if parts.is_empty():
		return false

	var cmd_name: String = parts[0]
	var args: PackedStringArray = PackedStringArray()
	for i: int in range(1, parts.size()):
		_append_packed_string(args, parts[i])

	if not _commands.has(cmd_name):
		if is_instance_valid(_console_gui):
			var similar_commands: PackedStringArray = suggest_similar_commands(cmd_name)
			if similar_commands.is_empty():
				_console_gui.append_text("[color=red]未知指令：%s。输入 'help' 查看帮助。[/color]" % _escape_bbcode_text(cmd_name))
			else:
				_console_gui.append_text(
					"[color=red]未知指令：%s。你是不是想输入：%s？[/color]" % [
						_escape_bbcode_text(cmd_name),
						_escape_bbcode_text(", ".join(similar_commands)),
					]
				)
		return false

	var entry: Dictionary = _get_command_entry(cmd_name)
	if not _prepare_command_execution(cmd_name, entry, args):
		return false

	var cb: Callable = entry["callback"]
	cb.call(args)
	return true


## 向控制台输出追加一行 BBCode 文本。
## [br]
## @api public
## [br]
## @param bbcode_line: 要追加的一行 BBCode 文本。
func append_output_line(bbcode_line: String) -> void:
	if is_instance_valid(_console_gui):
		_console_gui.append_text(bbcode_line)


## 向控制台输出追加多行 BBCode 文本。
## [br]
## @api public
## [br]
## @param bbcode_lines: 要追加的 BBCode 文本行列表。
func append_output_lines(bbcode_lines: PackedStringArray) -> void:
	if is_instance_valid(_console_gui):
		_console_gui.append_lines(bbcode_lines)


## 清空控制台输出。
## [br]
## @api public
func clear_output() -> void:
	if is_instance_valid(_console_gui):
		_console_gui.clear_output()


## 立即刷新待追加的控制台输出。
## [br]
## @api public
func flush_output() -> void:
	if is_instance_valid(_console_gui):
		_console_gui.flush_output()


## 获取控制台调试快照。
## [br]
## @api public
## [br]
## @return 控制台命令、GUI 和配置状态。
## [br]
## @schema return: Dictionary，包含 command_count、command_names、command_catalog、has_console_gui、gui、配置字段。
func get_debug_snapshot() -> Dictionary:
	return {
		"command_count": _commands.size(),
		"command_names": get_command_names(),
		"command_catalog": get_command_catalog(),
		"has_console_gui": is_instance_valid(_console_gui),
		"gui": _console_gui.get_debug_snapshot() if is_instance_valid(_console_gui) else {},
		"toggle_key": toggle_key,
		"max_output_lines": max_output_lines,
		"max_history_size": max_history_size,
		"background_alpha": background_alpha,
		"windowed": windowed,
		"initial_window_size_ratio": initial_window_size_ratio,
		"minimum_window_size": minimum_window_size,
		"keep_topmost": keep_topmost,
		"debug_only": debug_only,
		"max_command_tier": max_command_tier,
		"require_danger_confirmation": require_danger_confirmation,
	}


# --- 私有/辅助方法 ---

func _get_command_entry(cmd_name: String) -> Dictionary:
	return GFVariantData.as_dictionary(GFVariantData.get_option_value(_commands, cmd_name, {}))


func _get_main_scene_tree() -> SceneTree:
	var main_loop: MainLoop = Engine.get_main_loop()
	if main_loop is SceneTree:
		var tree: SceneTree = main_loop
		return tree
	return null


func _get_log_utility() -> GFLogUtility:
	var utility: Variant = get_utility(GFLogUtility)
	if utility is GFLogUtility:
		var log_utility: GFLogUtility = utility
		return log_utility
	return null


func _append_packed_string(target: PackedStringArray, value: String) -> void:
	var appended: bool = target.append(value)
	if appended:
		return


func _erase_dictionary_key(source: Dictionary, key: Variant) -> void:
	var erased: bool = source.erase(key)
	if erased:
		return


func _connect_signal(source_signal: Signal, callback: Callable) -> void:
	var connected: int = source_signal.connect(callback)
	if connected == OK:
		return


func _parse_command_line(raw_input: String) -> PackedStringArray:
	var parts: PackedStringArray = PackedStringArray()
	var current: String = ""
	var in_quotes: bool = false
	var quote_char: String = ""
	var escaping: bool = false
	var token_started: bool = false

	for index: int in range(raw_input.length()):
		var ch: String = raw_input.substr(index, 1)
		if escaping:
			current += ch
			token_started = true
			escaping = false
			continue

		if ch == "\\":
			escaping = true
			token_started = true
			continue

		if in_quotes:
			if ch == quote_char:
				in_quotes = false
			else:
				current += ch
			continue

		if ch == "\"" or ch == "'":
			in_quotes = true
			quote_char = ch
			token_started = true
		elif ch == " " or ch == "\t":
			if token_started:
				_append_packed_string(parts, current)
				current = ""
				token_started = false
		else:
			current += ch
			token_started = true

	if escaping:
		current += "\\"
	if token_started:
		_append_packed_string(parts, current)
	return parts


func _prepare_command_execution(cmd_name: String, entry: Dictionary, args: PackedStringArray) -> bool:
	var tier: CommandTier = _get_command_tier(entry)
	if tier > max_command_tier:
		if is_instance_valid(_console_gui):
			_console_gui.append_text("[color=red]指令风险等级超过当前允许范围：%s。[/color]" % _escape_bbcode_text(cmd_name))
		return false

	if tier == CommandTier.DANGER and require_danger_confirmation:
		var confirmation_index: int = args.find(DANGER_CONFIRMATION_ARGUMENT)
		if confirmation_index < 0:
			if is_instance_valid(_console_gui):
				_console_gui.append_text("[color=yellow]危险指令需要追加 %s 确认。[/color]" % DANGER_CONFIRMATION_ARGUMENT)
			return false
		args.remove_at(confirmation_index)

	return true


func _get_command_tier(entry: Dictionary) -> CommandTier:
	var metadata: Dictionary = GFVariantData.get_option_dictionary(entry, "metadata")
	var tier_value: Variant = GFVariantData.get_option_value(metadata, "tier", CommandTier.OBSERVE)
	return _to_command_tier(GFVariantData.to_int(tier_value, CommandTier.OBSERVE))


func _to_command_tier(value: int) -> CommandTier:
	match clampi(value, CommandTier.OBSERVE, CommandTier.DANGER):
		CommandTier.CONTROL:
			return CommandTier.CONTROL
		CommandTier.DANGER:
			return CommandTier.DANGER
		_:
			return CommandTier.OBSERVE


func _escape_bbcode_text(value: Variant) -> String:
	return _escape_bbcode_string(GFVariantData.to_text(value))


static func _escape_bbcode_string(text: String) -> String:
	return text.replace("[", "[lb]").replace("]", "[rb]")


func _cmd_help(_args: PackedStringArray) -> void:
	if not is_instance_valid(_console_gui):
		return

	_console_gui.append_text("[color=cyan]--- 可用指令 ---[/color]")
	for cmd_name: String in _commands:
		var entry: Dictionary = _get_command_entry(cmd_name)
		var desc: String = GFVariantData.get_option_string(entry, "description")
		_console_gui.append_text("  [color=white]%s[/color] - %s" % [
			_escape_bbcode_text(cmd_name),
			_escape_bbcode_text(desc),
		])
	_console_gui.append_text("[color=cyan]----------------[/color]")


func _cmd_clear(_args: PackedStringArray) -> void:
	if is_instance_valid(_console_gui):
		_console_gui.clear_output()


func _cmd_scene_tree(args: PackedStringArray) -> void:
	if not is_instance_valid(_console_gui):
		return

	var max_depth: int = 3
	var max_nodes: int = 80
	var root_path: String = ""
	if args.size() >= 1 and args[0].is_valid_int():
		max_depth = maxi(args[0].to_int(), 0)
	if args.size() >= 2 and args[1].is_valid_int():
		max_nodes = maxi(args[1].to_int(), 1)
	if args.size() >= 3:
		root_path = args[2]

	var root: Node = _resolve_console_node(root_path)
	if root == null:
		_console_gui.append_text("[color=red]没有找到场景树根节点。[/color]")
		return

	var lines: PackedStringArray = PackedStringArray()
	var counter: Dictionary = { "count": 0, "truncated": false }
	_append_scene_tree_lines(root, 0, max_depth, max_nodes, counter, lines)
	if GFVariantData.get_option_bool(counter, "truncated"):
		_append_packed_string(lines, "... truncated")
	_console_gui.append_lines(_escape_plain_lines(lines))


func _cmd_scene_node(args: PackedStringArray) -> void:
	if not is_instance_valid(_console_gui):
		return

	var path: String = args[0] if args.size() > 0 else ""
	var node: Node = _resolve_console_node(path)
	if node == null:
		_console_gui.append_text("[color=red]没有找到节点：%s[/color]" % _escape_bbcode_text(path))
		return

	var lines: PackedStringArray = PackedStringArray()
	_append_packed_string(lines, "path: %s" % _get_console_node_path(node))
	_append_packed_string(lines, "type: %s" % node.get_class())
	_append_packed_string(lines, "children: %d" % node.get_child_count())
	var script: Script = null
	var script_value: Variant = node.get_script()
	if script_value is Script:
		script = script_value
	if script != null:
		_append_packed_string(lines, "script: %s" % script.resource_path)
	var groups: PackedStringArray = PackedStringArray()
	for group: StringName in node.get_groups():
		_append_packed_string(groups, String(group))
	groups.sort()
	if not groups.is_empty():
		_append_packed_string(lines, "groups: %s" % ", ".join(groups))
	_append_packed_string(lines, "signals: %d" % node.get_signal_list().size())
	_append_packed_string(lines, "methods: %d" % node.get_method_list().size())
	_console_gui.append_lines(_escape_plain_lines(lines))


func _resolve_console_node(path: String) -> Node:
	var tree: SceneTree = _get_main_scene_tree()
	if tree == null:
		return null

	if path.is_empty() or path == ".":
		return tree.current_scene if tree.current_scene != null else tree.root

	var node_path: NodePath = NodePath(path)
	if path.begins_with("/"):
		return tree.root.get_node_or_null(node_path)
	if tree.current_scene != null:
		var scene_node: Node = tree.current_scene.get_node_or_null(node_path)
		if scene_node != null:
			return scene_node
	return tree.root.get_node_or_null(node_path)


func _append_scene_tree_lines(
	node: Node,
	depth: int,
	max_depth: int,
	max_nodes: int,
	counter: Dictionary,
	lines: PackedStringArray
) -> void:
	if GFVariantData.get_option_int(counter, "count") >= max_nodes:
		counter["truncated"] = true
		return

	counter["count"] = GFVariantData.get_option_int(counter, "count") + 1
	_append_packed_string(lines, "%s%s [%s]" % [
		_make_tree_indent(depth),
		node.name,
		node.get_class(),
	])
	if depth >= max_depth:
		if node.get_child_count() > 0:
			counter["truncated"] = true
		return

	for child: Node in node.get_children():
		_append_scene_tree_lines(child, depth + 1, max_depth, max_nodes, counter, lines)
		if GFVariantData.get_option_bool(counter, "truncated"):
			return


func _escape_plain_lines(lines: PackedStringArray) -> PackedStringArray:
	var escaped: PackedStringArray = PackedStringArray()
	for line: String in lines:
		_append_packed_string(escaped, _escape_bbcode_text(line))
	return escaped


func _make_tree_indent(depth: int) -> String:
	var indent: String = ""
	for _index: int in range(depth):
		indent += "  "
	return indent


func _get_console_node_path(node: Node) -> String:
	return str(node.get_path()) if node.is_inside_tree() else String(node.name)


func _on_command_submitted(raw_input: String) -> void:
	if is_instance_valid(_console_gui):
		_console_gui.append_text("[color=gray]> %s[/color]" % _escape_bbcode_text(raw_input))

	var executed: bool = execute_command(raw_input)
	if executed:
		return


func _on_log_emitted(level: int, tag: String, message: String) -> void:
	if not is_instance_valid(_console_gui):
		return

	if _console_gui.is_tag_ignored(tag):
		return

	var color: String
	match level:
		0:
			color = "cyan"
		2:
			color = "yellow"
		3, 4:
			color = "red"
		_:
			color = "white"

	var level_names: PackedStringArray = PackedStringArray(["DEBUG", "INFO", "WARN", "ERROR", "FATAL"])
	var level_str: String = level_names[level] if level >= 0 and level < level_names.size() else "UNKNOWN"
	_console_gui.append_text("[color=%s][%s][%s] %s[/color]" % [
		color,
		level_str,
		_escape_bbcode_text(tag),
		_escape_bbcode_text(message),
	])


# --- 内部类 ---

class _GFConsoleGUI extends CanvasLayer:
	# --- 信号 ---

	## GUI 提交控制台输入时发出。
	## [br]
	## @api framework_internal
	## [br]
	## @param raw_input: 用户提交的原始输入。
	signal command_submitted(raw_input: String)


	# --- 常量 ---

	const _DEFAULT_LAYER: int = 1
	const _TOPMOST_LAYER: int = 150
	const _WINDOW_MARGIN: float = 16.0
	const _RESIZE_HANDLE_SIZE: float = 18.0


	# --- 公共变量 ---

	## 呼出或隐藏控制台的快捷键。
	## [br]
	## @api framework_internal
	var toggle_key: Key

	## 命令名提供回调。
	## [br]
	## @api framework_internal
	var command_name_provider: Callable

	## 控制台最多保留的输出行数。
	## [br]
	## @api framework_internal
	var max_output_lines: int = 1000:
		set(value):
			max_output_lines = maxi(value, 1)
			_trim_output_lines()
			if is_instance_valid(_output):
				_render_output()

	## 控制台最多保留的历史命令数量。
	## [br]
	## @api framework_internal
	var max_history_size: int = 100:
		set(value):
			max_history_size = maxi(value, 1)
			_trim_command_history()

	## 控制台背景透明度，范围 0 到 1。
	## [br]
	## @api framework_internal
	var background_alpha: float = 0.85:
		set(value):
			background_alpha = clampf(value, 0.0, 1.0)
			_apply_background_alpha()

	## 是否使用可拖拽、可缩放的窗口模式。
	## [br]
	## @api framework_internal
	var windowed: bool = false:
		set(value):
			windowed = value
			_layout_console()

	## 窗口模式初始尺寸相对视口比例。
	## [br]
	## @api framework_internal
	var initial_window_size_ratio: Vector2 = Vector2(0.72, 0.55):
		set(value):
			initial_window_size_ratio = Vector2(
				clampf(value.x, 0.2, 1.0),
				clampf(value.y, 0.2, 1.0)
			)
			_window_layout_initialized = false
			_layout_console()

	## 窗口模式最小尺寸。
	## [br]
	## @api framework_internal
	var minimum_window_size: Vector2 = Vector2(360.0, 220.0):
		set(value):
			minimum_window_size = Vector2(maxf(value.x, 120.0), maxf(value.y, 80.0))
			_layout_console()

	## 是否把控制台放在较高 CanvasLayer 层级。
	## [br]
	## @api framework_internal
	var keep_topmost: bool = true:
		set(value):
			keep_topmost = value
			_apply_layer()


	# --- 私有变量 ---

	var _panel: PanelContainer
	var _panel_style: StyleBoxFlat
	var _output: RichTextLabel
	var _input_field: LineEdit
	var _filter_input: LineEdit
	var _resize_handle: Panel
	var _ignored_tags: PackedStringArray = PackedStringArray()
	var _output_lines: PackedStringArray = PackedStringArray()
	var _pending_lines: PackedStringArray = PackedStringArray()
	var _flush_queued: bool = false
	var _command_history: PackedStringArray = PackedStringArray()
	var _history_index: int = -1
	var _window_layout_initialized: bool = false
	var _dragging: bool = false
	var _resizing: bool = false
	var _drag_offset: Vector2 = Vector2.ZERO
	var _resize_origin_mouse: Vector2 = Vector2.ZERO
	var _resize_origin_size: Vector2 = Vector2.ZERO

	func _append_packed_string(target: PackedStringArray, value: String) -> void:
		var appended: bool = target.append(value)
		if appended:
			return


	func _connect_signal(source_signal: Signal, callback: Callable) -> void:
		var connected: int = source_signal.connect(callback)
		if connected == OK:
			return

	func _init() -> void:
		_apply_layer()
		visible = false
		process_mode = Node.PROCESS_MODE_ALWAYS as Node.ProcessMode

		_panel = PanelContainer.new()
		_panel.name = "Panel"
		_panel.mouse_filter = Control.MOUSE_FILTER_STOP as Control.MouseFilter
		add_child(_panel)

		_panel_style = StyleBoxFlat.new()
		_panel_style.bg_color = Color(0.05, 0.05, 0.1, background_alpha)
		_panel.add_theme_stylebox_override("panel", _panel_style)

		var margin: MarginContainer = MarginContainer.new()
		margin.add_theme_constant_override("margin_left", 12)
		margin.add_theme_constant_override("margin_top", 12)
		margin.add_theme_constant_override("margin_right", 12)
		margin.add_theme_constant_override("margin_bottom", 12)
		_panel.add_child(margin)

		var vbox: VBoxContainer = VBoxContainer.new()
		margin.add_child(vbox)

		var header_hbox: HBoxContainer = HBoxContainer.new()
		vbox.add_child(header_hbox)

		var header: Label = Label.new()
		header.text = "[ GF Developer Console ]"
		header.modulate = Color(0.4, 0.8, 1.0)
		header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		header.mouse_filter = Control.MOUSE_FILTER_STOP as Control.MouseFilter
		_connect_signal(header.gui_input, _on_header_gui_input)
		header_hbox.add_child(header)

		var filter_label: Label = Label.new()
		filter_label.text = "过滤标签: "
		filter_label.modulate = Color(0.8, 0.8, 0.8)
		header_hbox.add_child(filter_label)

		_filter_input = LineEdit.new()
		_filter_input.placeholder_text = "逗号分隔 (如 sys,net)"
		_filter_input.custom_minimum_size = Vector2(200, 0)
		_connect_signal(_filter_input.text_changed, _on_filter_changed)
		header_hbox.add_child(_filter_input)

		_output = RichTextLabel.new()
		_output.bbcode_enabled = true
		_output.scroll_following = true
		_output.size_flags_vertical = Control.SIZE_EXPAND_FILL
		_output.selection_enabled = true
		vbox.add_child(_output)

		_input_field = LineEdit.new()
		_input_field.placeholder_text = "输入指令..."
		_input_field.clear_button_enabled = true
		_connect_signal(_input_field.text_submitted, _on_input_submitted)
		vbox.add_child(_input_field)

		_resize_handle = Panel.new()
		_resize_handle.mouse_filter = Control.MOUSE_FILTER_STOP as Control.MouseFilter
		_resize_handle.mouse_default_cursor_shape = Control.CURSOR_FDIAGSIZE
		_resize_handle.visible = false
		_connect_signal(_resize_handle.gui_input, _on_resize_handle_gui_input)
		var resize_style: StyleBoxFlat = StyleBoxFlat.new()
		resize_style.bg_color = Color(0.4, 0.8, 1.0, 0.45)
		_resize_handle.add_theme_stylebox_override("panel", resize_style)
		add_child(_resize_handle)

		_layout_console()


	func _ready() -> void:
		_apply_layer()
		_apply_background_alpha()
		_layout_console()


	func _input(event: InputEvent) -> void:
		if visible and (_dragging or _resizing):
			_update_window_interaction(event)
			get_viewport().set_input_as_handled()
			return

		if event is InputEventKey:
			var key_event: InputEventKey = event
			if not key_event.pressed or key_event.echo:
				return
			if key_event.keycode == toggle_key:
				visible = not visible
				if visible:
					_layout_console()
					_input_field.call_deferred("grab_focus")
				get_viewport().set_input_as_handled()
			elif visible and _input_field.has_focus() and key_event.keycode == KEY_UP:
				_show_previous_history()
				get_viewport().set_input_as_handled()
			elif visible and _input_field.has_focus() and key_event.keycode == KEY_DOWN:
				_show_next_history()
				get_viewport().set_input_as_handled()
			elif visible and _input_field.has_focus() and key_event.keycode == KEY_TAB:
				_apply_command_completion()
				get_viewport().set_input_as_handled()


	# --- 公共方法 ---

	## 向控制台输出追加一行文本。
	## [br]
	## @api framework_internal
	## [br]
	## @param bbcode_line: 要追加的一行 BBCode 文本。
	func append_text(bbcode_line: String) -> void:
		_append_packed_string(_pending_lines, bbcode_line)
		_queue_flush()


	## 向控制台输出追加多行文本。
	## [br]
	## @api framework_internal
	## [br]
	## @param bbcode_lines: 要追加的 BBCode 文本行列表。
	func append_lines(bbcode_lines: PackedStringArray) -> void:
		for bbcode_line: String in bbcode_lines:
			_append_packed_string(_pending_lines, bbcode_line)
		_queue_flush()


	## 清空控制台输出。
	## [br]
	## @api framework_internal
	func clear_output() -> void:
		_output_lines.clear()
		_pending_lines.clear()
		_flush_queued = false
		_output.clear()


	## 立即刷新待追加的控制台输出。
	## [br]
	## @api framework_internal
	func flush_output() -> void:
		_flush_pending_lines()


	## 检查日志标签是否被忽略。
	## [br]
	## @api framework_internal
	## [br]
	## @param tag: 日志标签。
	## [br]
	## @return 被忽略返回 true。
	func is_tag_ignored(tag: String) -> bool:
		if _ignored_tags.is_empty():
			return false

		return _ignored_tags.has(tag)


	## 获取 GUI 调试快照。
	## [br]
	## @api framework_internal
	## [br]
	## @return GUI 输出、历史、布局和配置状态。
	## [br]
	## @schema return: Dictionary，包含 visible、layer、output_lines、pending_line_count、command_history、background_alpha、windowed、resize_handle_visible、panel_size、panel_background_alpha。
	func get_debug_snapshot() -> Dictionary:
		return {
			"visible": visible,
			"layer": layer,
			"output_lines": _output_lines.duplicate(),
			"pending_line_count": _pending_lines.size(),
			"command_history": _command_history.duplicate(),
			"history_index": _history_index,
			"background_alpha": background_alpha,
			"windowed": windowed,
			"resize_handle_visible": _resize_handle.visible if is_instance_valid(_resize_handle) else false,
			"panel_size": _panel.size if is_instance_valid(_panel) else Vector2.ZERO,
			"panel_background_alpha": _panel_style.bg_color.a if _panel_style != null else 0.0,
			"max_output_lines": max_output_lines,
			"max_history_size": max_history_size,
			"keep_topmost": keep_topmost,
		}


	# --- 私有/辅助方法 ---

	func _apply_layer() -> void:
		layer = _TOPMOST_LAYER if keep_topmost else _DEFAULT_LAYER


	func _apply_background_alpha() -> void:
		if _panel_style == null:
			return

		var color: Color = _panel_style.bg_color
		color.a = background_alpha
		_panel_style.bg_color = color


	func _layout_console() -> void:
		if not is_instance_valid(_panel):
			return

		if not windowed:
			_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			_panel.position = Vector2.ZERO
			_window_layout_initialized = false
			if is_instance_valid(_resize_handle):
				_resize_handle.visible = false
			return

		_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
		if not _window_layout_initialized:
			var viewport_size: Vector2 = _get_viewport_size()
			var target_size: Vector2 = Vector2(
				viewport_size.x * initial_window_size_ratio.x,
				viewport_size.y * initial_window_size_ratio.y
			)
			_panel.position = Vector2(_WINDOW_MARGIN, _WINDOW_MARGIN)
			_panel.size = _get_clamped_window_size(target_size)
			_window_layout_initialized = true
		else:
			_panel.size = _get_clamped_window_size(_panel.size)

		_clamp_panel_rect()
		_sync_resize_handle()


	func _get_viewport_size() -> Vector2:
		var viewport: Viewport = get_viewport()
		if viewport == null:
			return Vector2.ZERO

		var viewport_rect: Rect2 = viewport.get_visible_rect()
		return Vector2(viewport_rect.size.x, viewport_rect.size.y)


	func _get_clamped_window_size(requested_size: Vector2) -> Vector2:
		var viewport_size: Vector2 = _get_viewport_size()
		if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
			return minimum_window_size

		var max_size: Vector2 = Vector2(
			maxf(1.0, viewport_size.x - _WINDOW_MARGIN * 2.0),
			maxf(1.0, viewport_size.y - _WINDOW_MARGIN * 2.0)
		)
		var min_size: Vector2 = Vector2(
			minf(minimum_window_size.x, max_size.x),
			minf(minimum_window_size.y, max_size.y)
		)
		return Vector2(
			clampf(requested_size.x, min_size.x, max_size.x),
			clampf(requested_size.y, min_size.y, max_size.y)
		)


	func _clamp_panel_rect() -> void:
		if not is_instance_valid(_panel):
			return

		_panel.size = _get_clamped_window_size(_panel.size)
		var viewport_size: Vector2 = _get_viewport_size()
		var max_position: Vector2 = viewport_size - _panel.size - Vector2(_WINDOW_MARGIN, _WINDOW_MARGIN)
		var safe_max_position: Vector2 = Vector2(
			maxf(_WINDOW_MARGIN, max_position.x),
			maxf(_WINDOW_MARGIN, max_position.y)
		)
		_panel.position = Vector2(
			clampf(_panel.position.x, _WINDOW_MARGIN, safe_max_position.x),
			clampf(_panel.position.y, _WINDOW_MARGIN, safe_max_position.y)
		)


	func _sync_resize_handle() -> void:
		if not is_instance_valid(_resize_handle) or not is_instance_valid(_panel):
			return

		_resize_handle.visible = windowed
		_resize_handle.position = _panel.position + _panel.size - Vector2(_RESIZE_HANDLE_SIZE, _RESIZE_HANDLE_SIZE)
		_resize_handle.size = Vector2(_RESIZE_HANDLE_SIZE, _RESIZE_HANDLE_SIZE)


	func _update_window_interaction(event: InputEvent) -> void:
		if event is InputEventMouseButton:
			var button_event: InputEventMouseButton = event
			if button_event.button_index == MOUSE_BUTTON_LEFT and not button_event.pressed:
				_dragging = false
				_resizing = false
				return

		if not (event is InputEventMouseMotion):
			return

		var mouse_position: Vector2 = get_viewport().get_mouse_position()
		if _dragging:
			_panel.position = mouse_position - _drag_offset
			_clamp_panel_rect()
			_sync_resize_handle()
		elif _resizing:
			_panel.size = _resize_origin_size + mouse_position - _resize_origin_mouse
			_clamp_panel_rect()
			_sync_resize_handle()


	func _queue_flush() -> void:
		if _flush_queued:
			return

		_flush_queued = true
		call_deferred("_flush_pending_lines")


	func _flush_pending_lines() -> void:
		_flush_queued = false
		if _pending_lines.is_empty():
			return

		for line: String in _pending_lines:
			_append_packed_string(_output_lines, line)
		_pending_lines.clear()
		_trim_output_lines()
		_render_output()


	func _trim_output_lines() -> void:
		var max_lines: int = maxi(max_output_lines, 1)
		while _output_lines.size() > max_lines:
			_output_lines.remove_at(0)


	func _render_output() -> void:
		_output.clear()
		if _output_lines.is_empty():
			return

		_output.append_text("\n".join(_output_lines) + "\n")


	func _show_previous_history() -> void:
		if _command_history.is_empty():
			return
		if _history_index < 0:
			_history_index = _command_history.size() - 1
		else:
			_history_index = maxi(_history_index - 1, 0)
		_set_input_text(_command_history[_history_index])


	func _show_next_history() -> void:
		if _command_history.is_empty() or _history_index < 0:
			return
		_history_index += 1
		if _history_index >= _command_history.size():
			_history_index = -1
			_set_input_text("")
			return
		_set_input_text(_command_history[_history_index])


	func _apply_command_completion() -> void:
		if not command_name_provider.is_valid():
			return

		var text: String = _input_field.text
		var parts: PackedStringArray = text.split(" ", false)
		var prefix: String = parts[0] if parts.size() > 0 else text
		var names_variant: Variant = command_name_provider.call()
		var names: PackedStringArray = PackedStringArray()
		if names_variant is PackedStringArray:
			names = names_variant
		elif names_variant is Array:
			for name_variant: Variant in names_variant:
				_append_packed_string(names, GFVariantData.to_text(name_variant))

		var matches: PackedStringArray = PackedStringArray()
		for cmd_name: String in names:
			if cmd_name.begins_with(prefix):
				_append_packed_string(matches, cmd_name)
		if matches.size() == 1:
			_set_input_text(matches[0] + " ")
		elif matches.size() > 1:
			append_text("[color=cyan]%s[/color]" % GFConsoleUtility._escape_bbcode_string(", ".join(matches)))


	func _trim_command_history() -> void:
		var max_size: int = maxi(max_history_size, 1)
		while _command_history.size() > max_size:
			_command_history.remove_at(0)
		if _history_index >= _command_history.size():
			_history_index = -1


	func _set_input_text(text: String) -> void:
		_input_field.text = text
		_input_field.caret_column = text.length()


	# --- 信号处理函数 ---

	func _on_input_submitted(text: String) -> void:
		if text.strip_edges().is_empty():
			return

		_append_packed_string(_command_history, text)
		_trim_command_history()
		_history_index = -1
		command_submitted.emit(text)
		_input_field.clear()


	func _on_filter_changed(text: String) -> void:
		if text.is_empty():
			_ignored_tags.clear()
		else:
			_ignored_tags = text.replace(" ", "").split(",", false)


	func _on_header_gui_input(event: InputEvent) -> void:
		if not windowed or not is_instance_valid(_panel):
			return

		if event is InputEventMouseButton:
			var button_event: InputEventMouseButton = event
			if button_event.button_index != MOUSE_BUTTON_LEFT:
				return
			_dragging = button_event.pressed
			_resizing = false
			if _dragging:
				_drag_offset = get_viewport().get_mouse_position() - _panel.position
			get_viewport().set_input_as_handled()
		elif event is InputEventMouseMotion and _dragging:
			_update_window_interaction(event)
			get_viewport().set_input_as_handled()


	func _on_resize_handle_gui_input(event: InputEvent) -> void:
		if not windowed or not is_instance_valid(_panel):
			return

		if event is InputEventMouseButton:
			var button_event: InputEventMouseButton = event
			if button_event.button_index != MOUSE_BUTTON_LEFT:
				return
			_resizing = button_event.pressed
			_dragging = false
			if _resizing:
				_resize_origin_mouse = get_viewport().get_mouse_position()
				_resize_origin_size = _panel.size
			get_viewport().set_input_as_handled()
		elif event is InputEventMouseMotion and _resizing:
			_update_window_interaction(event)
			get_viewport().set_input_as_handled()
