@tool

## GFUITweenMotion: 在页面或组件轨道中重用已有 GFTweenActionConfig，通过受控时间轴按局部进度采样。
## [br]
## @api public
## [br]
## @category resource_definition
## [br]
## @since unreleased
class_name GFUITweenMotion
extends GFUIMotionEffect


# --- 导出变量 ---

## 配置化 Tween 的来源，按每次绑定复制并启用受控定位。
## [br]
## @api public
## [br]
## @since unreleased
@export var configuration: GFTweenActionConfig


# --- 公共方法 ---

## 受控 Tween 从基线重建整个根属性，包括只配置单个分量的步骤。
## [br]
## @api public
## [br]
## @return: 去重后的属性路径。
## [br]
## @since unreleased
func written_properties() -> Array[NodePath]:
	var paths: Array[NodePath] = []
	if configuration != null:
		for step: GFTweenActionStep in configuration.steps:
			if step != null:
				var root: NodePath = NodePath(str(step.property_name).get_slice(":", 0))
				if not paths.has(root):
					paths.append(root)
	return paths


## 按受控播放合同检查真实目标。
## [br]
## @api public
## [br]
## @param target: 项目目标。
## [br]
## @param _inputs: 额外输入。
## [br]
## @schema _inputs: Dictionary，此效果只使用绑定目标。
## [br]
## @return: 校验说明或空串。
## [br]
## @since unreleased
func binding_error(target: Object, _inputs: Dictionary) -> String:
	if (
		configuration == null
		or not target is Node
		or not (target as Node).is_inside_tree()
		or configuration.is_empty()
	):
		return "已有 Tween 需要配置和树内节点"
	var frozen: GFTweenActionConfig = configuration.duplicate_config()
	if frozen == null:
		return "无法复制 Tween 配置"
	frozen.enable_playback_control = true
	if not frozen.get_validation_report(target).is_ok():
		return "Tween 步骤不满足目标或受控播放要求"
	return ""


## 使用 GF 受控动作的求值、取消及恢复语义。
## [br]
## @api public
## [br]
## @param target: 已验证的树内节点。
## [br]
## @param _inputs: 额外输入。
## [br]
## @schema _inputs: Dictionary，此效果不消费额外槽位。
## [br]
## @return: 对同一受控动作执行的定位操作。
## [br]
## @since unreleased
func bind_target(target: Object, _inputs: Dictionary) -> GFUIMotionBinding:
	var frozen: GFTweenActionConfig = configuration.duplicate_config()
	frozen.enable_playback_control = true
	frozen.restore_initial_values_on_cancel = true
	var created: GFVisualAction = frozen.create_action(target)
	if not created is GFConfiguredTweenAction:
		return null
	var action: GFConfiguredTweenAction = created
	var sample: Callable = func(weight: float) -> void:
		if not action.can_control_playback():
			var _completion: Variant = action.execute()
		var _positioned: bool = action.seek(
			clampf(
				weight,
				0.0,
				1.0
			) * action.get_duration_seconds()
		)
	var release: Callable = func(reason: int) -> void:
		if reason == GFUIMotionBinding.EndReason.CANCELLED:
			action.cancel()
		elif reason == GFUIMotionBinding.EndReason.REPLACED:
			action.stop_at_current_pose()
		else:
			action.finish()
	return GFUIMotionBinding.new(sample, release)
