@tool

# GF Capability 扩展编辑器菜单动作。
extends RefCounted


# --- 框架内部方法 ---

## 获取 Capability 扩展贡献的脚本模板。
## [br]
## @api framework_internal
## [br]
## @return 模板记录列表。
## [br]
## @schema return: Array[Dictionary]，每个值包含 source_id、type、label、section、base_class、template。
func get_template_records() -> Array[Dictionary]:
	return [
		{
			"source_id": "gf.extension.capability:template.capability",
			"type": "Capability",
			"label": "生成 Capability",
			"section": "扩展模板",
			"base_class": "GFCapability",
			"template": _get_capability_template(),
		},
		{
			"source_id": "gf.extension.capability:template.node_capability",
			"type": "NodeCapability",
			"label": "生成 NodeCapability",
			"section": "扩展模板",
			"base_class": "GFNodeCapability",
			"template": _get_capability_template(),
		},
		{
			"source_id": "gf.extension.capability:template.node_2d_capability",
			"type": "Node2DCapability",
			"label": "生成 Node2DCapability",
			"section": "扩展模板",
			"base_class": "GFNode2DCapability",
			"template": _get_capability_template(),
		},
		{
			"source_id": "gf.extension.capability:template.node_3d_capability",
			"type": "Node3DCapability",
			"label": "生成 Node3DCapability",
			"section": "扩展模板",
			"base_class": "GFNode3DCapability",
			"template": _get_capability_template(),
		},
		{
			"source_id": "gf.extension.capability:template.control_capability",
			"type": "ControlCapability",
			"label": "生成 ControlCapability",
			"section": "扩展模板",
			"base_class": "GFControlCapability",
			"template": _get_capability_template(),
		},
	]


# --- 私有/辅助方法 ---

func _get_capability_template() -> String:
	return """## {ClassName}: TODO。
## [br]
## @api public
## [br]
## @category protocol
## [br]
## @since 3.17.0
class_name {ClassName}
extends {BaseClass}


# --- 信号 ---


# --- 枚举 ---


# --- 常量 ---


# --- 导出变量 ---


# --- 公共变量 ---


# --- 私有变量 ---


# --- 公共方法 ---

## 返回移除当前能力时对自动补齐依赖能力的处理策略。
## [br]
## @api public
## [br]
## @return GFCapabilityUtility.DependencyRemovalPolicy 枚举值。
func get_dependency_removal_policy() -> int:
	return super.get_dependency_removal_policy()


## 处理能力添加通知。
## [br]
## @api public
## [br]
## @param target: 交互目标对象。
func on_gf_capability_added(target: Object) -> void:
	super.on_gf_capability_added(target)


## 处理能力移除通知。
## [br]
## @api public
## [br]
## @param target: 交互目标对象。
func on_gf_capability_removed(target: Object) -> void:
	super.on_gf_capability_removed(target)


## 处理能力激活状态变化通知。
## [br]
## @api public
## [br]
## @param _target: 能力目标对象，默认回调不直接使用。
## [br]
## @param _active: 能力激活状态，默认回调不直接使用。
func on_gf_capability_active_changed(_target: Object, _active: bool) -> void:
	pass


# --- 私有/辅助方法 ---


# --- 信号处理函数 ---

"""
