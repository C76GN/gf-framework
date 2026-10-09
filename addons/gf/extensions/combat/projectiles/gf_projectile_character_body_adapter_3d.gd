## GFProjectileCharacterBodyAdapter3D: CharacterBody3D 运动适配器。
## [br]
## @api public
## [br]
## @category resource_definition
## [br]
## @since 11.0.0
class_name GFProjectileCharacterBodyAdapter3D
extends GFProjectileBodyAdapter3D


# --- 可重写钩子 / 虚方法 ---

## 只接纳仍存活且未排队删除的 CharacterBody3D，供后续物理移动与速度写回使用。
## [br]
## @api protected
## [br]
## @since 11.0.0
## [br]
## @param root: 待驱动的完整发射体根节点；此处不检查是否已进入场景树。
## [br]
## @return: 类型与生命周期符合要求时为 OK，否则为 ERR_INVALID_PARAMETER。
func _validate_root(root: Node) -> Error:
	if (
		root == null
		or not is_instance_valid(root)
		or root.is_queued_for_deletion()
		or not root is CharacterBody3D
	):
		return ERR_INVALID_PARAMETER
	return OK


## 重新校验 CharacterBody3D 后捕获其当前全局变换，不读取或修改速度。
## [br]
## @api protected
## [br]
## @since 11.0.0
## [br]
## @param root: 要捕获运动快照的发射体根节点。
## [br]
## @return: 变换有限时为全局变换与零位移的成功结果；root 不支持时失败原因为 unsupported_body，变换非有限时为 non_finite_body_result。
func _capture_body(root: Node) -> GFProjectileBodyResult3D:
	if _validate_root(root) != OK:
		return GFProjectileBodyResult3D.failed(&"unsupported_body")
	var body: CharacterBody3D = root
	return GFProjectileBodyResult3D.successful(body.global_transform)


## 将 MOVE 速度写入 CharacterBody3D 后调用 move_and_slide，返回实际产生的全局位移。
## intent 时长用于候选位移的有限性预检，实际移动由 move_and_slide 执行；其他有效种类使用零速度。
## 若移动后位置或位移非有限，只还原本节点先前的变换与速度，不承诺撤销物理查询或其他外部影响。
## [br]
## @api protected
## [br]
## @since 11.0.0
## [br]
## @param root: 仍可用的 CharacterBody3D 根节点；本次调用会修改其速度并尝试移动。
## [br]
## @param intent: 本帧 intent；空值或 REJECTED 会在移动前失败，并尽量保留 intent 的失败原因。
## [br]
## @return: 移动后的 body 快照及实际位移；root、intent 或运动数值不合法时返回失败结果。
func _apply_intent(
	root: Node,
	intent: GFProjectileMotionIntent3D
) -> GFProjectileBodyResult3D:
	if _validate_root(root) != OK:
		return GFProjectileBodyResult3D.failed(&"unsupported_body")
	var body: CharacterBody3D = root
	var before_transform: Transform3D = body.global_transform
	if intent == null or not intent.is_valid():
		var reason: StringName = &"invalid_motion_intent"
		if intent != null and intent.get_failure_reason() != &"":
			reason = intent.get_failure_reason()
		return GFProjectileBodyResult3D.failed(reason, before_transform)
	var before_velocity: Vector3 = body.velocity
	var requested_velocity: Vector3 = (
		intent.get_velocity()
		if intent.get_kind() == GFProjectileMotionIntent3D.Kind.MOVE
		else Vector3.ZERO
	)
	var intended_displacement: Vector3 = requested_velocity * intent.get_delta_seconds()
	if (
		not intended_displacement.is_finite()
		or not (before_transform.origin + intended_displacement).is_finite()
	):
		return GFProjectileBodyResult3D.failed(
			&"non_finite_motion_intent",
			before_transform
		)
	body.velocity = requested_velocity
	var _collided: bool = body.move_and_slide()
	var after_transform: Transform3D = body.global_transform
	var actual_displacement: Vector3 = after_transform.origin - before_transform.origin
	if not after_transform.origin.is_finite() or not actual_displacement.is_finite():
		body.global_transform = before_transform
		body.velocity = before_velocity
		return GFProjectileBodyResult3D.failed(
			&"non_finite_motion_intent",
			before_transform
		)
	return GFProjectileBodyResult3D.successful(
		after_transform,
		actual_displacement
	)


## 校验 root 后先将 CharacterBody3D 的速度清零，再构造当前变换的结果，不调用 move_and_slide 或额外修改位置。
## 结果工厂因变换非有限返回失败时，不撤销已经完成的速度清零。
## [br]
## @api protected
## [br]
## @since 11.0.0
## [br]
## @param root: 要停止运动的发射体根节点。
## [br]
## @return: 变换有限时为当前全局变换与零位移的成功结果；root 不支持时失败原因为 unsupported_body，变换非有限时为 non_finite_body_result。
func _stop(root: Node) -> GFProjectileBodyResult3D:
	if _validate_root(root) != OK:
		return GFProjectileBodyResult3D.failed(&"unsupported_body")
	var body: CharacterBody3D = root
	body.velocity = Vector3.ZERO
	return GFProjectileBodyResult3D.successful(body.global_transform)
