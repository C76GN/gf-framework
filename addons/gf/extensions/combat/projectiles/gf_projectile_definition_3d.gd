## GFProjectileDefinition3D: 3D projectile typed 定义。
## [br]
## @api public
## [br]
## @category resource_definition
## [br]
## @since 11.0.0
class_name GFProjectileDefinition3D
extends GFProjectileDefinition


## 驱动 3D root 的 body adapter。
## [br]
## @api public
## [br]
## @since 11.0.0
@export var body_adapter: GFProjectileBodyAdapter3D = null


## 校验并绑定一个已进入 SceneTree 的完整 3D 实例。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @param root: definition.scene 对应的完整实例 root。
## [br]
## @return: 有效 topology snapshot 或带确定失败原因的 binding。
func bind_instance(root: Node) -> GFProjectileBinding3D:
	var value: GFProjectileBinding = _bind_instance(
		root,
		GFProjectileSession.Dimension.THREE_D,
		body_adapter
	)
	if value is GFProjectileBinding3D:
		var binding: GFProjectileBinding3D = value
		return binding
	return GFProjectileBinding3D.new()
