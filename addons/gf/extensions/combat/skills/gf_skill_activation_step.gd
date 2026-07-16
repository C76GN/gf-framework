## GFSkillActivationStep: 技能激活事务步骤协议。
##
## 项目侧通过继承实现验证、应用与回滚；步骤不保存单次施放状态，所有运行时数据
## 应写入 GFSkillActivationContext 或项目自己的事务对象。
## [br]
## @api public
## [br]
## @category protocol
## [br]
## @since 8.0.0
class_name GFSkillActivationStep
extends RefCounted


# --- 公共变量 ---

## 步骤 ID；同一技能中的步骤 ID 必须唯一且非空。
## [br]
## @api public
## [br]
## @since 8.0.0
var step_id: StringName = &""

## 应用成功后是否必须支持回滚。
## [br]
## @api public
## [br]
## @since 8.0.0
var rollback_required: bool = true


# --- 公共方法 ---

## 配置步骤并返回自身。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param p_step_id: 步骤 ID。
## [br]
## @param p_rollback_required: 应用成功后是否必须支持回滚。
## [br]
## @return 当前步骤。
func configure(
	p_step_id: StringName,
	p_rollback_required: bool = true
) -> GFSkillActivationStep:
	step_id = p_step_id
	rollback_required = p_rollback_required
	return self


# --- 可重写钩子 / 虚方法 ---

## 无副作用地验证当前步骤。
## [br]
## @api protected
## [br]
## @since 8.0.0
## [br]
## @param _context: 本次技能激活上下文。
## [br]
## @return `bool`、`Error` 或包含 `ok`、`reason`、`metadata` 的 Dictionary。
## [br]
## @schema return: Variant，可为 bool、Error 或 Dictionary；回调必须同步返回。
func _validate_activation(_context: GFSkillActivationContext) -> Variant:
	return true


## 应用步骤副作用。
## [br]
## @api protected
## [br]
## @since 8.0.0
## [br]
## @param _context: 本次技能激活上下文。
## [br]
## @return `bool`、`Error` 或包含 `ok`、`reason`、`metadata` 的 Dictionary。
## [br]
## @schema return: Variant，可为 bool、Error 或 Dictionary；回调必须同步返回。
func _apply_activation(_context: GFSkillActivationContext) -> Variant:
	return {
		"ok": false,
		"reason": &"activation_step_apply_not_implemented",
	}


## 回滚已经成功应用的步骤。
## [br]
## @api protected
## [br]
## @since 8.0.0
## [br]
## @param _context: 本次技能激活上下文。
## [br]
## @return `bool`、`Error` 或包含 `ok`、`reason`、`metadata` 的 Dictionary。
## [br]
## @schema return: Variant，可为 bool、Error 或 Dictionary；回调必须同步返回。
func _rollback_activation(_context: GFSkillActivationContext) -> Variant:
	return {
		"ok": false,
		"reason": &"activation_step_rollback_not_implemented",
	}
