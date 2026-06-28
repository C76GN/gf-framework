@tool

# GF 标准库编辑器扩展声明。
extends RefCounted


# --- 公共方法 ---

## 获取标准库 Inspector 插件记录。
## [br]
## @api framework_internal
## [br]
## @layer standard/editor
## [br]
## @return Inspector 插件记录列表。
## [br]
## @schema return: Array of Dictionary inspector plugin records.
static func get_inspector_plugin_records() -> Array[Dictionary]:
	return [
		{
			"path": "res://addons/gf/standard/state_machine/node/editor/gf_node_state_machine_inspector_plugin.gd",
			"label": "节点状态机 Inspector",
		},
		{
			"path": "res://addons/gf/standard/foundation/math/editor/gf_pattern_2d_inspector_plugin.gd",
			"label": "Pattern2D Inspector",
		},
		{
			"path": "res://addons/gf/standard/utilities/audio/editor/gf_audio_bank_inspector_plugin.gd",
			"label": "AudioBank Inspector",
		},
	]


## 获取标准库导出插件记录。
## [br]
## @api framework_internal
## [br]
## @layer standard/editor
## [br]
## @return 导出插件记录列表。
## [br]
## @schema return: Array of Dictionary export plugin records.
static func get_export_plugin_records() -> Array[Dictionary]:
	return [
		{
			"path": "res://addons/gf/standard/utilities/debug/editor/gf_build_info_export_plugin.gd",
			"label": "构建信息导出插件",
		},
	]


## 获取标准库 Debugger 插件记录。
## [br]
## @api framework_internal
## [br]
## @layer standard/editor
## [br]
## @return Debugger 插件记录列表。
## [br]
## @schema return: Array of Dictionary debugger plugin records.
static func get_debugger_plugin_records() -> Array[Dictionary]:
	return [
		{
			"path": "res://addons/gf/standard/utilities/debug/editor/gf_runtime_debugger_plugin.gd",
			"label": "GF Runtime Debugger",
		},
	]


## 获取标准库 ProjectSettings 记录。
## [br]
## @api framework_internal
## [br]
## @layer standard/editor
## [br]
## @return ProjectSettings 记录列表。
## [br]
## @schema return: Array of Dictionary project setting records.
static func get_project_setting_records() -> Array[Dictionary]:
	return [
		{
			"name": GFBuildInfo.EXPORT_ENABLED_SETTING,
			"default_value": false,
			"type": TYPE_BOOL,
			"basic": true,
		},
		{
			"name": GFBuildInfo.EXPORT_RESTORE_PREVIOUS_SETTING,
			"default_value": true,
			"type": TYPE_BOOL,
			"basic": true,
		},
		{
			"name": GFBuildInfo.EXPORT_SAVE_PROJECT_SETTINGS_SETTING,
			"default_value": false,
			"type": TYPE_BOOL,
			"basic": true,
		},
		{
			"name": GFBuildInfo.EXPORT_BUILD_METADATA_SETTING,
			"default_value": {},
			"type": TYPE_DICTIONARY,
			"basic": true,
		},
		{
			"name": GFBuildInfo.EXPORT_EXTRA_METADATA_SETTING,
			"default_value": {},
			"type": TYPE_DICTIONARY,
			"basic": true,
		},
	]


## 获取标准库工作区页面记录。
## [br]
## @api framework_internal
## [br]
## @layer standard/editor
## [br]
## @return 工作区页面记录列表。
## [br]
## @schema return: Array of Dictionary dock page records.
static func get_dock_records() -> Array[Dictionary]:
	return [
		{
			"path": "res://addons/gf/standard/state_machine/node/editor/gf_node_state_machine_dock.gd",
			"label": "GF State Tools",
			"short_label": "状态",
			"order": 10,
		},
		{
			"path": "res://addons/gf/standard/input/editor/gf_input_mapping_dock.gd",
			"label": "GF Input Mapping",
			"short_label": "输入",
			"order": 20,
		},
		{
			"path": "res://addons/gf/standard/utilities/storage/editor/gf_storage_viewer_dock.gd",
			"label": "GF Storage Viewer",
			"short_label": "存储",
			"order": 50,
		},
		{
			"path": "res://addons/gf/standard/utilities/debug/editor/gf_signal_graph_dock.gd",
			"label": "GF Signal Diagnostics",
			"short_label": "信号诊断",
			"order": 60,
		},
		{
			"path": "res://addons/gf/standard/utilities/debug/editor/gf_diagnostics_dock.gd",
			"label": "GF Diagnostics",
			"short_label": "诊断",
			"order": 70,
		},
	]


## 获取标准库脚本模板记录。
## [br]
## @api framework_internal
## [br]
## @layer standard/editor
## [br]
## @return 脚本模板记录列表。
## [br]
## @schema return: Array of Dictionary script template records.
static func get_template_records() -> Array[Dictionary]:
	return [
		{
			"type": "NodeState",
			"label": "生成 NodeState",
			"section": "扩展模板",
			"base_class": "GFNodeState",
			"template": _get_node_state_template(),
		},
		{
			"type": "NodeStateMachine",
			"label": "生成 NodeStateMachine",
			"section": "扩展模板",
			"base_class": "GFNodeStateMachine",
			"template": _get_node_state_machine_template(),
		},
	]


# --- 私有/辅助方法 ---

static func _get_node_state_template() -> String:
	return """## {ClassName}: TODO。
class_name {ClassName}
extends {BaseClass}


# --- 信号 ---


# --- 枚举 ---


# --- 常量 ---


# --- 导出变量 ---


# --- 公共变量 ---


# --- 私有变量 ---


# --- @onready 变量 (节点引用) ---


# --- 公共方法 ---


# --- 虚方法（由子类重写） ---

func _initialize() -> void:
	pass


func _enter(_previous_state: StringName = &"", _args: Dictionary = {}) -> void:
	pass


func _exit(_next_state: StringName = &"", _args: Dictionary = {}) -> void:
	pass


func _pause(_next_state: StringName = &"", _args: Dictionary = {}) -> void:
	pass


func _resume(_previous_state: StringName = &"", _args: Dictionary = {}) -> void:
	pass


# --- 私有/辅助方法 ---


# --- 信号处理函数 ---

"""


static func _get_node_state_machine_template() -> String:
	return """## {ClassName}: TODO。
class_name {ClassName}
extends {BaseClass}


# --- 信号 ---


# --- 枚举 ---


# --- 常量 ---


# --- 导出变量 ---


# --- 公共变量 ---


# --- 私有变量 ---


# --- @onready 变量 (节点引用) ---


# --- Godot 生命周期方法 ---

func _ready() -> void:
	super._ready()


# --- 公共方法 ---


# --- 私有/辅助方法 ---


# --- 信号处理函数 ---

"""
