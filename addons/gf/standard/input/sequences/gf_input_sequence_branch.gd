## GFInputSequenceBranch: 输入序列触发器的一条可选分支。
##
## 多分支允许同一动作由不同抽象动作序列触发，适合格斗、快捷指令或可替代输入路径。
## [br]
## @api public
## [br]
## @category resource_definition
## [br]
## @since 3.17.0
class_name GFInputSequenceBranch
extends Resource


# --- 导出变量 ---

## 本分支的步骤列表。
## [br]
## @api public
@export var steps: Array[GFInputSequenceStep] = []

## 本分支默认最大步骤间隔。小于 0 表示使用触发器默认值，0 表示不限制。
## [br]
## @api public
@export var max_gap_seconds: float = -1.0:
	set(value):
		max_gap_seconds = maxf(value, -1.0)


# --- 公共方法 ---

## 检查分支是否至少包含一个有效动作步骤。
## [br]
## @api public
## [br]
## @return 有效返回 true。
func is_valid_branch() -> bool:
	for step: GFInputSequenceStep in steps:
		if step != null and step.action_id != &"":
			return true
	return false


## 创建当前分支的深拷贝。
## [br]
## @api public
## [br]
## @return 分支副本。
func duplicate_branch() -> GFInputSequenceBranch:
	var branch: Resource = duplicate(true)
	if branch is GFInputSequenceBranch:
		var sequence_branch: GFInputSequenceBranch = branch
		return sequence_branch
	return null


## 从动作 ID 数组创建分支。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @param action_ids: 动作 ID 数组。
## [br]
## @param p_max_gap_seconds: 默认最大步骤间隔。
## [br]
## @schema action_ids: Array[StringName]，会复制到 GFInputSequenceStep 资源中。
## [br]
## @return 新分支。
static func from_action_ids(action_ids: Array[StringName], p_max_gap_seconds: float = -1.0) -> GFInputSequenceBranch:
	var branch: GFInputSequenceBranch = GFInputSequenceBranch.new()
	branch.max_gap_seconds = p_max_gap_seconds
	for action_id: StringName in action_ids:
		branch.steps.append(GFInputSequenceStep.from_action_id(action_id))
	return branch
