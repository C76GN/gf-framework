@tool

# GF Capability 扩展的访问器生成扩展。
#
# 负责把能力脚本记录贡献给 GFAccessGenerator，避免 kernel 硬编码可选扩展路径。
extends RefCounted


# --- 常量 ---

## 访问器生成器脚本资源。
## [br]
## @api private
const _GF_ACCESS_GENERATOR_SCRIPT = preload("res://addons/gf/kernel/editor/gf_access_generator.gd")

## 脚本继承关系检查器资源。
## [br]
## @api private
const _SCRIPT_TYPE_INSPECTOR = preload("res://addons/gf/kernel/core/gf_script_type_inspector.gd")

## 基础 Capability 脚本资源。
## [br]
## @api private
const _BASE_CAPABILITY_SCRIPT = preload("res://addons/gf/extensions/capability/core/gf_capability.gd")

## Node Capability 基类脚本资源。
## [br]
## @api private
const _BASE_NODE_CAPABILITY_SCRIPT = preload("res://addons/gf/extensions/capability/nodes/gf_node_capability.gd")

## Node2D Capability 基类脚本资源。
## [br]
## @api private
const _BASE_NODE_2D_CAPABILITY_SCRIPT = preload("res://addons/gf/extensions/capability/nodes/gf_node_2d_capability.gd")

## Node3D Capability 基类脚本资源。
## [br]
## @api private
const _BASE_NODE_3D_CAPABILITY_SCRIPT = preload("res://addons/gf/extensions/capability/nodes/gf_node_3d_capability.gd")

## Control Capability 基类脚本资源。
## [br]
## @api private
const _BASE_CONTROL_CAPABILITY_SCRIPT = preload("res://addons/gf/extensions/capability/nodes/gf_control_capability.gd")

## Capability Utility 的资源路径。
## [br]
## @api private
const _CAPABILITY_UTILITY_SCRIPT_PATH: String = "res://addons/gf/extensions/capability/core/gf_capability_utility.gd"

## 用于识别 Capability 子类的基类脚本列表。
## [br]
## @api private
const _CAPABILITY_BASE_SCRIPTS: Array[Script] = [
	_BASE_CAPABILITY_SCRIPT,
	_BASE_NODE_CAPABILITY_SCRIPT,
	_BASE_NODE_2D_CAPABILITY_SCRIPT,
	_BASE_NODE_3D_CAPABILITY_SCRIPT,
	_BASE_CONTROL_CAPABILITY_SCRIPT,
]


# --- 框架内部方法 ---

## 向访问器记录列表追加当前项目中可识别的 Capability 类型。
## [br]
## @api framework_internal
## [br]
## @param records: GFAccessGenerator 收集到的记录数组，会被原地追加。
## [br]
## @schema records: Array[Dictionary]，GFAccessGenerator 记录数组；会原地追加 class_name、path、kind、utility_path。
func append_access_records(records: Array[Dictionary]) -> void:
	var existing_paths: Dictionary = {}
	for record: Dictionary in records:
		var existing_path: String = GFVariantData.get_option_string(record, "path", "")
		if not existing_path.is_empty():
			existing_paths[existing_path] = true

	for global_class: Dictionary in ProjectSettings.get_global_class_list():
		var class_name_value: String = GFVariantData.get_option_string(global_class, "class", "")
		var path: String = GFVariantData.get_option_string(global_class, "path", "")
		if class_name_value.is_empty() or path.is_empty() or existing_paths.has(path):
			continue

		var script: Script = _load_script(path)
		if script == null or not _is_capability_script(script):
			continue

		records.append(_make_access_record(class_name_value, path))
		existing_paths[path] = true


# --- 私有/辅助方法 ---

## 加载路径资源并收窄为 Script。
## [br]
## @api private
func _load_script(path: String) -> Script:
	var resource: Resource = load(path)
	if resource is Script:
		var script: Script = resource
		return script
	return null


## 构造 Capability 访问器生成记录。
## [br]
## @api private
func _make_access_record(class_name_value: String, path: String) -> Dictionary:
	return {
		"class_name": class_name_value,
		"path": path,
		"kind": _GF_ACCESS_GENERATOR_SCRIPT.TargetKind.CAPABILITY,
		"utility_path": _CAPABILITY_UTILITY_SCRIPT_PATH,
	}


## 排除 Capability 基类并检查脚本是否继承受支持的基类。
## [br]
## @api private
func _is_capability_script(script: Script) -> bool:
	if script == null:
		return false
	if script == _BASE_CAPABILITY_SCRIPT or script == _BASE_NODE_CAPABILITY_SCRIPT:
		return false
	for base_script: Script in _CAPABILITY_BASE_SCRIPTS:
		if _SCRIPT_TYPE_INSPECTOR.script_extends_or_equals(script, base_script):
			return true
	return false
