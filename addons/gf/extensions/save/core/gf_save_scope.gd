## GFSaveScope: 存档图作用域节点。
##
## Scope 定义一次保存/加载的边界。它可嵌套组织子 Scope，但不假设具体业务结构。
## [br]
## @api public
## [br]
## @category protocol
## [br]
## @since 3.17.0
class_name GFSaveScope
extends Node


# --- 枚举 ---

## 恢复未知实体时的处理策略。
## [br]
## @api public
enum RestorePolicy {
	## 只把数据应用到已存在的 Source。
	APPLY_ONLY_EXISTING,
	## 允许 GFSaveGraphUtility 使用注册的工厂补建实体。
	ALLOW_FACTORIES,
}


## Scope/Source 执行阶段。
## [br]
## @api public
enum Phase {
	## 早期执行。
	EARLY,
	## 普通执行。
	NORMAL,
	## 后期执行。
	LATE,
}


# --- 导出变量 ---

## Scope 稳定标识。留空时回退到节点名。
## [br]
## @api public
@export var scope_key: StringName = &""

## 可选键命名空间。用于多处复用同名子结构时隔离 source key。
## [br]
## @api public
@export var key_namespace: StringName = &""

## 是否启用该 Scope。
## [br]
## @api public
@export var enabled: bool = true

## 是否参与保存。
## [br]
## @api public
@export var save_enabled: bool = true

## 是否参与加载。
## [br]
## @api public
@export var load_enabled: bool = true

## 执行阶段。
## [br]
## @api public
@export var phase: Phase = Phase.NORMAL

## 恢复策略。
## [br]
## @api public
@export var restore_policy: RestorePolicy = RestorePolicy.APPLY_ONLY_EXISTING


# --- 公共方法 ---

## 获取 Scope 稳定标识。
## [br]
## @api public
## [br]
## @return 作用域键。
func get_scope_key() -> StringName:
	if scope_key != &"":
		return scope_key
	return StringName(name)


## 获取来源键前缀。
## [br]
## @api public
## [br]
## @return 前缀字符串。
func get_key_prefix() -> String:
	return String(key_namespace)


## 返回当前 Scope 的通用描述。
## [br]
## @api public
## [br]
## @return 描述字典。
## [br]
## @schema return: Dictionary，包含 scope_key、key_namespace、phase 与 restore_policy。
func describe_scope() -> Dictionary:
	return {
		"scope_key": get_scope_key(),
		"key_namespace": key_namespace,
		"phase": phase,
		"restore_policy": restore_policy,
	}


# --- 可重写钩子 / 虚方法 ---

## 判断是否可保存。
## [br]
## @api protected
## [br]
## @param _context: 调用上下文字典。
## [br]
## @return 可保存时返回 true。
## [br]
## @schema _context: Dictionary，可包含 pipeline_context、pipeline_shared、include_pipeline_trace 等流程字段。
func _can_save_scope(_context: Dictionary = {}) -> bool:
	return enabled and save_enabled


## 判断是否可加载。
## [br]
## @api protected
## [br]
## @param _context: 调用上下文字典。
## [br]
## @return 可加载时返回 true。
## [br]
## @schema _context: Dictionary，可包含 pipeline_context、pipeline_shared、include_pipeline_trace 等流程字段。
func _can_load_scope(_context: Dictionary = {}) -> bool:
	return enabled and load_enabled


## 保存前 Hook。
## [br]
## @api protected
## [br]
## @param _context: 调用上下文字典。
## [br]
## @schema _context: Dictionary，可包含 pipeline_context、pipeline_shared、include_pipeline_trace 等流程字段。
func _before_save(_context: Dictionary = {}) -> void:
	pass


## 保存后 Hook。
## [br]
## @api protected
## [br]
## @param _payload: 当前 Scope 载荷。
## [br]
## @param _context: 调用上下文字典。
## [br]
## @schema _payload: Dictionary，当前 Scope 采集完成后的载荷。
## [br]
## @schema _context: Dictionary，可包含 pipeline_context、pipeline_shared、include_pipeline_trace 等流程字段。
func _after_save(_payload: Dictionary, _context: Dictionary = {}) -> void:
	pass


## 加载前 Hook。
## [br]
## @api protected
## [br]
## @param _payload: 当前 Scope 载荷。
## [br]
## @param _context: 调用上下文字典。
## [br]
## @schema _payload: Dictionary，当前 Scope 待应用的载荷。
## [br]
## @schema _context: Dictionary，可包含 pipeline_context、pipeline_shared、include_pipeline_trace 等流程字段。
func _before_load(_payload: Dictionary, _context: Dictionary = {}) -> void:
	pass


## 加载后 Hook。
## [br]
## @api protected
## [br]
## @param _payload: 当前 Scope 载荷。
## [br]
## @param _context: 调用上下文字典。
## [br]
## @schema _payload: Dictionary，当前 Scope 已应用的载荷。
## [br]
## @schema _context: Dictionary，可包含 pipeline_context、pipeline_shared、include_pipeline_trace 等流程字段。
func _after_load(_payload: Dictionary, _context: Dictionary = {}) -> void:
	pass
