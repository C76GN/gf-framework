## GFProjectileBinding2D: 2D projectile 的 typed 拓扑快照。
## [br]
## @api public
## [br]
## @category value_object
## [br]
## @since unreleased
class_name GFProjectileBinding2D
extends GFProjectileBinding


# --- 公共方法 ---

## 返回创建本快照的 2D definition。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return: 2D definition；准入前失败时可能为 null。
func get_definition() -> GFProjectileDefinition2D:
	var value: GFProjectileDefinition = super.get_definition()
	if value is GFProjectileDefinition2D:
		var definition: GFProjectileDefinition2D = value
		return definition
	return null


## 返回绑定的完整 2D 实例根节点。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return: live Node2D root；已释放时返回 null。
func get_instance_root() -> Node2D:
	var value: Node = super.get_instance_root()
	if value is Node2D:
		var root: Node2D = value
		return root
	return null


## 返回唯一 2D runtime 节点。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return: live GFProjectile2D；已释放时返回 null。
func get_runtime() -> GFProjectile2D:
	var value: Node = super.get_runtime()
	if value is GFProjectile2D:
		var runtime: GFProjectile2D = value
		return runtime
	return null


## 返回冻结的 2D body adapter。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return: 绑定准入时的 GFProjectileBodyAdapter2D。
func get_body_adapter() -> GFProjectileBodyAdapter2D:
	var value: Resource = super.get_body_adapter()
	if value is GFProjectileBodyAdapter2D:
		var adapter: GFProjectileBodyAdapter2D = value
		return adapter
	return null
