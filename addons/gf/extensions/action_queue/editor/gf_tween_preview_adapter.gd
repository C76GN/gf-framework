@tool

## GFTweenPreviewAdapter: 受信任的编辑器数值样机绘制协议。
##
## 适配器只获得新建样机与冻结数值，不获得来源配置、真实目标或业务上下文。
## GDScript 不是沙箱；实现者负责不访问来源、全局业务、持久化、标记或导航。
## [br]
## @api public
## [br]
## @category protocol
## [br]
## @since unreleased
class_name GFTweenPreviewAdapter
extends RefCounted


# --- 可重写钩子 / 虚方法 ---

## 创建全新、未入树、无父节点的 Control 样机，至多 128 节点与 8 层。
## 成功接收后样机归 GF 所有，GF 负责挂载与释放；不能返回真实场景节点。
## [br]
## @api protected
## [br]
## @since unreleased
## [br]
## @return: 独立样机；null 表示拒绝。
func _create_sample() -> Control:
	return null


## 将冻结快照映射到工具自有样机；不得保留、改写来源或产生业务副作用。
## [br]
## @api protected
## [br]
## @since unreleased
## [br]
## @param _sample: 本适配器新建、GF 持有的有效样机。
## [br]
## @param _values: 可独立修改的采样副本；不含对象或来源引用。
## [br]
## @schema _values: Dictionary，String 声明属性名映射到有限 int/float。
func _apply_sample(_sample: Control, _values: Dictionary) -> void:
	pass
