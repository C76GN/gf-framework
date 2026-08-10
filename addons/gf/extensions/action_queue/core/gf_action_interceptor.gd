## GFActionInterceptor: 动作队列的通用拦截器基类。
##
## 拦截器可在表现动作执行前后做横切处理，例如跳过、替换、停止后续队列、
## 记录诊断或根据运行时状态调整表现，不绑定任何具体玩法规则。
## [br]
## @api public
## [br]
## @category protocol
## [br]
## @since 3.17.0
class_name GFActionInterceptor
extends RefCounted


# --- 公共变量 ---

## 拦截器优先级，数值越大越早执行。运行期修改从下一次拦截阶段快照开始生效；
## 相同优先级按注册顺序执行。
## [br]
## @api public
## [br]
## @since 11.0.0
var priority: int = 0

## 是否启用当前拦截器。
## [br]
## @api public
var enabled: bool = true


# --- Godot 生命周期方法 ---

func _init(p_priority: int = 0, p_enabled: bool = true) -> void:
	priority = p_priority
	enabled = p_enabled


# --- 可重写钩子 / 虚方法 ---

## 动作执行前调用。
## [br]
## @api protected
## [br]
## @param _action: 即将执行的动作。
## [br]
## @param _queue: 当前动作队列。
## [br]
## @return 拦截结果；返回 null 等价于继续。
func _before_execute(
	_action: Object,
	_queue: GFActionQueueSystem
) -> GFActionInterceptionResult:
	return GFActionInterceptionResult.continue_action()


## 动作执行并完成等待后调用。
## [br]
## @api protected
## [br]
## @param _action: 已执行的动作。
## [br]
## @param _queue: 当前动作队列。
## [br]
## @param _execute_result: 动作 execute() 的原始返回值。
## [br]
## @return 拦截结果；当前仅 STOP_QUEUE 会影响后续队列。
## [br]
## @schema _execute_result: Variant，由动作 execute() 返回的原始结果，可能是 Signal 或项目自定义值。
func _after_execute(
	_action: Object,
	_queue: GFActionQueueSystem,
	_execute_result: Variant
) -> GFActionInterceptionResult:
	return GFActionInterceptionResult.continue_action()
