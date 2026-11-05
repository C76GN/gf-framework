## GFSavePipelineStep: 存档图流程步骤基类。
##
## 用于在 GFSaveGraphUtility 的 Scope 采集/应用流程前后插入通用处理。
## 步骤只接收 scope、payload、context 和 result，不绑定任何业务字段。
## [br]
## @api public
## [br]
## @category protocol
## [br]
## @since 3.17.0
class_name GFSavePipelineStep
extends Resource


# --- 导出变量 ---

## 步骤标识，便于调试与项目层开关。
## [br]
## @api public
@export var step_id: StringName = &""

## 是否启用该步骤。
## [br]
## @api public
@export var enabled: bool = true


# --- 可重写钩子 / 虚方法 ---

## 采集 Scope 前调用。
## [br]
## @api protected
## [br]
## @param _scope: 当前 Scope。
## [br]
## @param _context: 调用上下文字典。
## [br]
## @schema _context: Dictionary，可包含 pipeline_context、pipeline_shared、include_pipeline_trace 等流程字段。
func _before_gather_scope(_scope: GFSaveScope, _context: Dictionary = {}) -> void:
	pass


## 采集 Scope 后调用。返回 Dictionary 时会替换当前 payload。
## [br]
## @api protected
## [br]
## @since 3.17.0
## [br]
## @param _scope: 当前 Scope。
## [br]
## @param payload: 当前 Scope 载荷。
## [br]
## @param _context: 调用上下文字典。
## [br]
## @return 可返回 null 或替换后的 Dictionary。
## [br]
## @schema payload: Dictionary，当前 Scope 采集结果载荷。
## [br]
## @schema _context: Dictionary，可包含 pipeline_context、pipeline_shared、include_pipeline_trace 等流程字段。
## [br]
## @schema return: Variant，返回 Dictionary 会替换当前 payload；返回 null 或非 Dictionary 表示保持不变。
func _after_gather_scope(
	_scope: GFSaveScope,
	payload: Dictionary,
	_context: Dictionary = {}
) -> Variant:
	return payload


## 应用 Scope 前调用。返回 Dictionary 时会替换当前 payload。
## [br]
## @api protected
## [br]
## @since 3.17.0
## [br]
## @param _scope: 当前 Scope。
## [br]
## @param payload: 当前 Scope 载荷。
## [br]
## @param _context: 调用上下文字典。
## [br]
## @return 可返回 null 或替换后的 Dictionary。
## [br]
## @schema payload: Dictionary，当前 Scope 待应用载荷。
## [br]
## @schema _context: Dictionary，可包含 pipeline_context、pipeline_shared、include_pipeline_trace 等流程字段。
## [br]
## @schema return: Variant，返回 Dictionary 会替换当前 payload；返回 null 或非 Dictionary 表示保持不变。
func _before_apply_scope(
	_scope: GFSaveScope,
	payload: Dictionary,
	_context: Dictionary = {}
) -> Variant:
	return payload


## 外层应用已完成提交或回滚时，按子 Scope 在先的顺序观察各 Scope 的应用结果。
## 诊断可写入 Pipeline Context；要否决本次应用，应在提交前登记事务参与者。
## [br]
## @api protected
## [br]
## @since 3.17.0
## [br]
## @param _scope: 当前 Scope。
## [br]
## @param _payload: 当前 Scope 载荷。
## [br]
## @param result: 当前 Scope 的结果副本。根 Scope 包含整次事务的回滚结果。
## [br]
## @param _context: 调用上下文字典。
## [br]
## @return 调度方忽略返回值；重写可返回 null。
## [br]
## @schema _payload: Dictionary，交给当前 Scope 应用的载荷副本。
## [br]
## @schema result: Dictionary，包含 ok、applied、errors、missing 等字段；修改副本只影响当前观察。
## [br]
## @schema _context: Dictionary，可包含 pipeline_context、pipeline_shared、include_pipeline_trace 等流程字段。
## [br]
## @schema return: Variant，保留既有重写签名；返回值不参与事务或结果传递。
func _after_apply_scope(
	_scope: GFSaveScope,
	_payload: Dictionary,
	result: Dictionary,
	_context: Dictionary = {}
) -> Variant:
	return result
