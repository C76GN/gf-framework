## GFActionInterceptionResult: 动作队列拦截器的处理结果。
##
## 用于在动作执行前后表达继续、跳过、替换或停止队列等通用决策。
## [br]
## @api public
## [br]
## @category value_object
## [br]
## @since 3.17.0
class_name GFActionInterceptionResult
extends RefCounted


# --- 枚举 ---

## 拦截器决策类型。
## [br]
## @api public
enum Decision {
	## 继续当前动作。
	CONTINUE,
	## 跳过当前动作并继续后续队列。
	SKIP,
	## 用 replacement_action 替换当前动作。
	REPLACE,
	## 停止并清空当前队列。
	STOP_QUEUE,
}


# --- 公共变量 ---

## 当前决策。
## [br]
## @api public
var decision: Decision = Decision.CONTINUE

## 替换动作，仅在 decision 为 REPLACE 时使用。
## [br]
## @api public
var replacement_action: Object = null

## 调用方自定义元数据。
## [br]
## @api public
## [br]
## @schema metadata: Dictionary，由项目或拦截器定义的附加诊断数据。
var metadata: Dictionary = {}


# --- Godot 生命周期方法 ---

func _init(
	p_decision: Decision = Decision.CONTINUE,
	p_replacement_action: Object = null,
	p_metadata: Dictionary = {}
) -> void:
	decision = p_decision
	replacement_action = p_replacement_action
	metadata = p_metadata.duplicate(true)


# --- 公共方法 ---

## 判断结果是否表示继续当前动作。
## [br]
## @api public
## [br]
## @return 继续时返回 true。
func is_continue() -> bool:
	return decision == Decision.CONTINUE


## 判断结果是否表示跳过当前动作。
## [br]
## @api public
## [br]
## @return 跳过时返回 true。
func is_skip() -> bool:
	return decision == Decision.SKIP


## 判断结果是否表示替换当前动作。
## [br]
## @api public
## [br]
## @return 替换时返回 true。
func is_replace() -> bool:
	return decision == Decision.REPLACE and replacement_action != null


## 判断结果是否表示停止队列。
## [br]
## @api public
## [br]
## @return 停止时返回 true。
func is_stop_queue() -> bool:
	return decision == Decision.STOP_QUEUE


## 创建继续结果。
## [br]
## @api public
## [br]
## @param p_metadata: 可选元数据。
## [br]
## @return 继续结果。
## [br]
## @schema p_metadata: Dictionary，由项目或拦截器定义的附加诊断数据。
static func continue_action(p_metadata: Dictionary = {}) -> GFActionInterceptionResult:
	return GFActionInterceptionResult.new(
		Decision.CONTINUE,
		null,
		p_metadata
	)


## 创建跳过结果。
## [br]
## @api public
## [br]
## @param p_metadata: 可选元数据。
## [br]
## @return 跳过结果。
## [br]
## @schema p_metadata: Dictionary，由项目或拦截器定义的附加诊断数据。
static func skip_action(p_metadata: Dictionary = {}) -> GFActionInterceptionResult:
	return GFActionInterceptionResult.new(
		Decision.SKIP,
		null,
		p_metadata
	)


## 创建替换结果。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @param action: 替换动作。
## [br]
## @param p_metadata: 可选元数据。
## [br]
## @return 替换结果。
## [br]
## @schema p_metadata: Dictionary，由项目或拦截器定义的附加诊断数据。
static func replace_with(action: Object, p_metadata: Dictionary = {}) -> GFActionInterceptionResult:
	if action == null:
		return continue_action(p_metadata)
	return GFActionInterceptionResult.new(
		Decision.REPLACE,
		action,
		p_metadata
	)


## 创建停止队列结果。
## [br]
## @api public
## [br]
## @param p_metadata: 可选元数据。
## [br]
## @return 停止队列结果。
## [br]
## @schema p_metadata: Dictionary，由项目或拦截器定义的附加诊断数据。
static func stop_queue(p_metadata: Dictionary = {}) -> GFActionInterceptionResult:
	return GFActionInterceptionResult.new(
		Decision.STOP_QUEUE,
		null,
		p_metadata
	)
