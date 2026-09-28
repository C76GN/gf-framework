@tool

# GF 插件 Debugger 插件管理辅助。
extends RefCounted


# --- 常量 ---

## 从标准记录中读取类型化字段的工具脚本。
## [br]
## @api private
const _GF_VARIANT_ACCESS_SCRIPT = preload("res://addons/gf/kernel/core/gf_variant_access.gd")


# --- 私有变量 ---

## 当前已安装到 EditorPlugin、需要在 cleanup 时移除的 Debugger 插件实例。
## [br]
## @api private
var _debugger_plugins: Array[EditorDebuggerPlugin] = []


# --- 公共方法 ---

## 安装 GF Debugger 插件。
## [br]
## @api framework_internal
## [br]
## @layer kernel/editor
## [br]
## @param plugin: 当前 EditorPlugin 实例。
## [br]
## @param standard_records: 组合入口传入的标准库 Debugger 插件记录。
## [br]
## @schema standard_records: Dictionary containing debugger_plugin_records.
## [br]
## @param extension_paths: 当前启用扩展贡献的 EditorDebuggerPlugin 脚本路径。
func setup(
	plugin: EditorPlugin,
	standard_records: Dictionary = {},
	extension_paths: Array[String] = []
) -> void:
	if plugin == null:
		return
	cleanup(plugin)
	for record: Dictionary in _collect_debugger_records(standard_records, extension_paths):
		_add_debugger_plugin(
			plugin,
			_GF_VARIANT_ACCESS_SCRIPT.get_option_string(record, "path"),
			_GF_VARIANT_ACCESS_SCRIPT.get_option_string(record, "label")
		)


## 移除 GF Debugger 插件。
## [br]
## @api framework_internal
## [br]
## @layer kernel/editor
## [br]
## @param plugin: 当前 EditorPlugin 实例。
func cleanup(plugin: EditorPlugin) -> void:
	if plugin == null:
		_debugger_plugins.clear()
		return
	for debugger_plugin: EditorDebuggerPlugin in _debugger_plugins:
		if debugger_plugin != null:
			plugin.remove_debugger_plugin(debugger_plugin)
	_debugger_plugins.clear()


# --- 私有/辅助方法 ---

## 合并标准记录和扩展路径，去除空路径及重复路径，保留首次出现的顺序。
## 标准记录缺少 label 时以路径作为标签，扩展路径始终以自身作为标签。
## [br]
## @api private
func _collect_debugger_records(
	standard_records: Dictionary,
	extension_paths: Array[String]
) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var used_paths: Dictionary = {}
	var standard_debugger_records: Array[Dictionary] = _to_record_array(
		_GF_VARIANT_ACCESS_SCRIPT.get_option_value(
			standard_records,
			"debugger_plugin_records",
			[]
		)
	)
	for record: Dictionary in standard_debugger_records:
		var script_path: String = _GF_VARIANT_ACCESS_SCRIPT.get_option_string(
			record,
			"path"
		).strip_edges()
		if script_path.is_empty() or used_paths.has(script_path):
			continue
		var label: String = _GF_VARIANT_ACCESS_SCRIPT.get_option_string(
			record,
			"label"
		).strip_edges()
		if label.is_empty():
			label = script_path
		used_paths[script_path] = true
		result.append({
			"path": script_path,
			"label": label,
		})

	for raw_path: String in extension_paths:
		var extension_script_path: String = raw_path.strip_edges()
		if extension_script_path.is_empty() or used_paths.has(extension_script_path):
			continue
		used_paths[extension_script_path] = true
		result.append({
			"path": extension_script_path,
			"label": extension_script_path,
		})
	return result


## 加载有效 Debugger 插件脚本，安装到 EditorPlugin 后保存实例供清理。
## [br]
## @api private
func _add_debugger_plugin(plugin: EditorPlugin, script_path: String, label: String) -> void:
	var debugger_plugin: EditorDebuggerPlugin = _load_debugger_plugin(script_path, label)
	if debugger_plugin == null:
		return
	plugin.add_debugger_plugin(debugger_plugin)
	_debugger_plugins.append(debugger_plugin)


## 加载可实例化脚本，验证其继承 EditorDebuggerPlugin 并创建对应实例。
## 加载、类型或实例检查失败时记录错误并返回 null。
## [br]
## @api private
func _load_debugger_plugin(script_path: String, label: String) -> EditorDebuggerPlugin:
	var debugger_script: Script = _load_script(script_path)
	if debugger_script == null or not debugger_script.can_instantiate():
		push_error("[GFPluginDebuggerTools][plugin_debugger_tools.debugger_load_failed] Could not load the %s Debugger plugin script." % label)
		return null
	if not _is_editor_debugger_plugin_script(debugger_script):
		push_error(
			"[GFPluginDebuggerTools][plugin_debugger_tools.debugger_type_invalid] The %s Debugger plugin script must extend EditorDebuggerPlugin."
			% label
		)
		return null

	var instance: Variant = debugger_script.call("new")
	if instance is EditorDebuggerPlugin:
		var debugger_plugin: EditorDebuggerPlugin = instance
		return debugger_plugin

	push_error("[GFPluginDebuggerTools][plugin_debugger_tools.debugger_instantiation_failed] Could not instantiate the %s Debugger plugin." % label)
	return null


## 依据脚本 instance base type 判断其是否为 EditorDebuggerPlugin 或其子类。
## [br]
## @api private
func _is_editor_debugger_plugin_script(debugger_script: Script) -> bool:
	if debugger_script == null:
		return false
	var instance_base_type: StringName = debugger_script.get_instance_base_type()
	return (
		instance_base_type == &"EditorDebuggerPlugin"
		or ClassDB.is_parent_class(
			instance_base_type,
			&"EditorDebuggerPlugin"
		)
	)


## 拒绝空路径，加载资源并仅在资源为 Script 时返回。
## [br]
## @api private
func _load_script(script_path: String) -> Script:
	if script_path.is_empty():
		return null
	var resource: Resource = load(script_path)
	if resource is Script:
		var script: Script = resource
		return script
	return null


## 仅接受 Array 中的 Dictionary 项，并深复制每项；其他输入类型返回空数组。
## [br]
## @api private
func _to_record_array(value: Variant) -> Array[Dictionary]:
	var records: Array[Dictionary] = []
	if not value is Array:
		return records
	for record_variant: Variant in value:
		if record_variant is Dictionary:
			var record: Dictionary = record_variant
			records.append(record.duplicate(true))
	return records
