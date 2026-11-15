## GFSkillActivationContext: 技能激活上下文。
##
## 保存一次技能激活过程中的 owner、目标、位置、失败原因和项目元数据。
## 它只承载通用上下文，不解释成本、阵营、属性或具体玩法规则。
## [br]
## @api public
## [br]
## @category value_object
## [br]
## @since 3.20.0
class_name GFSkillActivationContext
extends RefCounted


# --- 公共变量 ---

## 技能实例。
## [br]
## @api public
var skill: GFSkill = null

## 技能拥有者。
## [br]
## @api public
var owner: Object = null

## 手动传入的目标。
## [br]
## @api public
var manual_target: Object = null

## 原始施放中心。
## [br]
## @api public
## [br]
## @schema cast_center: Variant，可为 null 或 Vector2。
var cast_center: Variant = null

## 解析后的施放中心。
## [br]
## @api public
var resolved_center: Vector2 = Vector2.ZERO

## 最终目标列表。
## [br]
## @api public
## [br]
## @schema targets: Array[Object]，经过项目目标规则过滤后的目标。
var targets: Array[Object] = []

## 激活报告中的失败原因。空值表示尚未失败。
## [br]
## @api public
var failure_reason: StringName = &""

## 项目自定义元数据。框架不解释该字段。
## [br]
## @api public
## [br]
## @schema metadata: Dictionary，项目持有的成本、日志、调试或表现数据。
var metadata: Dictionary = {}


# --- 公共方法 ---

## 配置上下文并返回自身。
## [br]
## @api public
## [br]
## @param p_skill: 技能实例。
## [br]
## @param p_owner: 技能拥有者。
## [br]
## @param p_manual_target: 手动传入目标。
## [br]
## @param p_cast_center: 原始施放中心。
## [br]
## @param p_resolved_center: 解析后的施放中心。
## [br]
## @param p_metadata: 项目自定义元数据。
## [br]
## @return 当前上下文。
## [br]
## @schema p_cast_center: Variant，可为 null 或 Vector2。
## [br]
## @schema p_metadata: Dictionary，复制到上下文中供项目检查、提交或诊断使用。
## [br]
## @schema return: GFSkillActivationContext 当前上下文。
func configure(
	p_skill: GFSkill,
	p_owner: Object,
	p_manual_target: Object = null,
	p_cast_center: Variant = null,
	p_resolved_center: Vector2 = Vector2.ZERO,
	p_metadata: Dictionary = {}
) -> RefCounted:
	skill = p_skill
	owner = p_owner
	manual_target = p_manual_target
	cast_center = p_cast_center
	resolved_center = p_resolved_center
	metadata = p_metadata.duplicate(true)
	return self


## 标记激活失败。
## [br]
## @api public
## [br]
## @param reason: 失败原因。
## [br]
## @param extra_metadata: 追加到上下文的元数据。
## [br]
## @schema extra_metadata: Dictionary，复制到 metadata 中供项目诊断或串联使用。
func fail(reason: StringName, extra_metadata: Dictionary = {}) -> void:
	failure_reason = reason
	for key: Variant in extra_metadata.keys():
		metadata[key] = GFVariantData.duplicate_graph(extra_metadata[key])


## 检查上下文当前是否未失败。
## [br]
## @api public
## [br]
## @return 未失败时返回 true。
func is_ok() -> bool:
	return failure_reason == &""


## 创建报告字典。
## [br]
## @api public
## [br]
## @return 报告字典。
## [br]
## @schema return: Dictionary，包含 ok、reason、skill_id、target_count 和 metadata。
func to_report() -> Dictionary:
	return {
		"ok": is_ok(),
		"reason": failure_reason,
		"skill_id": skill.id if skill != null else &"",
		"target_count": targets.size(),
		"metadata": metadata.duplicate(true),
	}
