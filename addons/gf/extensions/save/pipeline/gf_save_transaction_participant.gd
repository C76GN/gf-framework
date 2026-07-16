## GFSaveTransactionParticipant: 存档应用事务参与者基类。
##
## 项目侧或流程步骤可在 GFSavePipelineContext 中登记参与者，
## 让 apply_scope 统一调度 prepare / commit / rollback，避免外部副作用绕过存档事务。
## [br]
## @api public
## [br]
## @category protocol
## [br]
## @since 8.0.0
class_name GFSaveTransactionParticipant
extends Resource


# --- 导出变量 ---

## 参与者标识，用于诊断和流程 trace。
## [br]
## @api public
## [br]
## @since 8.0.0
@export var participant_id: StringName = &""


# --- 公共方法 ---

## 执行 prepare 阶段。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param context: apply_scope 调用上下文字典。
## [br]
## @return 结果字典。
## [br]
## @schema context: Dictionary，可包含 pipeline_context、pipeline_shared、include_pipeline_trace、transactional_apply 及项目自定义键。
## [br]
## @schema return: Dictionary，包含 ok、errors 和 participant_id。
func prepare(context: Dictionary = {}) -> Dictionary:
	return _normalize_result(_prepare_transaction(context))


## 执行 commit 阶段。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param context: apply_scope 调用上下文字典。
## [br]
## @return 结果字典。
## [br]
## @schema context: Dictionary，可包含 pipeline_context、pipeline_shared、include_pipeline_trace、transactional_apply 及项目自定义键。
## [br]
## @schema return: Dictionary，包含 ok、errors 和 participant_id。
func commit(context: Dictionary = {}) -> Dictionary:
	return _normalize_result(_commit_transaction(context))


## 执行 rollback 阶段。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param context: apply_scope 调用上下文字典。
## [br]
## @return 结果字典。
## [br]
## @schema context: Dictionary，可包含 pipeline_context、pipeline_shared、include_pipeline_trace、transactional_apply 及项目自定义键。
## [br]
## @schema return: Dictionary，包含 ok、errors 和 participant_id。
func rollback(context: Dictionary = {}) -> Dictionary:
	return _normalize_result(_rollback_transaction(context))


## 构造统一结果。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param ok: 是否成功。
## [br]
## @param errors: 错误列表。
## [br]
## @return 结果字典。
## [br]
## @schema errors: Array[String] 错误消息。
## [br]
## @schema return: Dictionary，包含 ok、errors 和 participant_id。
func make_result(ok: bool, errors: Array[String] = []) -> Dictionary:
	return {
		"ok": ok,
		"errors": errors,
		"participant_id": participant_id,
	}


# --- 可重写钩子 / 虚方法 ---

## prepare 阶段钩子。失败会阻止 commit，并触发统一 rollback。
## [br]
## @api protected
## [br]
## @since 8.0.0
## [br]
## @param _context: apply_scope 调用上下文字典。
## [br]
## @return 结果字典。
## [br]
## @schema _context: Dictionary，可包含 pipeline_context、pipeline_shared、include_pipeline_trace、transactional_apply 及项目自定义键。
## [br]
## @schema return: Dictionary，包含 ok 与 errors；返回空字典视为成功。
func _prepare_transaction(_context: Dictionary = {}) -> Dictionary:
	return make_result(true)


## commit 阶段钩子。失败会触发统一 rollback。
## [br]
## @api protected
## [br]
## @since 8.0.0
## [br]
## @param _context: apply_scope 调用上下文字典。
## [br]
## @return 结果字典。
## [br]
## @schema _context: Dictionary，可包含 pipeline_context、pipeline_shared、include_pipeline_trace、transactional_apply 及项目自定义键。
## [br]
## @schema return: Dictionary，包含 ok 与 errors；返回空字典视为成功。
func _commit_transaction(_context: Dictionary = {}) -> Dictionary:
	return make_result(true)


## rollback 阶段钩子。返回失败时只记录诊断，不再抛出新异常。
## [br]
## @api protected
## [br]
## @since 8.0.0
## [br]
## @param _context: apply_scope 调用上下文字典。
## [br]
## @return 结果字典。
## [br]
## @schema _context: Dictionary，可包含 pipeline_context、pipeline_shared、include_pipeline_trace、transactional_apply 及项目自定义键。
## [br]
## @schema return: Dictionary，包含 ok 与 errors；返回空字典视为成功。
func _rollback_transaction(_context: Dictionary = {}) -> Dictionary:
	return make_result(true)


# --- 私有/辅助方法 ---

func _normalize_result(result: Dictionary) -> Dictionary:
	var errors: Array[String] = GFVariantData.to_string_array(GFVariantData.get_option_value(result, "errors", []))
	var error_message: String = GFVariantData.get_option_string(result, "error")
	if not error_message.is_empty():
		errors.append(error_message)
	return make_result(GFVariantData.get_option_bool(result, "ok", errors.is_empty()), errors)
