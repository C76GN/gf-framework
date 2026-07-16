## GFProjectileSpawnPattern3D: 3D 发射体生成点模式基类。
##
## 模式只返回全局 Transform3D 列表，不实例化节点，也不解释伤害、弹药或阵营。
## [br]
## @api public
## [br]
## @category protocol
## [br]
## @since 3.17.0
class_name GFProjectileSpawnPattern3D
extends Resource


# --- 公共方法 ---

## 计算本次发射的全局生成变换。
## [br]
## @api public
## [br]
## @param emitter: 发射器节点。
## [br]
## @param projectile_context: 本次发射上下文。
## [br]
## @param emit_count: 调用方请求的数量；小于等于 0 时由模式自行决定。
## [br]
## @return 全局 Transform3D 列表。
## [br]
## @schema projectile_context: Dictionary，本次发射上下文；模式只读取调用方约定的数据。
func get_spawn_transforms(
	emitter: Node3D,
	projectile_context: Dictionary = {},
	emit_count: int = -1
) -> Array[Transform3D]:
	return _get_spawn_transforms(emitter, projectile_context, emit_count)


## 解析模式本次请求的最终数量，不生成变换。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param emit_count: 调用方请求数量；小于等于 0 时使用模式默认值。
## [br]
## @return 至少为 1 的请求数量。
func resolve_spawn_count(emit_count: int = -1) -> int:
	if emit_count > 0:
		return emit_count
	return maxi(_get_default_spawn_count(), 1)


# --- 可重写钩子 / 虚方法 ---

## 生成点计算扩展点。
## [br]
## @api protected
## [br]
## @param emitter: 发射器节点。
## [br]
## @param _projectile_context: 本次发射上下文。
## [br]
## @param _emit_count: 调用方请求的数量；小于等于 0 时由模式自行决定。
## [br]
## @return 全局 Transform3D 列表。
## [br]
## @schema _projectile_context: Dictionary，本次发射上下文；模式只读取调用方约定的数据。
func _get_spawn_transforms(
	emitter: Node3D,
	_projectile_context: Dictionary = {},
	_emit_count: int = -1
) -> Array[Transform3D]:
	if emitter == null:
		return []
	return [emitter.global_transform]


## 返回模式默认生成数量。
## [br]
## @api protected
## [br]
## @since 8.0.0
## [br]
## @return 默认生成数量。
func _get_default_spawn_count() -> int:
	return 1
