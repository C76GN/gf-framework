@tool

# GF 插件 Debugger 插件管理辅助。
extends RefCounted


# --- 常量 ---

const _GF_VARIANT_ACCESS_SCRIPT = preload("res://addons/gf/kernel/core/gf_variant_access.gd")


# --- 私有变量 ---

var _debugger_plugins: Array[EditorDebuggerPlugin] = []
var _standard_debugger_records: Array[Dictionary] = []


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
func setup(plugin: EditorPlugin, standard_records: Dictionary = {}) -> void:
	if plugin == null:
		return
	_standard_debugger_records = _to_record_array(
		_GF_VARIANT_ACCESS_SCRIPT.get_option_value(standard_records, "debugger_plugin_records", [])
	)
	for record: Dictionary in _standard_debugger_records:
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

func _add_debugger_plugin(plugin: EditorPlugin, script_path: String, label: String) -> void:
	var debugger_plugin: EditorDebuggerPlugin = _load_debugger_plugin(script_path, label)
	if debugger_plugin == null:
		return
	plugin.add_debugger_plugin(debugger_plugin)
	_debugger_plugins.append(debugger_plugin)


func _load_debugger_plugin(script_path: String, label: String) -> EditorDebuggerPlugin:
	var debugger_script: Script = _load_script(script_path)
	if debugger_script == null or not debugger_script.can_instantiate():
		push_error("[GF Framework] %s Debugger 插件脚本加载失败。" % label)
		return null

	var instance: Variant = debugger_script.call("new")
	if instance is EditorDebuggerPlugin:
		var debugger_plugin: EditorDebuggerPlugin = instance
		return debugger_plugin

	push_error("[GF Framework] %s Debugger 插件实例化失败。" % label)
	return null


func _load_script(script_path: String) -> Script:
	if script_path.is_empty():
		return null
	var resource: Resource = load(script_path)
	if resource is Script:
		var script: Script = resource
		return script
	return null


func _to_record_array(value: Variant) -> Array[Dictionary]:
	var records: Array[Dictionary] = []
	if not value is Array:
		return records
	for record_variant: Variant in value:
		if record_variant is Dictionary:
			var record: Dictionary = record_variant
			records.append(record.duplicate(true))
	return records
