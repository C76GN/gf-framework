## GFDiagnosticsUtility: 运行时诊断聚合工具。
##
## 提供架构生命周期、事件系统、性能、日志和外部贡献诊断的统一快照。
## 外部监控和快照贡献采用 owner-bound 发布模型；采集路径只读取已验证缓存，不执行项目回调。
## [br]
## @api public
## [br]
## @category runtime_service
## [br]
## @since 3.17.0
class_name GFDiagnosticsUtility
extends GFUtility


# --- 信号 ---

## 采集快照后发出。
## [br]
## @api public
## [br]
## @param snapshot: 刚采集到的诊断快照。
## [br]
## @schema snapshot: Dictionary，包含 collect_snapshot() 返回的顶层诊断分区。
signal snapshot_collected(snapshot: Dictionary)

## 执行诊断命令后发出。
## [br]
## @api public
## [br]
## @param command_name: 已执行的诊断命令名。
## [br]
## @param result: 命令执行结果。
## [br]
## @schema result: Dictionary，包含 ok、value、error、metadata 等字段。
signal diagnostic_command_executed(command_name: StringName, result: Dictionary)

## 采样诊断监控项后发出。
## [br]
## @api public
## [br]
## @param monitor_id: 监控项标识。
## [br]
## @param sample: 采样结果。
## [br]
## @schema sample: Dictionary，包含 id、label、group、value、valid、error、metadata 和 sampled_at_unix。
signal monitor_sampled(monitor_id: StringName, sample: Dictionary)


# --- 枚举 ---

## 诊断命令风险等级。
## [br]
## @api public
enum CommandTier {
	## 只读取状态。
	OBSERVE,
	## 修改调试输入或临时过滤条件。
	INPUT,
	## 控制运行时行为。
	CONTROL,
	## 可能破坏状态、存档或远端连接。
	DANGER,
}


# --- 常量 ---

## EditorDebugger 与运行时诊断桥使用的 capture 名称。
## [br]
## @api public
## [br]
## @since 6.0.0
const DEBUGGER_CAPTURE_NAME: StringName = &"gf_diagnostics"

## EditorDebugger 请求快照消息。
## [br]
## @api public
## [br]
## @since 6.0.0
const DEBUGGER_MESSAGE_REQUEST_SNAPSHOT: String = "gf_diagnostics:request_snapshot"

## EditorDebugger 请求目录消息。
## [br]
## @api public
## [br]
## @since 6.0.0
const DEBUGGER_MESSAGE_REQUEST_CATALOG: String = "gf_diagnostics:request_catalog"

## EditorDebugger 执行诊断命令消息。
## [br]
## @api public
## [br]
## @since 6.0.0
const DEBUGGER_MESSAGE_EXECUTE_COMMAND: String = "gf_diagnostics:execute_command"

## 运行时返回快照消息。
## [br]
## @api public
## [br]
## @since 6.0.0
const DEBUGGER_MESSAGE_SNAPSHOT: String = "gf_diagnostics:snapshot"

## 运行时返回目录消息。
## [br]
## @api public
## [br]
## @since 6.0.0
const DEBUGGER_MESSAGE_CATALOG: String = "gf_diagnostics:catalog"

## 运行时返回命令结果消息。
## [br]
## @api public
## [br]
## @since 6.0.0
const DEBUGGER_MESSAGE_COMMAND_RESULT: String = "gf_diagnostics:command_result"


# --- 公共变量 ---

## 是否采集 Godot Performance 监视器。
## [br]
## @api public
var include_performance_monitors: bool = true

## 快照中默认包含的最近日志数量。
## [br]
## @api public
var default_recent_log_count: int = 20

## 当前允许执行的最高命令等级。
## [br]
## @api public
var max_command_tier: CommandTier = CommandTier.OBSERVE

## 是否要求命令参数提供 auth_token 或 _auth_token。
## [br]
## @api public
var require_auth_token: bool = false

## 诊断命令认证 token。为空时无法通过认证。
## [br]
## @api public
var auth_token: String = ""

## 是否允许 EditorDebugger 桥执行诊断命令。
## [br]
## @api public
## [br]
## @since 6.0.0
var allow_debugger_command_execution: bool = false

## 是否允许执行 DANGER 等级命令。即使 max_command_tier 足够，也需要显式开启。
## [br]
## @api public
var allow_danger_commands: bool = false

## 是否把诊断命令结果转换为 JSON 兼容 Variant。
## [br]
## @api public
var encode_command_results_for_json: bool = false

## 场景树快照默认递归深度。
## [br]
## @api public
var default_scene_tree_max_depth: int = 4

## 场景树快照默认最多采集节点数。
## [br]
## @api public
var default_scene_tree_max_nodes: int = 128

## 外部诊断贡献的单个容器最多包含的元素数量。
## [br]
## @api public
## [br]
## @since 8.0.0
var max_contribution_collection_items: int = 64:
	set(value):
		max_contribution_collection_items = maxi(value, 0)

## 外部诊断贡献最多包含的 Variant 节点数量。
## [br]
## @api public
## [br]
## @since 8.0.0
var max_contribution_nodes: int = 2048:
	set(value):
		max_contribution_nodes = maxi(value, 0)

## 外部诊断贡献允许的最大集合嵌套深度。
## [br]
## @api public
## [br]
## @since 8.0.0
var max_contribution_depth: int = 16:
	set(value):
		max_contribution_depth = maxi(value, 0)

## 外部诊断贡献允许保留的估算字节数。
## [br]
## 该预算用于阻止诊断系统长期保留异常大的字符串、PackedArray 或集合，不代表精确内存占用。
## [br]
## @api public
## [br]
## @since 8.0.0
var max_contribution_bytes: int = 262_144:
	set(value):
		max_contribution_bytes = maxi(value, 0)


# --- 私有变量 ---

var _commands: Dictionary = {}
var _disabled_commands: Dictionary = {}
var _monitors: Dictionary = {}
var _monitor_presets: Dictionary = {}
var _snapshot_sections: Dictionary = {}
var _tool_snapshots: Dictionary = {}
var _monitor_order_counter: int = 0
var _console_utility: GFConsoleUtility = null
var _console_command_subscription: GFLifetimeSubscription = null
var _debugger_capture_registered: bool = false


# --- GF 生命周期方法 ---

## 初始化内置诊断命令和监控项。
## [br]
## @api public
func init() -> void:
	_register_builtin_monitors()
	var _snapshot_command_registered: bool = register_command(self, &"diagnostics.snapshot", Callable(self, "_command_collect_snapshot"), "采集 GF 诊断快照。", CommandTier.OBSERVE)
	var _performance_command_registered: bool = register_command(self, &"diagnostics.performance", Callable(self, "_command_collect_performance"), "采集性能监视器快照。", CommandTier.OBSERVE)
	var _logs_command_registered: bool = register_command(self, &"diagnostics.logs", Callable(self, "_command_collect_logs"), "读取最近日志缓存。", CommandTier.OBSERVE)
	var _monitors_command_registered: bool = register_command(self, &"diagnostics.monitors", Callable(self, "_command_collect_monitors"), "采集已注册诊断监控项。", CommandTier.OBSERVE)
	var _tools_command_registered: bool = register_command(self, &"diagnostics.tools", Callable(self, "_command_collect_tools"), "采集已注册 GF 工具快照。", CommandTier.OBSERVE)
	var _scene_command_registered: bool = register_command(self, &"diagnostics.scene", Callable(self, "_command_collect_scene"), "采集只读场景树快照。", CommandTier.OBSERVE)
	var _signals_command_registered: bool = register_command(self, &"diagnostics.signals", Callable(self, "_command_collect_signals"), "采集只读信号连接图快照。", CommandTier.OBSERVE)
	_register_debugger_capture()


## 绑定控制台诊断命令。
## [br]
## @api public
func ready() -> void:
	_bind_console_command()


## 释放诊断注册表并解绑控制台命令。
## [br]
## @api public
func dispose() -> void:
	_unregister_debugger_capture()
	if _console_command_subscription != null:
		var _console_subscription_cancelled: bool = _console_command_subscription.cancel()
	_console_utility = null
	_console_command_subscription = null
	_commands.clear()
	_disabled_commands.clear()
	_monitors.clear()
	_monitor_presets.clear()
	_snapshot_sections.clear()
	_tool_snapshots.clear()
	_monitor_order_counter = 0


# --- 公共方法 ---

## 注册诊断命令。
## [br]
## @api public
## [br]
## @since 3.0.0
## [br]
## @param owner: 命令注册所有者；同名命令只允许同一 owner 更新。
## [br]
## @param command_name: 命令名。
## [br]
## @param callback: 回调，签名建议为 func(args: Dictionary) -> Variant。
## [br]
## @param description: 描述文本。
## [br]
## @param tier: 命令风险等级。
## [br]
## @param options: 可选元数据，支持 parameters、metadata、enabled。
## [br]
## @return 注册成功返回 true；同名命令属于其他 owner 时返回 false。
## [br]
## @schema options: Dictionary，支持 parameters、metadata 和 enabled。
func register_command(
	owner: Object,
	command_name: StringName,
	callback: Callable,
	description: String = "",
	tier: CommandTier = CommandTier.OBSERVE,
	options: Dictionary = {}
) -> bool:
	if owner == null or command_name == &"" or not callback.is_valid():
		return false
	if not _can_register_owned_entry(_commands, command_name, owner):
		return false
	_commands[command_name] = {
		"owner_ref": weakref(owner),
		"owner_instance_id": owner.get_instance_id(),
		"callback": callback,
		"description": description,
		"tier": tier,
		"parameters": _normalize_parameter_schema(GFVariantData.get_option_value(options, "parameters", [])),
		"metadata": GFVariantData.get_option_dictionary(options, "metadata"),
	}
	if options.has("enabled"):
		var _enabled_updated: bool = set_command_enabled(
			command_name,
			GFVariantData.get_option_bool(options, "enabled", true)
		)
	return true


## 注销诊断命令。
## [br]
## @api public
## [br]
## @since 3.0.0
## [br]
## @param owner: 当前命令注册所有者。
## [br]
## @param command_name: 命令名。
## [br]
## @return owner 匹配且成功注销时返回 true。
func unregister_command(owner: Object, command_name: StringName) -> bool:
	if not _owned_entry_matches(_commands, command_name, owner):
		return false
	var _command_erased: bool = _commands.erase(command_name)
	var _disabled_erased: bool = _disabled_commands.erase(command_name)
	return _command_erased


## 检查诊断命令是否存在。
## [br]
## @api public
## [br]
## @param command_name: 命令名。
## [br]
## @return 存在返回 true。
func has_command(command_name: StringName) -> bool:
	return _command_registration_is_live(command_name)


## 设置诊断命令参数 schema。
## [br]
## @api public
## [br]
## @param command_name: 命令名。
## [br]
## @param parameters: 参数 schema，可为数组或按参数名索引的字典。
## [br]
## @return 设置成功返回 true。
## [br]
## @schema parameters: Variant，支持 Array[Dictionary] 或 Dictionary 形式的参数 schema。
func set_command_parameter_schema(command_name: StringName, parameters: Variant) -> bool:
	if not _command_registration_is_live(command_name):
		return false
	var entry: Dictionary = _get_dictionary_entry(_commands, command_name)
	entry["parameters"] = _normalize_parameter_schema(parameters)
	_commands[command_name] = entry
	return true


## 设置诊断命令是否启用。
## [br]
## @api public
## [br]
## @param command_name: 命令名。
## [br]
## @param enabled: 是否启用。
## [br]
## @return 命令存在时返回 true。
func set_command_enabled(command_name: StringName, enabled: bool) -> bool:
	if not _command_registration_is_live(command_name):
		return false
	if enabled:
		var _disabled_erased: bool = _disabled_commands.erase(command_name)
	else:
		_disabled_commands[command_name] = true
	return true


## 批量设置命令是否启用。
## [br]
## @api public
## [br]
## @param enabled: 是否启用。
## [br]
## @param command_names: 指定命令；为空时作用于全部已注册命令。
## [br]
## @return 实际处理的命令数量。
func set_all_commands_enabled(
	enabled: bool,
	command_names: PackedStringArray = PackedStringArray()
) -> int:
	_prune_released_commands()
	var selected_names: PackedStringArray = command_names.duplicate()
	if selected_names.is_empty():
		for command_name: StringName in _commands.keys():
			var _name_appended: bool = selected_names.append(String(command_name))

	var count: int = 0
	for name_text: String in selected_names:
		if set_command_enabled(StringName(name_text), enabled):
			count += 1
	return count


## 检查命令是否启用。
## [br]
## @api public
## [br]
## @param command_name: 命令名。
## [br]
## @return 命令存在且启用时返回 true。
func is_command_enabled(command_name: StringName) -> bool:
	return _command_registration_is_live(command_name) and not _disabled_commands.has(command_name)


## 获取诊断命令描述。
## [br]
## @api public
## [br]
## @return 命令名到描述的字典。
## [br]
## @schema return: Dictionary[StringName, String]，以命令名为键。
func get_command_descriptions() -> Dictionary:
	_prune_released_commands()
	var result: Dictionary = {}
	for command_name: StringName in _commands.keys():
		var entry: Dictionary = _get_dictionary_entry(_commands, command_name)
		result[command_name] = GFVariantData.get_option_string(entry, "description")
	return result


## 获取诊断命令目录。
## [br]
## @api public
## [br]
## @return 命令名到命令元数据的字典。
## [br]
## @schema return: Dictionary[StringName, Dictionary]，每个值包含 description、tier、tier_name、enabled、parameters 和 metadata。
func get_command_catalog() -> Dictionary:
	_prune_released_commands()
	var result: Dictionary = {}
	for command_name: StringName in _commands.keys():
		var entry: Dictionary = _get_dictionary_entry(_commands, command_name)
		var tier: int = GFVariantData.get_option_int(entry, "tier", CommandTier.OBSERVE)
		result[command_name] = {
			"description": GFVariantData.get_option_string(entry, "description"),
			"tier": tier,
			"tier_name": _get_tier_name(tier),
			"enabled": is_command_enabled(command_name),
			"parameters": GFVariantData.get_option_array(entry, "parameters"),
			"metadata": GFVariantData.get_option_dictionary(entry, "metadata"),
		}
	return result


## 注册一个由 owner 主动发布采样值的诊断监控项。
## [br]
## @api public
## [br]
## @since 3.0.0
## [br]
## @param owner: 监控项注册所有者；同名监控项只允许同一 owner 更新。
## [br]
## @param monitor_id: 监控项唯一标识。
## [br]
## @param options: 可选元数据，支持 label、group、visible 和 metadata。
## [br]
## @return 注册成功返回 true。
## [br]
## @schema options: Dictionary，支持 label、group、visible 和 metadata。
func register_monitor(owner: Object, monitor_id: StringName, options: Dictionary = {}) -> bool:
	if owner == null or monitor_id == &"":
		return false
	if not _can_register_owned_entry(_monitors, monitor_id, owner):
		return false

	var existing_entry: Dictionary = _get_dictionary_entry(_monitors, monitor_id)
	var order: int = GFVariantData.get_option_int(existing_entry, "order", _monitor_order_counter)
	var entry: Dictionary = {
		"owner_ref": weakref(owner),
		"owner_instance_id": owner.get_instance_id(),
		"label": GFVariantData.get_option_string(options, "label", String(monitor_id)),
		"group": GFVariantData.get_option_string(options, "group", "Runtime"),
		"visible": GFVariantData.get_option_bool(options, "visible", true),
		"metadata": GFVariantData.get_option_dictionary(options, "metadata"),
		"order": order,
		"has_published_value": GFVariantData.get_option_bool(existing_entry, "has_published_value"),
		"published_value": GFVariantData.get_option_value(existing_entry, "published_value"),
		"published_metadata": GFVariantData.get_option_dictionary(existing_entry, "published_metadata"),
		"published_at_unix": GFVariantData.get_option_float(existing_entry, "published_at_unix", 0.0),
	}
	if existing_entry.is_empty():
		_monitor_order_counter += 1
	_monitors[monitor_id] = entry
	return true


## 发布一个监控采样值。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param owner: 当前监控项注册所有者。
## [br]
## @param monitor_id: 监控项唯一标识。
## [br]
## @param value: 要缓存的采样值；采集阶段不会执行该值中的 Callable。
## [br]
## @param sample_metadata: 本次采样元数据。
## [br]
## @return owner 匹配且值通过贡献预算时返回 true；失败时保留上一份有效采样。
## [br]
## @schema value: 任意 Variant 报告值；写入前由 GFReportValueCodec 编码，循环引用或超出诊断贡献预算时拒绝。
## [br]
## @schema sample_metadata: JSON 兼容 Dictionary。
func publish_monitor_sample(
	owner: Object,
	monitor_id: StringName,
	value: Variant,
	sample_metadata: Dictionary = {}
) -> bool:
	if not _owned_entry_matches(_monitors, monitor_id, owner):
		return false
	var prepared_value: Dictionary = _prepare_contribution_value(value)
	if not GFVariantData.get_option_bool(prepared_value, "ok"):
		return false
	var prepared_metadata: Dictionary = _prepare_contribution_value(sample_metadata)
	if not GFVariantData.get_option_bool(prepared_metadata, "ok"):
		return false

	var entry: Dictionary = _get_dictionary_entry(_monitors, monitor_id)
	entry["has_published_value"] = true
	entry["published_value"] = GFVariantData.get_option_value(prepared_value, "value")
	entry["published_metadata"] = GFVariantData.get_option_dictionary(prepared_metadata, "value")
	entry["published_at_unix"] = Time.get_unix_time_from_system()
	_monitors[monitor_id] = entry
	monitor_sampled.emit(monitor_id, _sample_monitor(monitor_id, entry))
	return true


## 注销诊断监控项。
## [br]
## @api public
## [br]
## @since 3.0.0
## [br]
## @param owner: 当前监控项注册所有者。
## [br]
## @param monitor_id: 监控项唯一标识。
## [br]
## @return owner 匹配且成功注销时返回 true。
func unregister_monitor(owner: Object, monitor_id: StringName) -> bool:
	if not _owned_entry_matches(_monitors, monitor_id, owner):
		return false
	var _monitor_erased: bool = _monitors.erase(monitor_id)
	for preset_id: StringName in _monitor_presets.keys():
		var preset: Dictionary = _get_dictionary_entry(_monitor_presets, preset_id)
		var ids: PackedStringArray = GFVariantData.get_option_packed_string_array(preset, "monitor_ids")
		var monitor_index: int = ids.find(String(monitor_id))
		if monitor_index >= 0:
			ids.remove_at(monitor_index)
			preset["monitor_ids"] = ids
			_monitor_presets[preset_id] = preset
	return _monitor_erased


## 检查诊断监控项是否存在。
## [br]
## @api public
## [br]
## @param monitor_id: 监控项唯一标识。
## [br]
## @return 存在返回 true。
func has_monitor(monitor_id: StringName) -> bool:
	return _owned_registry_has_live_entry(_monitors, monitor_id)


## 获取诊断监控项目录。
## [br]
## @api public
## [br]
## @since 3.0.0
## [br]
## @return 监控项元数据字典。
## [br]
## @schema return: Dictionary[StringName, Dictionary]，每个值包含 label、group、visible、metadata 和 has_published_value。
func get_monitor_catalog() -> Dictionary:
	_prune_released_owned_entries(_monitors)
	var result: Dictionary = {}
	for monitor_id: StringName in _monitors.keys():
		var entry: Dictionary = _get_dictionary_entry(_monitors, monitor_id)
		result[monitor_id] = {
			"label": GFVariantData.get_option_string(entry, "label", String(monitor_id)),
			"group": GFVariantData.get_option_string(entry, "group", "Runtime"),
			"visible": GFVariantData.get_option_bool(entry, "visible", true),
			"metadata": GFVariantData.get_option_dictionary(entry, "metadata"),
			"has_published_value": GFVariantData.get_option_bool(entry, "has_published_value"),
		}
	return result


## 注册诊断监控预设。
## [br]
## @api public
## [br]
## @param preset_id: 预设唯一标识。
## [br]
## @param monitor_ids: 预设包含的监控项标识。
## [br]
## @param options: 可选元数据，支持 label、metadata。
## [br]
## @return 注册成功返回 true。
## [br]
## @schema options: Dictionary，支持 label 和 metadata。
func register_monitor_preset(
	preset_id: StringName,
	monitor_ids: PackedStringArray,
	options: Dictionary = {}
) -> bool:
	if preset_id == &"":
		return false

	_monitor_presets[preset_id] = {
		"monitor_ids": monitor_ids.duplicate(),
		"label": GFVariantData.get_option_string(options, "label", String(preset_id)),
		"metadata": GFVariantData.get_option_dictionary(options, "metadata"),
	}
	return true


## 将一个监控项追加到已有预设；预设不存在时会创建。
## [br]
## @api public
## [br]
## @param preset_id: 预设唯一标识。
## [br]
## @param monitor_id: 监控项唯一标识。
## [br]
## @return 追加成功返回 true。
func add_monitor_to_preset(preset_id: StringName, monitor_id: StringName) -> bool:
	if preset_id == &"" or monitor_id == &"":
		return false
	if not _monitor_presets.has(preset_id):
		return register_monitor_preset(preset_id, PackedStringArray([String(monitor_id)]))

	var preset: Dictionary = _get_dictionary_entry(_monitor_presets, preset_id)
	var ids: PackedStringArray = GFVariantData.get_option_packed_string_array(preset, "monitor_ids")
	if not ids.has(String(monitor_id)):
		var _monitor_appended: bool = ids.append(String(monitor_id))
		preset["monitor_ids"] = ids
		_monitor_presets[preset_id] = preset
	return true


## 注销诊断监控预设。
## [br]
## @api public
## [br]
## @param preset_id: 预设唯一标识。
func unregister_monitor_preset(preset_id: StringName) -> void:
	var _preset_erased: bool = _monitor_presets.erase(preset_id)


## 检查诊断监控预设是否存在。
## [br]
## @api public
## [br]
## @param preset_id: 预设唯一标识。
## [br]
## @return 存在返回 true。
func has_monitor_preset(preset_id: StringName) -> bool:
	return _monitor_presets.has(preset_id)


## 获取诊断监控预设列表。
## [br]
## @api public
## [br]
## @return 预设标识列表。
func get_monitor_preset_ids() -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	for preset_id: StringName in _monitor_presets.keys():
		var _preset_appended: bool = result.append(String(preset_id))
	result.sort()
	return result


## 发布快照分区。用于扩展或项目把自己的诊断数据贡献到 collect_snapshot() 顶层字段。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param owner: 分区所有者；同名分区只允许同一 owner 更新。
## [br]
## @param section_id: 快照顶层字段名。
## [br]
## @param section: 要缓存的分区快照，必须满足诊断贡献预算。
## [br]
## @return 注册成功返回 true。
## [br]
## @schema section: Dictionary 报告快照；写入前由 GFReportValueCodec 编码，循环引用或超出诊断贡献预算时拒绝。
func publish_snapshot_section(owner: Object, section_id: StringName, section: Dictionary) -> bool:
	if owner == null or section_id == &"":
		return false
	if _is_reserved_snapshot_section_id(section_id):
		push_warning("[GFDiagnosticsUtility] 快照分区使用了保留字段，已拒绝：%s。" % String(section_id))
		return false
	if not _can_register_owned_entry(_snapshot_sections, section_id, owner):
		return false
	var prepared: Dictionary = _prepare_contribution_value(section)
	if not GFVariantData.get_option_bool(prepared, "ok"):
		return false
	_snapshot_sections[section_id] = {
		"owner_ref": weakref(owner),
		"owner_instance_id": owner.get_instance_id(),
		"snapshot": GFVariantData.get_option_dictionary(prepared, "value"),
		"published_at_unix": Time.get_unix_time_from_system(),
	}
	return true


## 移除快照分区。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param owner: 当前分区所有者。
## [br]
## @param section_id: 快照顶层字段名。
## [br]
## @return owner 匹配且成功注销时返回 true。
func remove_snapshot_section(owner: Object, section_id: StringName) -> bool:
	if not _owned_entry_matches(_snapshot_sections, section_id, owner):
		return false
	return _snapshot_sections.erase(section_id)


## 检查快照分区是否存在。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param section_id: 快照顶层字段名。
## [br]
## @return 存在返回 true。
func has_snapshot_section(section_id: StringName) -> bool:
	return _owned_registry_has_live_entry(_snapshot_sections, section_id)


## 发布工具快照。用于扩展或项目把 get_debug_snapshot() 风格数据贡献到 tools 字段。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param owner: 快照所有者；同名工具只允许同一 owner 更新。
## [br]
## @param tool_id: tools 内部字段名。
## [br]
## @param snapshot: 要缓存的工具快照，必须满足诊断贡献预算。
## [br]
## @return 注册成功返回 true。
## [br]
## @schema snapshot: Dictionary 报告快照；写入前由 GFReportValueCodec 编码，循环引用或超出诊断贡献预算时拒绝。
func publish_tool_snapshot(owner: Object, tool_id: StringName, snapshot: Dictionary) -> bool:
	if owner == null or tool_id == &"":
		return false
	if _is_builtin_tool_snapshot_id(tool_id):
		push_warning("[GFDiagnosticsUtility] 工具快照使用了内置字段，已拒绝：%s。" % String(tool_id))
		return false
	if not _can_register_owned_entry(_tool_snapshots, tool_id, owner):
		return false
	var prepared: Dictionary = _prepare_contribution_value(snapshot)
	if not GFVariantData.get_option_bool(prepared, "ok"):
		return false
	_tool_snapshots[tool_id] = {
		"owner_ref": weakref(owner),
		"owner_instance_id": owner.get_instance_id(),
		"snapshot": GFVariantData.get_option_dictionary(prepared, "value"),
		"published_at_unix": Time.get_unix_time_from_system(),
	}
	return true


## 移除工具快照。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param owner: 当前快照所有者。
## [br]
## @param tool_id: tools 内部字段名。
## [br]
## @return owner 匹配且成功注销时返回 true。
func remove_tool_snapshot(owner: Object, tool_id: StringName) -> bool:
	if not _owned_entry_matches(_tool_snapshots, tool_id, owner):
		return false
	return _tool_snapshots.erase(tool_id)


## 检查工具快照是否存在。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param tool_id: tools 内部字段名。
## [br]
## @return 存在返回 true。
func has_tool_snapshot(tool_id: StringName) -> bool:
	return _owned_registry_has_live_entry(_tool_snapshots, tool_id)


## 采集诊断监控快照。
## [br]
## @api public
## [br]
## @param monitor_ids: 指定监控项；为空时采集全部可见监控项。
## [br]
## @param include_hidden: 为 true 时包含 visible=false 的监控项。
## [br]
## @return 监控快照字典。
## [br]
## @schema return: Dictionary，包含 timestamp_unix、monitor_count 和 monitors。
func collect_monitor_snapshot(
	monitor_ids: PackedStringArray = PackedStringArray(),
	include_hidden: bool = false
) -> Dictionary:
	_prune_released_owned_entries(_monitors)
	var selected_ids: PackedStringArray = monitor_ids.duplicate()
	if selected_ids.is_empty():
		for monitor_id: StringName in _monitors.keys():
			var _monitor_appended: bool = selected_ids.append(String(monitor_id))

	selected_ids.sort()
	var monitors: Dictionary = {}
	for id_text: String in selected_ids:
		var monitor_id: StringName = StringName(id_text)
		if not _monitors.has(monitor_id):
			continue

		var entry: Dictionary = _get_dictionary_entry(_monitors, monitor_id)
		if not include_hidden and not GFVariantData.get_option_bool(entry, "visible", true):
			continue
		monitors[monitor_id] = _sample_monitor(monitor_id, entry)

	return {
		"timestamp_unix": Time.get_unix_time_from_system(),
		"monitor_count": monitors.size(),
		"monitors": monitors,
	}


## 按预设采集诊断监控快照。
## [br]
## @api public
## [br]
## @param preset_id: 预设唯一标识。
## [br]
## @param include_hidden: 为 true 时包含 visible=false 的监控项。
## [br]
## @return 监控快照字典。
## [br]
## @schema return: Dictionary，包含 collect_monitor_snapshot() 字段以及 preset_id、preset_label、preset_metadata。
func collect_monitor_preset(preset_id: StringName, include_hidden: bool = false) -> Dictionary:
	if not _monitor_presets.has(preset_id):
		return collect_monitor_snapshot(PackedStringArray(), include_hidden)

	var preset: Dictionary = _get_dictionary_entry(_monitor_presets, preset_id)
	var ids: PackedStringArray = GFVariantData.get_option_packed_string_array(preset, "monitor_ids")
	var snapshot: Dictionary = collect_monitor_snapshot(ids, include_hidden)
	snapshot["preset_id"] = preset_id
	snapshot["preset_label"] = GFVariantData.get_option_string(preset, "label", String(preset_id))
	snapshot["preset_metadata"] = GFVariantData.get_option_dictionary(preset, "metadata")
	return snapshot


## 导出诊断监控快照。
## [br]
## @api public
## [br]
## @param snapshot: collect_monitor_snapshot() 或 collect_monitor_preset() 返回值。
## [br]
## @param format: 导出格式，支持 json、text、csv。
## [br]
## @return 导出文本。
## [br]
## @schema snapshot: Dictionary，collect_monitor_snapshot() 或 collect_monitor_preset() 返回结构。
func export_monitor_snapshot(snapshot: Dictionary, format: StringName = &"json") -> String:
	match format:
		&"text":
			return _export_monitor_snapshot_as_text(snapshot)
		&"csv":
			return _export_monitor_snapshot_as_csv(snapshot)
		_:
			return GFReportValueCodec.stringify_json_compatible(snapshot, "\t")


## 设置诊断认证 token。
## [br]
## @api public
## [br]
## @param token: token 文本。
## [br]
## @param required: 是否立即启用 token 校验。
func set_auth_token(token: String, required: bool = true) -> void:
	auth_token = token
	require_auth_token = required


## 执行诊断命令。
## [br]
## @api public
## [br]
## @param command_name: 命令名。
## [br]
## @param args: 命令参数。
## [br]
## @return 统一结果字典。
## [br]
## @schema args: Dictionary，命令参数；可包含 auth_token 以及该命令 parameter_schema 定义的字段。
## [br]
## @schema return: Dictionary，包含 ok、value、error、metadata。
func execute_command(command_name: StringName, args: Dictionary = {}) -> Dictionary:
	if not _command_registration_is_live(command_name):
		var missing_result: Dictionary = _make_command_result(false, null, "Missing diagnostic command: %s" % String(command_name))
		diagnostic_command_executed.emit(command_name, missing_result)
		return missing_result

	var entry: Dictionary = _get_dictionary_entry(_commands, command_name)
	if _disabled_commands.has(command_name):
		var disabled_result: Dictionary = _make_command_result(false, null, "Diagnostic command is disabled: %s" % String(command_name))
		diagnostic_command_executed.emit(command_name, disabled_result)
		return disabled_result

	var tier: int = GFVariantData.get_option_int(entry, "tier", CommandTier.OBSERVE)
	if not _is_tier_allowed(tier):
		var tier_result: Dictionary = _make_command_result(false, null, "Diagnostic command tier is not allowed: %s" % _get_tier_name(tier), {
			"tier": tier,
			"tier_name": _get_tier_name(tier),
		})
		diagnostic_command_executed.emit(command_name, tier_result)
		return tier_result
	if not _is_auth_allowed(args):
		var auth_result: Dictionary = _make_command_result(false, null, "Diagnostic command authentication failed.", {
			"tier": tier,
			"tier_name": _get_tier_name(tier),
		})
		diagnostic_command_executed.emit(command_name, auth_result)
		return auth_result

	var prepared_args: Dictionary = _prepare_command_args(args, entry)
	var validation_report: GFValidationReport = _validate_command_args(entry, prepared_args, args)
	if not validation_report.is_ok():
		var validation_metadata: Dictionary = validation_report.to_dict()
		validation_metadata["summary"] = _make_command_validation_summary(validation_report, command_name)
		var validation_result: Dictionary = _make_command_result(false, null, GFVariantData.get_option_string(validation_metadata, "summary"), {
			"tier": tier,
			"tier_name": _get_tier_name(tier),
			"validation": validation_metadata,
		})
		diagnostic_command_executed.emit(command_name, validation_result)
		return validation_result

	var callback: Callable = _get_callable_value(GFVariantData.get_option_value(entry, "callback", Callable()))
	if _get_registration_owner(entry) == null or not callback.is_valid():
		var invalid_result: Dictionary = _make_command_result(false, null, "Diagnostic command callback is invalid: %s" % String(command_name))
		diagnostic_command_executed.emit(command_name, invalid_result)
		return invalid_result

	var value: Variant = callback.call(prepared_args)
	var result: Dictionary = _make_command_result(true, value, "", {
		"tier": tier,
		"tier_name": _get_tier_name(tier),
	})
	if encode_command_results_for_json:
		result = command_result_to_json_compatible(result)
	diagnostic_command_executed.emit(command_name, result)
	return result


## 执行诊断命令并返回 JSON 兼容结果。
## [br]
## @api public
## [br]
## @param command_name: 命令名。
## [br]
## @param args: 命令参数。
## [br]
## @return JSON 兼容结果字典。
## [br]
## @schema args: Dictionary，命令参数；可包含 auth_token 以及该命令 parameter_schema 定义的字段。
## [br]
## @schema return: Dictionary，包含 JSON 兼容的 ok、value、error、metadata。
func execute_command_json_safe(command_name: StringName, args: Dictionary = {}) -> Dictionary:
	return command_result_to_json_compatible(execute_command(command_name, args))


## 将命令结果转换为 JSON 兼容字典。
## [br]
## @api public
## [br]
## @param result: execute_command() 返回的结果。
## [br]
## @param options: 传给 GFVariantJsonCodec.variant_to_json_compatible() 的选项。
## [br]
## @return JSON 兼容结果字典。
## [br]
## @schema result: Dictionary，execute_command() 返回结构。
## [br]
## @schema options: Dictionary，传给 GFVariantJsonCodec.variant_to_json_compatible() 的编码选项。
## [br]
## @schema return: Dictionary，JSON 兼容命令结果。
func command_result_to_json_compatible(result: Dictionary, options: Dictionary = {}) -> Dictionary:
	return GFVariantData.to_dictionary(GFReportValueCodec.to_json_compatible(result, options))


## 采集运行时诊断快照。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @param options: 可选参数，支持 recent_log_count、include_recent_logs、include_scene_tree、scene_tree_options、include_signal_graph、signal_graph_options。
## [br]
## @return 快照字典。
## [br]
## @schema options: Dictionary，支持 recent_log_count、include_recent_logs、include_scene_tree、scene_tree_options、include_signal_graph、signal_graph_options、include_monitors、monitor_preset、monitor_ids、include_hidden_monitors。
## [br]
## @schema return: Dictionary，包含 timestamp_unix、engine、build、architecture、event_system、performance、logs、tools，可选 scene_tree、signal_graph、monitors 和已发布分区。
func collect_snapshot(options: Dictionary = {}) -> Dictionary:
	var build_info_utility: GFBuildInfoUtility = _get_build_info_utility()
	var build_info: Dictionary = (
		build_info_utility.get_build_info_dict()
		if build_info_utility != null
		else GFBuildInfo.collect().to_dict()
	)
	var snapshot: Dictionary = {
		"timestamp_unix": Time.get_unix_time_from_system(),
		"engine": Engine.get_version_info(),
		"build": build_info,
		"architecture": {},
		"event_system": {},
		"performance": {},
		"logs": {},
		"tools": {},
	}

	var architecture: GFArchitecture = _get_architecture_or_null()
	if architecture != null:
		snapshot["architecture"] = architecture.get_debug_lifecycle_state()
		snapshot["event_system"] = architecture.get_event_debug_stats()

	if include_performance_monitors:
		snapshot["performance"] = collect_performance_snapshot()

	snapshot["logs"] = collect_log_snapshot(
		GFVariantData.get_option_int(options, "recent_log_count", default_recent_log_count),
		GFVariantData.get_option_bool(options, "include_recent_logs", true)
	)

	if GFVariantData.get_option_bool(options, "include_scene_tree", false):
		var scene_options: Dictionary = GFVariantData.get_option_dictionary(options, "scene_tree_options")
		snapshot["scene_tree"] = collect_scene_tree_snapshot(null, scene_options)

	if GFVariantData.get_option_bool(options, "include_signal_graph", false):
		var signal_options: Dictionary = GFVariantData.get_option_dictionary(options, "signal_graph_options")
		snapshot["signal_graph"] = collect_signal_graph_snapshot(null, signal_options)

	snapshot["tools"] = _collect_tool_debug_snapshots()
	_collect_published_snapshot_sections(snapshot)

	if GFVariantData.get_option_bool(options, "include_monitors", true):
		var preset_id: StringName = GFVariantData.get_option_string_name(options, "monitor_preset", &"")
		if preset_id != &"":
			snapshot["monitors"] = collect_monitor_preset(
				preset_id,
				GFVariantData.get_option_bool(options, "include_hidden_monitors", false)
			)
		else:
			var monitor_ids: PackedStringArray = GFVariantData.get_option_packed_string_array(options, "monitor_ids")
			snapshot["monitors"] = collect_monitor_snapshot(
				monitor_ids,
				GFVariantData.get_option_bool(options, "include_hidden_monitors", false)
			)

	snapshot_collected.emit(snapshot)
	return snapshot


## 获取 EditorDebugger 桥接状态。
## [br]
## @api public
## [br]
## @since 6.0.0
## [br]
## @return 桥接状态字典。
## [br]
## @schema return: Dictionary with capture_name, registered, debugger_active, editor_feature, editor_hint, and allow_command_execution.
func get_debugger_bridge_state() -> Dictionary:
	return {
		"capture_name": DEBUGGER_CAPTURE_NAME,
		"registered": _debugger_capture_registered,
		"debugger_active": EngineDebugger.is_active(),
		"editor_feature": OS.has_feature("editor"),
		"editor_hint": Engine.is_editor_hint(),
		"allow_command_execution": allow_debugger_command_execution,
	}


## 采集性能监视器快照。
## [br]
## @return 性能数据字典。
## [br]
## @api public
## [br]
## @schema return: Dictionary，包含 fps、process_time、physics_process_time、static_memory、object_count、node_count、resource_count。
func collect_performance_snapshot() -> Dictionary:
	return {
		"fps": Performance.get_monitor(Performance.TIME_FPS),
		"process_time": Performance.get_monitor(Performance.TIME_PROCESS),
		"physics_process_time": Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS),
		"static_memory": Performance.get_monitor(Performance.MEMORY_STATIC),
		"object_count": Performance.get_monitor(Performance.OBJECT_COUNT),
		"node_count": Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
		"resource_count": Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT),
	}


## 采集日志缓存快照。
## [br]
## @api public
## [br]
## @param recent_log_count: 最近日志数量。
## [br]
## @param include_recent_logs: 是否包含日志条目。
## [br]
## @return 日志数据字典。
## [br]
## @schema return: Dictionary，包含 available、memory_count、dropped_count、recent。
func collect_log_snapshot(recent_log_count: int = 20, include_recent_logs: bool = true) -> Dictionary:
	var log_utility: GFLogUtility = _get_log_utility()
	if log_utility == null:
		return {
			"available": false,
			"memory_count": 0,
			"dropped_count": 0,
			"recent": [],
		}

	return {
		"available": true,
		"memory_count": log_utility.get_memory_entry_count(),
		"dropped_count": log_utility.get_dropped_memory_entry_count(),
		"recent": log_utility.get_recent_entries(recent_log_count) if include_recent_logs else [],
	}


## 采集只读场景树快照。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @param root: 可选根节点；为空时优先使用当前场景，再回退到 Viewport root。
## [br]
## @param options: 可选参数，支持 max_depth、max_nodes、include_groups、include_owner_path、include_script_path、include_internal、redact_paths。
## [br]
## @return 场景树快照字典。
## [br]
## @schema options: Dictionary，支持 max_depth、max_nodes、include_groups、include_owner_path、include_script_path、include_internal、redact_paths、root_path、prefer_current_scene。
## [br]
## @schema return: Dictionary，包含 available、node_count、truncated、root_path、root。
func collect_scene_tree_snapshot(root: Node = null, options: Dictionary = {}) -> Dictionary:
	var target_root: Node = root if root != null else _resolve_scene_tree_root(options)
	var max_depth: int = maxi(GFVariantData.get_option_int(options, "max_depth", default_scene_tree_max_depth), 0)
	var max_nodes: int = maxi(GFVariantData.get_option_int(options, "max_nodes", default_scene_tree_max_nodes), 1)
	var normalized_options: Dictionary = {
		"max_depth": max_depth,
		"max_nodes": max_nodes,
		"include_groups": GFVariantData.get_option_bool(options, "include_groups", false),
		"include_owner_path": GFVariantData.get_option_bool(options, "include_owner_path", true),
		"include_script_path": GFVariantData.get_option_bool(options, "include_script_path", true),
		"include_internal": GFVariantData.get_option_bool(options, "include_internal", false),
		"redact_paths": GFVariantData.get_option_bool(options, "redact_paths", false),
	}

	if target_root == null:
		return {
			"available": false,
			"node_count": 0,
			"truncated": false,
			"root_path": "",
			"root": {},
		}

	var counters: Dictionary = {
		"count": 0,
		"truncated": false,
	}
	var root_snapshot: Dictionary = _collect_scene_tree_node(target_root, 0, normalized_options, counters)
	return {
		"available": true,
		"node_count": GFVariantData.get_option_int(counters, "count", 0),
		"truncated": GFVariantData.get_option_bool(counters, "truncated", false),
		"root_path": _redact_path_if_needed(_get_node_path_or_empty(target_root), normalized_options),
		"root": root_snapshot,
	}


## 采集只读信号连接图快照。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @param root: 可选根节点；为空时优先使用当前场景，再回退到 Viewport root。
## [br]
## @param options: 可选参数，支持 include_internal、persistent_only、include_empty_signals、include_external_targets、include_index、redact_paths。
## [br]
## @return 信号图快照字典。
## [br]
## @schema options: Dictionary，支持 include_internal、persistent_only、include_empty_signals、include_external_targets、include_index、redact_paths、root_path、prefer_current_scene。
## [br]
## @schema return: Dictionary，包含 ok、root_path、node_count、signal_count、connection_count、nodes、signals、connections，可选 index。
func collect_signal_graph_snapshot(root: Node = null, options: Dictionary = {}) -> Dictionary:
	var target_root: Node = root if root != null else _resolve_scene_tree_root(options)
	if target_root == null:
		return {
			"ok": false,
			"root_path": "",
			"node_count": 0,
			"signal_count": 0,
			"connection_count": 0,
			"nodes": [],
			"signals": [],
			"connections": [],
			"message": "Signal graph root is unavailable.",
		}

	var graph: Dictionary = _build_runtime_signal_graph(target_root, options)
	if GFVariantData.get_option_bool(options, "include_index", false):
		graph["index"] = _index_signal_graph(graph)
	return graph


# --- 私有/辅助方法 ---

func _build_runtime_signal_graph(root: Node, options: Dictionary) -> Dictionary:
	var state: Dictionary = {
		"include_internal": GFVariantData.get_option_bool(options, "include_internal", false),
		"include_empty_signals": GFVariantData.get_option_bool(options, "include_empty_signals", false),
		"include_external_targets": GFVariantData.get_option_bool(options, "include_external_targets", true),
		"persistent_only": GFVariantData.get_option_bool(options, "persistent_only", false),
		"max_nodes": maxi(GFVariantData.get_option_int(options, "max_nodes", default_scene_tree_max_nodes), 1),
		"redact_paths": GFVariantData.get_option_bool(options, "redact_paths", false),
		"truncated": false,
	}
	var graph: Dictionary = {
		"ok": true,
		"root_path": _redact_path_if_needed(_get_node_path_or_empty(root), state),
		"node_count": 0,
		"signal_count": 0,
		"connection_count": 0,
		"nodes": [],
		"signals": [],
		"connections": [],
	}
	_collect_signal_graph_node(root, root, graph, state)
	graph["node_count"] = GFVariantData.get_option_array(graph, "nodes").size()
	graph["signal_count"] = GFVariantData.get_option_array(graph, "signals").size()
	graph["connection_count"] = GFVariantData.get_option_array(graph, "connections").size()
	graph["truncated"] = GFVariantData.get_option_bool(state, "truncated", false)
	return graph


func _collect_signal_graph_node(root: Node, node: Node, graph: Dictionary, state: Dictionary) -> void:
	if node == null or GFVariantData.get_option_bool(state, "truncated", false):
		return
	var nodes: Array = GFVariantData.get_option_array(graph, "nodes")
	if nodes.size() >= GFVariantData.get_option_int(state, "max_nodes", default_scene_tree_max_nodes):
		state["truncated"] = true
		return

	var node_path: String = _redact_path_if_needed(_get_node_path_or_empty(node), state)
	nodes.append({
		"path": node_path,
		"name": node.name,
		"type": node.get_class(),
	})
	graph["nodes"] = nodes

	for signal_info: Dictionary in node.get_signal_list():
		var signal_name: StringName = GFVariantData.get_option_string_name(signal_info, "name")
		if signal_name == &"":
			continue
		if not GFVariantData.get_option_bool(state, "include_internal", false) and String(signal_name).begins_with("_"):
			continue
		var raw_connections: Array = node.get_signal_connection_list(signal_name)
		var connections: Array = _filter_signal_connections(root, node_path, signal_name, raw_connections, state)
		if connections.is_empty() and not GFVariantData.get_option_bool(state, "include_empty_signals", false):
			continue
		var signals: Array = GFVariantData.get_option_array(graph, "signals")
		signals.append({
			"node_path": node_path,
			"signal": String(signal_name),
			"connection_count": connections.size(),
		})
		graph["signals"] = signals
		var graph_connections: Array = GFVariantData.get_option_array(graph, "connections")
		graph_connections.append_array(connections)
		graph["connections"] = graph_connections

	for child: Node in node.get_children():
		_collect_signal_graph_node(root, child, graph, state)


func _filter_signal_connections(
	root: Node,
	source_path: String,
	signal_name: StringName,
	raw_connections: Array,
	state: Dictionary
) -> Array:
	var result: Array = []
	for connection_value: Variant in raw_connections:
		var connection: Dictionary = GFVariantData.as_dictionary(connection_value)
		var flags: int = GFVariantData.get_option_int(connection, "flags", 0)
		if GFVariantData.get_option_bool(state, "persistent_only", false) and (flags & CONNECT_PERSIST) == 0:
			continue
		var callback: Callable = _get_callable_value(GFVariantData.get_option_value(connection, "callable", Callable()))
		if not callback.is_valid():
			continue
		var target: Object = callback.get_object()
		if not _signal_connection_target_allowed(root, target, state):
			continue
		var target_path: String = ""
		if target is Node:
			var target_node: Node = target
			target_path = _redact_path_if_needed(_get_node_path_or_empty(target_node), state)
		result.append({
			"source_path": source_path,
			"signal": String(signal_name),
			"target_path": target_path,
			"target_class": target.get_class() if target != null else "",
			"method": callback.get_method(),
			"flags": flags,
		})
	return result


func _signal_connection_target_allowed(root: Node, target: Object, state: Dictionary) -> bool:
	if GFVariantData.get_option_bool(state, "include_external_targets", true):
		return true
	if not (target is Node):
		return false
	var target_node: Node = target
	return target_node == root or root.is_ancestor_of(target_node)


func _index_signal_graph(graph: Dictionary) -> Dictionary:
	var by_source: Dictionary = {}
	var by_target: Dictionary = {}
	for connection: Dictionary in GFVariantData.get_option_array(graph, "connections"):
		var source_path: String = GFVariantData.get_option_string(connection, "source_path")
		var target_path: String = GFVariantData.get_option_string(connection, "target_path")
		var source_entries: Array = GFVariantData.get_option_array(by_source, source_path)
		source_entries.append(connection.duplicate(true))
		by_source[source_path] = source_entries
		if not target_path.is_empty():
			var target_entries: Array = GFVariantData.get_option_array(by_target, target_path)
			target_entries.append(connection.duplicate(true))
			by_target[target_path] = target_entries
	return {
		"by_source": by_source,
		"by_target": by_target,
	}


func _is_reserved_snapshot_section_id(section_id: StringName) -> bool:
	match section_id:
		&"timestamp_unix", &"engine", &"build", &"architecture", &"event_system", &"performance", &"logs", &"tools", &"scene_tree", &"signal_graph", &"monitors":
			return true
		_:
			return false


func _is_builtin_tool_snapshot_id(tool_id: StringName) -> bool:
	match tool_id:
		&"build_info", &"timer", &"object_pool", &"operation_diagnostics", &"async_tracker":
			return true
		_:
			return false


func _get_build_info_utility() -> GFBuildInfoUtility:
	var utility: Variant = get_utility(GFBuildInfoUtility)
	if utility is GFBuildInfoUtility:
		var build_info_utility: GFBuildInfoUtility = utility
		return build_info_utility
	return null


func _get_log_utility() -> GFLogUtility:
	var utility: Variant = get_utility(GFLogUtility)
	if utility is GFLogUtility:
		var log_utility: GFLogUtility = utility
		return log_utility
	return null


func _get_console_utility() -> GFConsoleUtility:
	var utility: Variant = get_utility(GFConsoleUtility)
	if utility is GFConsoleUtility:
		var console_utility: GFConsoleUtility = utility
		return console_utility
	return null


func _get_main_scene_tree() -> SceneTree:
	var main_loop: MainLoop = Engine.get_main_loop()
	if main_loop is SceneTree:
		var tree: SceneTree = main_loop
		return tree
	return null


func _get_dictionary_entry(source: Dictionary, key: Variant) -> Dictionary:
	if not source.has(key):
		return {}
	var value: Variant = source[key]
	if not (value is Dictionary):
		return {}
	var entry: Dictionary = value
	return entry


func _can_register_owned_entry(registry: Dictionary, entry_id: Variant, owner: Object) -> bool:
	if owner == null:
		return false
	if not registry.has(entry_id):
		return true
	if _owned_entry_matches(registry, entry_id, owner):
		return true
	var existing_entry: Dictionary = _get_dictionary_entry(registry, entry_id)
	if _get_registration_owner(existing_entry) != null:
		return false
	var _stale_entry_erased: bool = registry.erase(entry_id)
	return true


func _owned_entry_matches(registry: Dictionary, entry_id: Variant, owner: Object) -> bool:
	if owner == null or not registry.has(entry_id):
		return false
	var entry: Dictionary = _get_dictionary_entry(registry, entry_id)
	return _get_registration_owner(entry) == owner


func _owned_registry_has_live_entry(registry: Dictionary, entry_id: Variant) -> bool:
	if not registry.has(entry_id):
		return false
	if _get_registration_owner(_get_dictionary_entry(registry, entry_id)) != null:
		return true
	var _stale_entry_erased: bool = registry.erase(entry_id)
	return false


func _prune_released_owned_entries(registry: Dictionary) -> void:
	var stale_ids: Array[Variant] = []
	for entry_id: Variant in registry.keys():
		if _get_registration_owner(_get_dictionary_entry(registry, entry_id)) == null:
			stale_ids.append(entry_id)
	for entry_id: Variant in stale_ids:
		var _stale_entry_erased: bool = registry.erase(entry_id)


func _command_registration_is_live(command_name: StringName) -> bool:
	if _owned_registry_has_live_entry(_commands, command_name):
		return true
	var _disabled_erased: bool = _disabled_commands.erase(command_name)
	return false


func _prune_released_commands() -> void:
	_prune_released_owned_entries(_commands)
	var stale_disabled_names: Array[Variant] = []
	for command_name: Variant in _disabled_commands.keys():
		if not _commands.has(command_name):
			stale_disabled_names.append(command_name)
	for command_name: Variant in stale_disabled_names:
		var _disabled_erased: bool = _disabled_commands.erase(command_name)


func _get_registration_owner(entry: Dictionary) -> Object:
	var owner_ref_value: Variant = GFVariantData.get_option_value(entry, "owner_ref")
	if not (owner_ref_value is WeakRef):
		return null
	var owner_ref: WeakRef = owner_ref_value
	var owner_value: Variant = owner_ref.get_ref()
	if typeof(owner_value) != TYPE_OBJECT or not is_instance_valid(owner_value):
		return null
	var owner: Object = owner_value
	if owner.get_instance_id() != GFVariantData.get_option_int(entry, "owner_instance_id", -1):
		return null
	return owner


func _get_callable_value(value: Variant) -> Callable:
	if value is Callable:
		var callable: Callable = value
		return callable
	return Callable()


func _get_script_value(value: Variant) -> Script:
	if value is Script:
		var script: Script = value
		return script
	return null


func _is_float_convertible(value: Variant) -> bool:
	return value is int or value is float or value is bool


func _number_to_float(value: Variant) -> float:
	if value is float:
		var float_value: float = value
		return float_value
	if value is int:
		var int_value: int = value
		return float(int_value)
	if value is bool:
		var bool_value: bool = value
		return float(bool_value)
	return 0.0


func _bind_console_command() -> void:
	_console_utility = _get_console_utility()
	if _console_utility == null:
		return
	if _console_utility.get_command_names().has("diagnostics"):
		return

	_console_command_subscription = _console_utility.register_command(self, "diagnostics", Callable(self, "_on_console_diagnostics_command"), "输出 GF 诊断摘要。", {
		"tier": GFConsoleUtility.CommandTier.OBSERVE,
	})


func _register_debugger_capture() -> void:
	if Engine.is_editor_hint():
		return
	if not EngineDebugger.is_active():
		return
	if EngineDebugger.has_capture(DEBUGGER_CAPTURE_NAME):
		return

	EngineDebugger.register_message_capture(DEBUGGER_CAPTURE_NAME, Callable(self, "_handle_debugger_message"))
	_debugger_capture_registered = true


func _unregister_debugger_capture() -> void:
	if not _debugger_capture_registered:
		return
	if EngineDebugger.has_capture(DEBUGGER_CAPTURE_NAME):
		EngineDebugger.unregister_message_capture(DEBUGGER_CAPTURE_NAME)
	_debugger_capture_registered = false


func _handle_debugger_message(message: String, data: Array) -> bool:
	match _normalize_debugger_message(message):
		"request_snapshot":
			var snapshot_options: Dictionary = _debugger_data_dictionary(data, 0)
			EngineDebugger.send_message(DEBUGGER_MESSAGE_SNAPSHOT, [_make_debugger_payload(collect_snapshot(snapshot_options))])
			return true
		"request_catalog":
			EngineDebugger.send_message(DEBUGGER_MESSAGE_CATALOG, [_make_debugger_payload(_make_debugger_catalog())])
			return true
		"execute_command":
			var command_name: StringName = _debugger_data_string_name(data, 0)
			var args: Dictionary = _debugger_data_dictionary(data, 1)
			var result: Dictionary = execute_command_json_safe(command_name, args) if allow_debugger_command_execution else _make_command_result(false, null, "Debugger command execution is disabled.")
			EngineDebugger.send_message(DEBUGGER_MESSAGE_COMMAND_RESULT, [
				String(command_name),
				_make_debugger_payload(result),
			])
			return true
		_:
			return false


func _normalize_debugger_message(message: String) -> String:
	var prefix: String = String(DEBUGGER_CAPTURE_NAME) + ":"
	if message.begins_with(prefix):
		return message.substr(prefix.length())
	return message


func _make_debugger_catalog() -> Dictionary:
	return {
		"commands": get_command_catalog(),
		"monitors": get_monitor_catalog(),
		"monitor_presets": get_monitor_preset_ids(),
		"bridge": get_debugger_bridge_state(),
	}


func _make_debugger_payload(value: Variant) -> Variant:
	return GFVariantJsonCodec.variant_to_json_compatible(value)


func _debugger_data_dictionary(data: Array, index: int) -> Dictionary:
	if index < 0 or index >= data.size():
		return {}
	var value: Variant = data[index]
	if value is Dictionary:
		var dictionary: Dictionary = value
		return dictionary.duplicate(true)
	return {}


func _debugger_data_string_name(data: Array, index: int) -> StringName:
	if index < 0 or index >= data.size():
		return &""
	return GFVariantData.to_string_name(data[index])


func _make_command_result(ok: bool, value: Variant, error: String, metadata: Dictionary = {}) -> Dictionary:
	var result: Dictionary = {
		"ok": ok,
		"value": value,
		"error": error,
		"metadata": metadata.duplicate(true),
	}
	return result


func _make_command_validation_summary(report: GFValidationReport, command_name: StringName) -> String:
	var summary: String = report.make_summary(String(command_name))
	var issue_kinds: PackedStringArray = PackedStringArray()
	var counts_by_kind: Dictionary = report.get_issue_counts_by_kind()
	for kind_variant: Variant in counts_by_kind.keys():
		var kind_text: String = GFVariantData.to_text(kind_variant)
		if kind_text.is_empty():
			continue
		var _kind_appended: bool = issue_kinds.append(kind_text)
	if issue_kinds.is_empty():
		return summary
	issue_kinds.sort()
	return "%s Issues: %s." % [summary, ", ".join(issue_kinds)]


func _command_collect_snapshot(args: Dictionary) -> Dictionary:
	return collect_snapshot(args)


func _command_collect_performance(_args: Dictionary) -> Dictionary:
	return collect_performance_snapshot()


func _command_collect_logs(args: Dictionary) -> Dictionary:
	return collect_log_snapshot(
		GFVariantData.get_option_int(args, "recent_log_count", default_recent_log_count),
		GFVariantData.get_option_bool(args, "include_recent_logs", true)
	)


func _command_collect_monitors(args: Dictionary) -> Dictionary:
	var preset_id: StringName = GFVariantData.get_option_string_name(args, "preset_id", &"")
	if preset_id != &"":
		return collect_monitor_preset(preset_id, GFVariantData.get_option_bool(args, "include_hidden", false))

	var monitor_ids: PackedStringArray = GFVariantData.get_option_packed_string_array(args, "monitor_ids")
	return collect_monitor_snapshot(
		monitor_ids,
		GFVariantData.get_option_bool(args, "include_hidden", false)
	)


func _command_collect_tools(_args: Dictionary) -> Dictionary:
	return _collect_tool_debug_snapshots()


func _command_collect_scene(args: Dictionary) -> Dictionary:
	return collect_scene_tree_snapshot(null, args)


func _command_collect_signals(args: Dictionary) -> Dictionary:
	return collect_signal_graph_snapshot(null, args)


func _collect_scene_tree_node(node: Node, depth: int, options: Dictionary, counters: Dictionary) -> Dictionary:
	counters["count"] = GFVariantData.get_option_int(counters, "count", 0) + 1
	var include_internal: bool = GFVariantData.get_option_bool(options, "include_internal", false)
	var child_count: int = node.get_child_count(include_internal)
	var info: Dictionary = {
		"name": node.name,
		"type": node.get_class(),
		"path": _redact_path_if_needed(_get_node_path_or_empty(node), options),
		"depth": depth,
		"child_count": child_count,
		"children": [],
	}

	if GFVariantData.get_option_bool(options, "include_owner_path", true):
		info["owner_path"] = _redact_path_if_needed(_get_node_path_or_empty(node.owner), options)
	if GFVariantData.get_option_bool(options, "include_script_path", true):
		info["script_path"] = _redact_path_if_needed(_get_node_script_path(node), options)
	if GFVariantData.get_option_bool(options, "include_groups", false):
		info["groups"] = _get_node_group_names(node)

	if depth >= GFVariantData.get_option_int(options, "max_depth", default_scene_tree_max_depth):
		if child_count > 0:
			info["depth_limit_reached"] = true
			counters["truncated"] = true
		return info

	var children: Array[Dictionary] = []
	for child_index: int in range(child_count):
		if GFVariantData.get_option_int(counters, "count", 0) >= GFVariantData.get_option_int(options, "max_nodes", default_scene_tree_max_nodes):
			info["children_truncated"] = true
			counters["truncated"] = true
			break

		var child: Node = node.get_child(child_index, include_internal)
		children.append(_collect_scene_tree_node(child, depth + 1, options, counters))
	info["children"] = children
	return info


func _resolve_scene_tree_root(options: Dictionary) -> Node:
	var root_path: NodePath = NodePath(GFVariantData.get_option_string(options, "root_path"))
	var tree: SceneTree = _get_main_scene_tree()
	if tree == null:
		return null

	if not root_path.is_empty():
		var explicit_root: Node = tree.root.get_node_or_null(root_path)
		if explicit_root != null:
			return explicit_root
		if tree.current_scene != null:
			explicit_root = tree.current_scene.get_node_or_null(root_path)
			if explicit_root != null:
				return explicit_root

	return tree.current_scene if tree.current_scene != null else tree.root


func _get_node_path_or_empty(node: Node) -> String:
	if node == null:
		return ""
	if node.is_inside_tree():
		return str(node.get_path())
	return String(node.name)


func _get_node_script_path(node: Node) -> String:
	var script: Script = _get_script_value(node.get_script())
	if script == null:
		return ""
	return script.resource_path


func _redact_path_if_needed(path: String, options: Dictionary) -> String:
	if path.is_empty() or not GFVariantData.get_option_bool(options, "redact_paths", false):
		return path
	return "<redacted>"


func _get_node_group_names(node: Node) -> PackedStringArray:
	var groups: PackedStringArray = PackedStringArray()
	for group: StringName in node.get_groups():
		var _group_appended: bool = groups.append(String(group))
	groups.sort()
	return groups


func _register_builtin_monitors() -> void:
	_register_builtin_monitor(&"performance.fps", &"_monitor_performance_fps", "FPS", "Performance")
	_register_builtin_monitor(&"performance.process_time", &"_monitor_performance_process_time", "Process Time", "Performance")
	_register_builtin_monitor(&"performance.physics_process_time", &"_monitor_performance_physics_time", "Physics Time", "Performance")
	_register_builtin_monitor(&"performance.static_memory", &"_monitor_performance_static_memory", "Static Memory", "Performance", 0.25)
	_register_builtin_monitor(&"performance.node_count", &"_monitor_performance_node_count", "Nodes", "Performance", 0.25)
	_register_builtin_monitor(&"architecture.models", &"_monitor_architecture_model_count", "Models", "Architecture", 0.25)
	_register_builtin_monitor(&"architecture.systems", &"_monitor_architecture_system_count", "Systems", "Architecture", 0.25)
	_register_builtin_monitor(&"architecture.utilities", &"_monitor_architecture_utility_count", "Utilities", "Architecture", 0.25)
	_register_builtin_monitor(&"event_system.stats", &"_monitor_event_system_stats", "Event Stats", "Architecture", 0.25)
	_register_builtin_monitor(&"tools.timer", &"_monitor_tool_timer_snapshot", "Timer Utility", "Tools", 0.25)

	_register_builtin_monitor_preset(&"minimal", PackedStringArray([
		"performance.fps",
		"performance.process_time",
		"performance.physics_process_time",
	]), "Minimal")
	_register_builtin_monitor_preset(&"performance", PackedStringArray([
		"performance.fps",
		"performance.process_time",
		"performance.physics_process_time",
		"performance.static_memory",
		"performance.node_count",
	]), "Performance")
	_register_builtin_monitor_preset(&"architecture", PackedStringArray([
		"architecture.models",
		"architecture.systems",
		"architecture.utilities",
		"event_system.stats",
	]), "Architecture")
	_register_builtin_monitor_preset(&"tools", PackedStringArray([
		"tools.timer",
	]), "Tools")
	_register_builtin_monitor_preset(&"overlay", PackedStringArray([
		"performance.fps",
		"architecture.models",
		"architecture.systems",
		"architecture.utilities",
	]), "Overlay")


func _register_builtin_monitor(
	monitor_id: StringName,
	method_name: StringName,
	label: String,
	group: String,
	min_interval_seconds: float = 0.0
) -> void:
	var provider: Callable = Callable(self, method_name)
	if not provider.is_valid():
		push_warning("Failed to register built-in diagnostic monitor: %s" % String(monitor_id))
		return
	var existing_entry: Dictionary = _get_dictionary_entry(_monitors, monitor_id)
	var order: int = GFVariantData.get_option_int(existing_entry, "order", _monitor_order_counter)
	if existing_entry.is_empty():
		_monitor_order_counter += 1
	_monitors[monitor_id] = {
		"owner_ref": weakref(self),
		"owner_instance_id": get_instance_id(),
		"trusted_provider": provider,
		"label": label,
		"group": group,
		"visible": true,
		"metadata": {},
		"sample_interval_seconds": maxf(min_interval_seconds, 0.0),
		"order": order,
		"last_sample_time": GFVariantData.get_option_float(existing_entry, "last_sample_time", -INF),
		"last_sample": GFVariantData.get_option_dictionary(existing_entry, "last_sample"),
	}


func _register_builtin_monitor_preset(preset_id: StringName, monitor_ids: PackedStringArray, label: String) -> void:
	if not register_monitor_preset(preset_id, monitor_ids, { "label": label }):
		push_warning("Failed to register built-in diagnostic monitor preset: %s" % String(preset_id))


func _sample_monitor(monitor_id: StringName, entry: Dictionary) -> Dictionary:
	var sample: Dictionary = {
		"id": monitor_id,
		"label": GFVariantData.get_option_string(entry, "label", String(monitor_id)),
		"group": GFVariantData.get_option_string(entry, "group", "Runtime"),
		"value": null,
		"valid": false,
		"error": "",
		"metadata": GFVariantData.get_option_dictionary(entry, "metadata"),
		"sampled_at_unix": Time.get_unix_time_from_system(),
	}
	if _get_registration_owner(entry) == null:
		sample["error"] = "Monitor owner was released."
		return sample

	var trusted_provider: Callable = _get_callable_value(
		GFVariantData.get_option_value(entry, "trusted_provider", Callable())
	)
	if trusted_provider.is_valid():
		var now_seconds: float = Time.get_ticks_msec() / 1000.0
		var sample_interval_seconds: float = GFVariantData.get_option_float(
			entry,
			"sample_interval_seconds",
			0.0
		)
		var last_sample: Dictionary = GFVariantData.get_option_dictionary(entry, "last_sample")
		if (
			sample_interval_seconds > 0.0
			and not last_sample.is_empty()
			and now_seconds - GFVariantData.get_option_float(entry, "last_sample_time", -INF) < sample_interval_seconds
		):
			return last_sample.duplicate(true)
		var prepared: Dictionary = _prepare_contribution_value(trusted_provider.call())
		if GFVariantData.get_option_bool(prepared, "ok"):
			sample["value"] = GFVariantData.get_option_value(prepared, "value")
			sample["valid"] = true
		else:
			sample["error"] = GFVariantData.get_option_string(prepared, "reason", "Monitor value rejected.")
		entry["last_sample_time"] = now_seconds
		entry["last_sample"] = sample.duplicate(true)
		_monitors[monitor_id] = entry
	elif GFVariantData.get_option_bool(entry, "has_published_value"):
		sample["value"] = GFVariantData.get_option_value(entry, "published_value")
		sample["sample_metadata"] = GFVariantData.get_option_dictionary(entry, "published_metadata")
		sample["sampled_at_unix"] = GFVariantData.get_option_float(entry, "published_at_unix", 0.0)
		sample["valid"] = true
	else:
		sample["error"] = "Monitor has no published sample."

	monitor_sampled.emit(monitor_id, sample)
	return sample


func _monitor_performance_fps() -> float:
	return Performance.get_monitor(Performance.TIME_FPS)


func _monitor_performance_process_time() -> float:
	return Performance.get_monitor(Performance.TIME_PROCESS)


func _monitor_performance_physics_time() -> float:
	return Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)


func _monitor_performance_static_memory() -> float:
	return Performance.get_monitor(Performance.MEMORY_STATIC)


func _monitor_performance_node_count() -> float:
	return Performance.get_monitor(Performance.OBJECT_NODE_COUNT)


func _monitor_architecture_model_count() -> int:
	return _get_architecture_debug_section_count("models")


func _monitor_architecture_system_count() -> int:
	return _get_architecture_debug_section_count("systems")


func _monitor_architecture_utility_count() -> int:
	return _get_architecture_debug_section_count("utilities")


func _monitor_event_system_stats() -> Dictionary:
	var architecture: GFArchitecture = _get_architecture_or_null()
	if architecture == null:
		return {}
	return architecture.get_event_debug_stats()


func _monitor_tool_timer_snapshot() -> Dictionary:
	return _get_instance_debug_snapshot(get_utility(GFTimerUtility))


func _collect_tool_debug_snapshots() -> Dictionary:
	var result: Dictionary = {}
	_add_tool_debug_snapshot(result, &"build_info", get_utility(GFBuildInfoUtility))
	_add_tool_debug_snapshot(result, &"timer", get_utility(GFTimerUtility))
	_add_tool_debug_snapshot(result, &"object_pool", get_utility(GFObjectPoolUtility))
	_add_tool_debug_snapshot(result, &"operation_diagnostics", get_utility(GFOperationDiagnosticsUtility))
	_add_tool_debug_snapshot(result, &"async_tracker", get_utility(GFAsyncTrackerUtility))
	_add_published_tool_snapshots(result)
	return result


func _add_tool_debug_snapshot(result: Dictionary, key: StringName, instance: Object) -> void:
	var snapshot: Dictionary = _get_instance_debug_snapshot(instance)
	if not snapshot.is_empty():
		result[key] = snapshot


func _add_published_tool_snapshots(result: Dictionary) -> void:
	_prune_released_owned_entries(_tool_snapshots)
	for tool_id: StringName in _tool_snapshots.keys():
		if result.has(tool_id):
			continue
		var entry: Dictionary = _get_dictionary_entry(_tool_snapshots, tool_id)
		var snapshot: Dictionary = GFVariantData.get_option_dictionary(entry, "snapshot")
		if not snapshot.is_empty():
			result[tool_id] = snapshot.duplicate(true)


func _collect_published_snapshot_sections(snapshot: Dictionary) -> void:
	_prune_released_owned_entries(_snapshot_sections)
	for section_id: StringName in _snapshot_sections.keys():
		if snapshot.has(section_id):
			continue
		var entry: Dictionary = _get_dictionary_entry(_snapshot_sections, section_id)
		var section: Dictionary = GFVariantData.get_option_dictionary(entry, "snapshot")
		if not section.is_empty():
			snapshot[section_id] = section.duplicate(true)


func _get_instance_debug_snapshot(instance: Object) -> Dictionary:
	if instance == null or not instance.has_method("get_debug_snapshot"):
		return {}
	var value: Variant = instance.call("get_debug_snapshot")
	return GFVariantData.to_dictionary(value)


func _prepare_contribution_value(value: Variant) -> Dictionary:
	var validation: Dictionary = _validate_contribution_value(value)
	if not GFVariantData.get_option_bool(validation, "ok"):
		return validation
	return {
		"ok": true,
		"reason": &"",
		"value": GFReportValueCodec.to_json_compatible(
			value,
			GFReportValueCodec.make_redaction_options(GFReportValueCodec.REDACTION_PROFILE_DEBUG, {
				"max_collection_items": max_contribution_collection_items,
				"max_total_nodes": max_contribution_nodes,
				"max_depth": max_contribution_depth,
				"max_string_length": max_contribution_bytes,
			})
		),
	}


func _validate_contribution_value(value: Variant) -> Dictionary:
	var state: Dictionary = {
		"ok": true,
		"reason": &"",
		"node_count": 0,
		"estimated_bytes": 0,
	}
	var visited: Array[Variant] = []
	var _validation_completed: bool = _validate_contribution_value_recursive(value, 0, visited, state)
	return state


func _validate_contribution_value_recursive(
	value: Variant,
	depth: int,
	visited: Array[Variant],
	state: Dictionary
) -> bool:
	if depth > max_contribution_depth:
		return _fail_contribution_value_validation(state, &"contribution_depth_budget_exhausted")
	var node_count: int = GFVariantData.get_option_int(state, "node_count") + 1
	state["node_count"] = node_count
	if node_count > max_contribution_nodes:
		return _fail_contribution_value_validation(state, &"contribution_node_budget_exhausted")

	var collection_size: int = _get_contribution_collection_size(value)
	if collection_size > max_contribution_collection_items:
		return _fail_contribution_value_validation(state, &"contribution_collection_budget_exhausted")
	var estimated_bytes: int = (
		GFVariantData.get_option_int(state, "estimated_bytes")
		+ _estimate_contribution_value_bytes(value)
	)
	state["estimated_bytes"] = estimated_bytes
	if estimated_bytes > max_contribution_bytes:
		return _fail_contribution_value_validation(state, &"contribution_byte_budget_exhausted")

	if value is Array:
		if _contribution_visited_contains_reference(visited, value):
			return _fail_contribution_value_validation(state, &"contribution_circular_reference")
		visited.append(value)
		var array_value: Array = value
		for item: Variant in array_value:
			if not _validate_contribution_value_recursive(item, depth + 1, visited, state):
				return false
		var _array_reference_removed: Variant = visited.pop_back()
	elif value is Dictionary:
		if _contribution_visited_contains_reference(visited, value):
			return _fail_contribution_value_validation(state, &"contribution_circular_reference")
		visited.append(value)
		var dictionary_value: Dictionary = value
		for key: Variant in dictionary_value.keys():
			if not _validate_contribution_value_recursive(key, depth + 1, visited, state):
				return false
			if not _validate_contribution_value_recursive(dictionary_value[key], depth + 1, visited, state):
				return false
		var _dictionary_reference_removed: Variant = visited.pop_back()
	return true


func _fail_contribution_value_validation(state: Dictionary, reason: StringName) -> bool:
	state["ok"] = false
	state["reason"] = reason
	return false


func _contribution_visited_contains_reference(visited: Array[Variant], value: Variant) -> bool:
	for existing_value: Variant in visited:
		if is_same(existing_value, value):
			return true
	return false


func _get_contribution_collection_size(value: Variant) -> int:
	match typeof(value):
		TYPE_ARRAY:
			var array_value: Array = value
			return array_value.size()
		TYPE_DICTIONARY:
			var dictionary_value: Dictionary = value
			return dictionary_value.size()
		TYPE_PACKED_BYTE_ARRAY:
			var byte_array: PackedByteArray = value
			return byte_array.size()
		TYPE_PACKED_INT32_ARRAY:
			var int_32_array: PackedInt32Array = value
			return int_32_array.size()
		TYPE_PACKED_INT64_ARRAY:
			var int_64_array: PackedInt64Array = value
			return int_64_array.size()
		TYPE_PACKED_FLOAT32_ARRAY:
			var float_32_array: PackedFloat32Array = value
			return float_32_array.size()
		TYPE_PACKED_FLOAT64_ARRAY:
			var float_64_array: PackedFloat64Array = value
			return float_64_array.size()
		TYPE_PACKED_STRING_ARRAY:
			var string_array: PackedStringArray = value
			return string_array.size()
		TYPE_PACKED_VECTOR2_ARRAY:
			var vector_2_array: PackedVector2Array = value
			return vector_2_array.size()
		TYPE_PACKED_VECTOR3_ARRAY:
			var vector_3_array: PackedVector3Array = value
			return vector_3_array.size()
		TYPE_PACKED_COLOR_ARRAY:
			var color_array: PackedColorArray = value
			return color_array.size()
		TYPE_PACKED_VECTOR4_ARRAY:
			var vector_4_array: PackedVector4Array = value
			return vector_4_array.size()
		_:
			return -1


func _estimate_contribution_value_bytes(value: Variant) -> int:
	match typeof(value):
		TYPE_STRING:
			var string_value: String = value
			return string_value.to_utf8_buffer().size() + 8
		TYPE_STRING_NAME:
			var string_name_value: StringName = value
			return String(string_name_value).to_utf8_buffer().size() + 8
		TYPE_NODE_PATH:
			var node_path_value: NodePath = value
			return String(node_path_value).to_utf8_buffer().size() + 8
		TYPE_ARRAY, TYPE_DICTIONARY:
			return 16
		TYPE_PACKED_BYTE_ARRAY:
			var byte_array: PackedByteArray = value
			return byte_array.size() + 16
		TYPE_PACKED_INT32_ARRAY, TYPE_PACKED_FLOAT32_ARRAY:
			return _get_contribution_collection_size(value) * 4 + 16
		TYPE_PACKED_INT64_ARRAY, TYPE_PACKED_FLOAT64_ARRAY:
			return _get_contribution_collection_size(value) * 8 + 16
		TYPE_PACKED_VECTOR2_ARRAY:
			return _get_contribution_collection_size(value) * 8 + 16
		TYPE_PACKED_VECTOR3_ARRAY:
			return _get_contribution_collection_size(value) * 12 + 16
		TYPE_PACKED_COLOR_ARRAY, TYPE_PACKED_VECTOR4_ARRAY:
			return _get_contribution_collection_size(value) * 16 + 16
		TYPE_PACKED_STRING_ARRAY:
			var string_array: PackedStringArray = value
			var estimated_bytes: int = 16
			for text_value: String in string_array:
				estimated_bytes += text_value.to_utf8_buffer().size() + 8
			return estimated_bytes
		_:
			return 16


func _get_architecture_debug_section_count(section_name: String) -> int:
	var architecture: GFArchitecture = _get_architecture_or_null()
	if architecture == null:
		return 0

	var state: Dictionary = architecture.get_debug_lifecycle_state()
	var section: Dictionary = GFVariantData.get_option_dictionary(state, section_name)
	return section.size()


func _export_monitor_snapshot_as_text(snapshot: Dictionary) -> String:
	var lines: PackedStringArray = PackedStringArray()
	var monitors: Dictionary = GFVariantData.get_option_dictionary(snapshot, "monitors")
	if monitors.is_empty():
		return ""

	var ids: PackedStringArray = PackedStringArray()
	for monitor_id: Variant in monitors.keys():
		var _id_appended: bool = ids.append(str(monitor_id))
	ids.sort()
	for id_text: String in ids:
		var sample: Dictionary = GFVariantData.get_option_dictionary(monitors, id_text)
		if sample.is_empty():
			continue
		var _line_appended: bool = lines.append("%s [%s]: %s" % [
			GFVariantData.get_option_string(sample, "label", id_text),
			GFVariantData.get_option_string(sample, "group", "Runtime"),
			str(GFVariantData.get_option_value(sample, "value", null)),
		])
	return "\n".join(lines)


func _export_monitor_snapshot_as_csv(snapshot: Dictionary) -> String:
	var lines: PackedStringArray = PackedStringArray(["id,label,group,value,valid,error"])
	var monitors: Dictionary = GFVariantData.get_option_dictionary(snapshot, "monitors")
	if monitors.is_empty():
		return "\n".join(lines)

	var ids: PackedStringArray = PackedStringArray()
	for monitor_id: Variant in monitors.keys():
		var _id_appended: bool = ids.append(str(monitor_id))
	ids.sort()
	for id_text: String in ids:
		var sample: Dictionary = GFVariantData.get_option_dictionary(monitors, id_text)
		if sample.is_empty():
			continue
		var _line_appended: bool = lines.append(",".join(PackedStringArray([
			_escape_csv(id_text),
			_escape_csv(GFVariantData.get_option_string(sample, "label", id_text)),
			_escape_csv(GFVariantData.get_option_string(sample, "group", "Runtime")),
			_escape_csv(str(GFVariantData.get_option_value(sample, "value", null))),
			_escape_csv(str(GFVariantData.get_option_bool(sample, "valid", false))),
			_escape_csv(GFVariantData.get_option_string(sample, "error")),
		])))
	return "\n".join(lines)


func _escape_csv(value: String) -> String:
	var escaped: String = value.replace("\"", "\"\"")
	if escaped.contains(",") or escaped.contains("\n") or escaped.contains("\""):
		return "\"%s\"" % escaped
	return escaped


func _on_console_diagnostics_command(_args: PackedStringArray) -> void:
	var snapshot: Dictionary = collect_snapshot({
		"include_recent_logs": false,
	})
	var summary: String = _make_console_summary(snapshot)
	var log_utility: GFLogUtility = _get_log_utility()
	if log_utility != null:
		log_utility.info("Diagnostics", summary)
	else:
		print(summary)


func _make_console_summary(snapshot: Dictionary) -> String:
	var architecture: Dictionary = GFVariantData.get_option_dictionary(snapshot, "architecture")
	var models: Dictionary = GFVariantData.get_option_dictionary(architecture, "models")
	var systems: Dictionary = GFVariantData.get_option_dictionary(architecture, "systems")
	var utilities: Dictionary = GFVariantData.get_option_dictionary(architecture, "utilities")
	var performance: Dictionary = GFVariantData.get_option_dictionary(snapshot, "performance")
	var fps: float = GFVariantData.get_option_float(performance, "fps", 0.0)
	return "GF diagnostics: models=%d systems=%d utilities=%d fps=%.1f" % [
		models.size(),
		systems.size(),
		utilities.size(),
		fps,
	]


func _is_tier_allowed(tier: int) -> bool:
	if tier > int(max_command_tier):
		return false
	if tier == CommandTier.DANGER and not allow_danger_commands:
		return false
	return true


func _is_auth_allowed(args: Dictionary) -> bool:
	if not require_auth_token:
		return true
	if auth_token.is_empty():
		return false

	var provided: String = GFVariantData.get_option_string(
		args,
		"auth_token",
		GFVariantData.get_option_string(args, "_auth_token")
	)
	return provided == auth_token


func _normalize_parameter_schema(parameters: Variant) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if parameters is Dictionary:
		var parameter_map: Dictionary = parameters
		for key: Variant in parameter_map.keys():
			var definition: Dictionary = {}
			var raw_definition: Variant = parameter_map[key]
			if raw_definition is Dictionary:
				var raw_definition_dictionary: Dictionary = raw_definition
				definition = raw_definition_dictionary.duplicate(true)
			definition["name"] = str(key)
			result.append(_normalize_parameter_definition(definition))
	elif parameters is Array:
		var parameter_array: Array = parameters
		for item: Variant in parameter_array:
			if item is Dictionary:
				var item_definition: Dictionary = item
				result.append(_normalize_parameter_definition(item_definition.duplicate(true)))
	return result


func _normalize_parameter_definition(definition: Dictionary) -> Dictionary:
	var parameter_name: String = GFVariantData.get_option_string(definition, "name")
	if parameter_name.is_empty():
		return {}
	return {
		"name": parameter_name,
		"type": GFVariantData.get_option_string(definition, "type", "any").to_lower(),
		"required": GFVariantData.get_option_bool(definition, "required", false),
		"allow_null": GFVariantData.get_option_bool(definition, "allow_null", false),
		"default": GFVariantData.duplicate_variant(GFVariantData.get_option_value(definition, "default", null)),
		"has_default": definition.has("default"),
		"allowed_values": GFVariantData.duplicate_variant(GFVariantData.get_option_value(definition, "allowed_values", [])),
		"min": GFVariantData.get_option_value(definition, "min", null),
		"max": GFVariantData.get_option_value(definition, "max", null),
		"metadata": GFVariantData.get_option_dictionary(definition, "metadata"),
	}


func _prepare_command_args(args: Dictionary, entry: Dictionary) -> Dictionary:
	var prepared: Dictionary = args.duplicate(true)
	var parameters: Array = GFVariantData.get_option_array(entry, "parameters")
	for parameter_variant: Variant in parameters:
		if not (parameter_variant is Dictionary):
			continue
		var parameter: Dictionary = parameter_variant
		var parameter_name: String = GFVariantData.get_option_string(parameter, "name")
		if not prepared.has(parameter_name) and GFVariantData.get_option_bool(parameter, "has_default", false):
			prepared[parameter_name] = GFVariantData.duplicate_variant(GFVariantData.get_option_value(parameter, "default", null))
	return prepared


func _validate_command_args(entry: Dictionary, prepared_args: Dictionary, original_args: Dictionary) -> GFValidationReport:
	var report: GFValidationReport = GFValidationReport.new("Diagnostic command arguments")
	var parameters: Array = GFVariantData.get_option_array(entry, "parameters")

	for parameter_variant: Variant in parameters:
		if not (parameter_variant is Dictionary):
			continue
		var parameter: Dictionary = parameter_variant
		if parameter.is_empty():
			continue
		_validate_command_parameter(report, parameter, prepared_args, original_args)
	return report


func _validate_command_parameter(
	report: GFValidationReport,
	parameter: Dictionary,
	prepared_args: Dictionary,
	original_args: Dictionary
) -> void:
	var parameter_name: String = GFVariantData.get_option_string(parameter, "name")
	if parameter_name.is_empty():
		return
	if (
		GFVariantData.get_option_bool(parameter, "required", false)
		and not original_args.has(parameter_name)
		and not GFVariantData.get_option_bool(parameter, "has_default", false)
	):
		var _missing_issue: RefCounted = report.add_error(&"missing_parameter", "Missing required diagnostic command parameter.", parameter_name)
		return
	if not prepared_args.has(parameter_name):
		return

	var value: Variant = prepared_args[parameter_name]
	if value == null:
		if not GFVariantData.get_option_bool(parameter, "allow_null", false):
			var _null_issue: RefCounted = report.add_error(&"null_parameter", "Diagnostic command parameter does not allow null.", parameter_name)
		return

	var type_name: String = GFVariantData.get_option_string(parameter, "type", "any").to_lower()
	if not _does_value_match_parameter_type(value, type_name):
		var _type_issue: RefCounted = report.add_error(&"parameter_type_mismatch", "Diagnostic command parameter has the wrong type.", parameter_name, "", {
			"expected_type": type_name,
			"actual_type": type_string(typeof(value)),
		})
		return

	_validate_allowed_values(report, parameter, parameter_name, value)
	_validate_numeric_range(report, parameter, parameter_name, value)


func _validate_allowed_values(
	report: GFValidationReport,
	parameter: Dictionary,
	name: String,
	value: Variant
) -> void:
	var allowed_values: Array = GFVariantData.get_option_array(parameter, "allowed_values")
	if allowed_values.is_empty():
		return
	for allowed: Variant in allowed_values:
		if value == allowed:
			return
	var _value_issue: RefCounted = report.add_error(&"parameter_value_not_allowed", "Diagnostic command parameter value is not allowed.", name)


func _validate_numeric_range(
	report: GFValidationReport,
	parameter: Dictionary,
	name: String,
	value: Variant
) -> void:
	if not (value is int or value is float):
		return
	var value_float: float = _number_to_float(value)
	if not _is_finite_float(value_float):
		var _finite_issue: RefCounted = report.add_error(&"parameter_non_finite", "Diagnostic command parameter must be finite.", name)
		return
	var min_value: Variant = GFVariantData.get_option_value(parameter, "min", null)
	if _is_float_convertible(min_value) and value_float < _number_to_float(min_value):
		var _min_issue: RefCounted = report.add_error(&"parameter_below_minimum", "Diagnostic command parameter is below minimum.", name)
	var max_value: Variant = GFVariantData.get_option_value(parameter, "max", null)
	if _is_float_convertible(max_value) and value_float > _number_to_float(max_value):
		var _max_issue: RefCounted = report.add_error(&"parameter_above_maximum", "Diagnostic command parameter is above maximum.", name)


func _does_value_match_parameter_type(value: Variant, type_name: String) -> bool:
	match type_name:
		"", "any", "variant":
			return true
		"bool", "boolean":
			return value is bool
		"int", "integer":
			return value is int
		"float", "number":
			return value is float or value is int
		"string":
			return value is String
		"string_name", "stringname":
			return value is StringName
		"node_path", "nodepath":
			return value is NodePath
		"dictionary", "dict":
			return value is Dictionary
		"array":
			return value is Array
		"packed_string_array":
			return value is PackedStringArray
		"vector2":
			return value is Vector2
		"vector3":
			return value is Vector3
		"color":
			return value is Color
		"object":
			return value is Object
		_:
			return true


func _get_tier_name(tier: int) -> String:
	match tier:
		CommandTier.INPUT:
			return "input"
		CommandTier.CONTROL:
			return "control"
		CommandTier.DANGER:
			return "danger"
		_:
			return "observe"


func _is_finite_float(value: float) -> bool:
	return not is_nan(value) and not is_inf(value)
