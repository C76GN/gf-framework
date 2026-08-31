## GFProjectileBinding3D: 3D projectile 的 typed 拓扑快照。
## [br]
## @api public
## [br]
## @category value_object
## [br]
## @since 11.0.0
class_name GFProjectileBinding3D
extends GFProjectileBinding


# --- 公共方法 ---

## 返回创建本快照的 3D definition。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @return: 3D definition；准入前失败时可能为 null。
func get_definition() -> GFProjectileDefinition3D:
	var value: GFProjectileDefinition = super.get_definition()
	if value is GFProjectileDefinition3D:
		var definition: GFProjectileDefinition3D = value
		return definition
	return null


## 返回绑定的完整 3D 实例根节点。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @return: live Node3D root；已释放时返回 null。
func get_instance_root() -> Node3D:
	var value: Node = super.get_instance_root()
	if value is Node3D:
		var root: Node3D = value
		return root
	return null


## 返回唯一 3D runtime 节点。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @return: live GFProjectile3D；已释放时返回 null。
func get_runtime() -> GFProjectile3D:
	var value: Node = super.get_runtime()
	if value is GFProjectile3D:
		var runtime: GFProjectile3D = value
		return runtime
	return null


## 返回冻结的 3D body adapter。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @return: 绑定准入时的 GFProjectileBodyAdapter3D。
func get_body_adapter() -> GFProjectileBodyAdapter3D:
	var value: Resource = super.get_body_adapter()
	if value is GFProjectileBodyAdapter3D:
		var adapter: GFProjectileBodyAdapter3D = value
		return adapter
	return null
