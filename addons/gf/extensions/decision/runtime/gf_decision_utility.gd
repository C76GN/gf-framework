## GFDecisionUtility: 通用决策集合注册与评分服务。
##
## 在架构中集中管理 GFDecisionSet，并为项目系统提供创建上下文、评分候选和选择最佳候选的入口。
## 它不执行候选动作，也不解释具体 AI 业务语义。
## [br]
## @api public
## [br]
## @category runtime_service
## [br]
## @since 4.3.0
class_name GFDecisionUtility
extends GFUtility


# --- 信号 ---

## 当决策集合注册后发出。
## [br]
## @api public
## [br]
## @param decision_set_id: 决策集合标识。
## [br]
## @param decision_set: 已注册的决策集合。
signal decision_set_registered(decision_set_id: StringName, decision_set: GFDecisionSet)

## 当决策集合注销后发出。
## [br]
## @api public
## [br]
## @param decision_set_id: 决策集合标识。
signal decision_set_unregistered(decision_set_id: StringName)


# --- 私有变量 ---

var _decision_sets: Dictionary = {}


# --- GF 生命周期方法 ---

## 清理决策集合注册表。
## [br]
## @api framework_internal
func dispose() -> void:
	clear_decision_sets()


# --- 公共方法 ---

## 创建决策上下文。
## [br]
## @api public
## [br]
## @param values: 初始黑板值。
## [br]
## @param subject: 决策主体。
## [br]
## @param target: 可选决策目标。
## [br]
## @param metadata: 上下文元数据。
## [br]
## @return: 新决策上下文。
## [br]
## @schema values: Dictionary[StringName, Variant] initial blackboard values.
## [br]
## @schema metadata: Dictionary[StringName, Variant] project-defined decision metadata.
func make_context(
	values: Dictionary = {},
	subject: Object = null,
	target: Object = null,
	metadata: Dictionary = {}
) -> GFDecisionContext:
	return GFDecisionContext.new(GFDecisionBlackboard.new(values), subject, target, metadata)


## 注册决策集合。
## [br]
## @api public
## [br]
## @param decision_set_id: 决策集合标识。
## [br]
## @param decision_set: 决策集合资源。
## [br]
## @return: 注册成功返回 true。
func register_decision_set(decision_set_id: StringName, decision_set: GFDecisionSet) -> bool:
	if decision_set_id == &"" or decision_set == null:
		return false
	if _decision_sets.has(decision_set_id):
		return false

	if decision_set.decision_set_id == &"":
		decision_set.decision_set_id = decision_set_id
	_decision_sets[decision_set_id] = decision_set
	decision_set_registered.emit(decision_set_id, decision_set)
	return true


## 注销决策集合。
## [br]
## @api public
## [br]
## @param decision_set_id: 决策集合标识。
## [br]
## @return: 注销成功返回 true。
func unregister_decision_set(decision_set_id: StringName) -> bool:
	if not _decision_sets.has(decision_set_id):
		return false

	var _erase_result: Variant = _decision_sets.erase(decision_set_id)
	decision_set_unregistered.emit(decision_set_id)
	return true


## 检查决策集合是否存在。
## [br]
## @api public
## [br]
## @param decision_set_id: 决策集合标识。
## [br]
## @return: 存在返回 true。
func has_decision_set(decision_set_id: StringName) -> bool:
	return _decision_sets.has(decision_set_id)


## 获取决策集合。
## [br]
## @api public
## [br]
## @param decision_set_id: 决策集合标识。
## [br]
## @return: 决策集合；不存在时返回 null。
func get_decision_set(decision_set_id: StringName) -> GFDecisionSet:
	var value: Variant = _decision_sets.get(decision_set_id)
	if value is GFDecisionSet:
		var decision_set: GFDecisionSet = value
		return decision_set
	return null


## 获取已注册决策集合标识。
## [br]
## @api public
## [br]
## @return: 排序后的决策集合标识。
func get_decision_set_ids() -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	for decision_set_id_variant: Variant in _decision_sets.keys():
		var _append_result: Variant = result.append(GFVariantData.to_text(decision_set_id_variant))
	result.sort()
	return result


## 清空全部决策集合。
## [br]
## @api public
func clear_decision_sets() -> void:
	var registered_ids: Array[StringName] = []
	for decision_set_id_variant: Variant in _decision_sets.keys():
		registered_ids.append(StringName(GFVariantData.to_text(decision_set_id_variant)))
	registered_ids.sort()
	_decision_sets.clear()
	for decision_set_id: StringName in registered_ids:
		decision_set_unregistered.emit(decision_set_id)


## 计算指定决策集合中的所有候选分数。
## [br]
## @api public
## [br]
## @param decision_set_id: 决策集合标识。
## [br]
## @param context: 决策上下文。
## [br]
## @return: 按分数降序排列的评分结果。
## [br]
## @schema return: Array[GFDecisionScore]，每个候选的评分结果；集合不存在时为空数组。
func score_all(decision_set_id: StringName, context: GFDecisionContext) -> Array[GFDecisionScore]:
	var decision_set: GFDecisionSet = get_decision_set(decision_set_id)
	if decision_set == null:
		return []
	return decision_set.score_all(context)


## 选择指定决策集合中的最佳候选。
## [br]
## @api public
## [br]
## @param decision_set_id: 决策集合标识。
## [br]
## @param context: 决策上下文。
## [br]
## @return: 最佳评分结果；集合不存在时返回 rejected score。
func select_best(decision_set_id: StringName, context: GFDecisionContext) -> GFDecisionScore:
	var decision_set: GFDecisionSet = get_decision_set(decision_set_id)
	if decision_set == null:
		return GFDecisionScore.new(null, 0.0, [], false)
	return decision_set.select_best(context)


## 获取决策服务调试快照。
## [br]
## @api public
## [br]
## @return: 调试快照字典。
## [br]
## @schema return: 包含 decision_set_count 和 decision_set_ids 字段的 Dictionary。
func get_debug_snapshot() -> Dictionary:
	return {
		"decision_set_count": _decision_sets.size(),
		"decision_set_ids": get_decision_set_ids(),
	}
