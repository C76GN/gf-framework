## GFShaderParameterBinder: 场景中的 Shader 参数 Profile 绑定节点。
##
## 将 `GFShaderParameterProfile` 应用到目标节点或材质，便于项目用可复用
## Resource 管理 ShaderMaterial uniform 参数。它只负责目标解析、材质复制选项、
## profile 变化监听和批量写入，不规定 shader、uniform 命名或视觉语义。
## [br]
## @api public
## [br]
## @category runtime_handle
## [br]
## @since 4.3.0
class_name GFShaderParameterBinder
extends Node


# --- 信号 ---

## Profile 应用完成时发出。
## [br]
## @api public
## [br]
## @param applied_count: 实际写入的参数数量。
signal profile_applied(applied_count: int)


# --- 导出变量 ---

## 要应用的 Shader 参数 Profile。
## [br]
## @api public
@export var profile: GFShaderParameterProfile = null:
	set(value):
		if profile == value:
			return
		_disconnect_profile_changed()
		profile = value
		_connect_profile_changed()
		if auto_apply_on_profile_changed and is_inside_tree():
			var _applied_count: int = apply()

## 目标节点路径。默认指向父节点，适合把 Binder 作为材质节点的子节点使用。
## [br]
## @api public
@export var target_path: NodePath = ^".."

## 当目标不是 ShaderMaterial 时，用于读取材质的属性路径。
## [br]
## @api public
@export var material_property: NodePath = ^"material"

## 进入场景树 ready 阶段时是否自动应用 profile。
## [br]
## @api public
@export var apply_on_ready: bool = true

## 是否在每帧 `_process()` 中重新应用 profile。
## [br]
## @api public
@export var apply_each_process: bool = false:
	set(value):
		apply_each_process = value
		set_process(apply_each_process)

## Profile 通过公开方法发出 changed 信号时是否自动应用。
## [br]
## @api public
@export var auto_apply_on_profile_changed: bool = true

## 应用前是否复制目标材质并写回 material_property，避免修改共享材质资源。
## [br]
## @api public
@export var duplicate_material_on_apply: bool = false

## 是否要求 shader 已声明 profile 中的 uniform 参数。
## [br]
## @api public
@export var require_declared_parameters: bool = true

## 目标或材质无效时是否输出 warning。
## [br]
## @api public
@export var warn_on_invalid_target: bool = true

## profile 中存在 shader 未声明参数时是否输出 warning。
## [br]
## @api public
@export var warn_on_missing_parameters: bool = true

## 写入参数前是否复制集合值，避免外部可变集合污染材质参数。
## [br]
## @api public
@export var copy_values: bool = true


# --- 私有变量 ---

var _shader_parameters: GFShaderParameterUtility = GFShaderParameterUtility.new()


# --- Godot 生命周期方法 ---

func _ready() -> void:
	_connect_profile_changed()
	set_process(apply_each_process)
	if apply_on_ready:
		var _applied_count: int = apply()


func _process(_delta: float) -> void:
	var _applied_count: int = apply()


func _exit_tree() -> void:
	_disconnect_profile_changed()


# --- 公共方法 ---

## 将当前 profile 应用到目标材质。
## [br]
## @api public
## [br]
## @return: 实际写入的参数数量。
func apply() -> int:
	if profile == null:
		return 0

	var target: Object = resolve_target()
	if target == null:
		return 0

	var applied_count: int = _shader_parameters.apply_profile(
		target,
		profile,
		_build_apply_options()
	)
	profile_applied.emit(applied_count)
	return applied_count


## 解析当前目标对象。
## [br]
## @api public
## [br]
## @return: 目标节点；解析失败时返回 null。
func resolve_target() -> Object:
	if target_path.is_empty():
		_warn_invalid_target("目标路径为空。")
		return null

	var target: Node = get_node_or_null(target_path)
	if target == null:
		_warn_invalid_target("目标节点不存在：%s。" % String(target_path))
		return null
	return target


# --- 私有/辅助方法 ---

func _build_apply_options() -> Dictionary:
	return {
		"material_property": material_property,
		"duplicate_material": duplicate_material_on_apply,
		"require_declared_parameters": require_declared_parameters,
		"warn_on_invalid_target": warn_on_invalid_target,
		"warn_on_missing_parameters": warn_on_missing_parameters,
		"copy_values": copy_values,
	}


func _connect_profile_changed() -> void:
	if profile == null:
		return
	if not profile.changed.is_connected(_on_profile_changed):
		var _changed_connected: Error = profile.changed.connect(_on_profile_changed) as Error


func _disconnect_profile_changed() -> void:
	if profile == null:
		return
	if profile.changed.is_connected(_on_profile_changed):
		profile.changed.disconnect(_on_profile_changed)


func _warn_invalid_target(message: String) -> void:
	if warn_on_invalid_target:
		push_warning("[GFShaderParameterBinder] %s" % message)


# --- 信号处理函数 ---

func _on_profile_changed() -> void:
	if not auto_apply_on_profile_changed or not is_inside_tree():
		return
	var _applied_count: int = apply()
