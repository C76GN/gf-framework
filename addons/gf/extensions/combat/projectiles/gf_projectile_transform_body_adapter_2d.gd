## GFProjectileTransformBodyAdapter2D: 直接应用 Node2D 变换的 body adapter。
## [br]
## @api public
## [br]
## @category resource_definition
## [br]
## @since 11.0.0
class_name GFProjectileTransformBodyAdapter2D
extends GFProjectileBodyAdapter2D


# --- 可重写钩子 / 虚方法 ---

## 接纳仍存活且未排队删除的普通 Node2D，并排除需要物理运动协议的 PhysicsBody2D。
## [br]
## @api protected
## [br]
## @since 11.0.0
## [br]
## @param root: 待直接修改全局位置的根节点；此处不检查是否已进入场景树。
## [br]
## @return: 可直接驱动时为 OK；无效节点为 ERR_INVALID_PARAMETER，PhysicsBody2D 为 ERR_UNAVAILABLE。
func _validate_root(root: Node) -> Error:
	if (
		root == null
		or not is_instance_valid(root)
		or root.is_queued_for_deletion()
		or not root is Node2D
	):
		return ERR_INVALID_PARAMETER
	if root is PhysicsBody2D:
		return ERR_UNAVAILABLE
	return OK


## 重新校验普通 Node2D 后捕获全局变换，不修改节点位置。
## [br]
## @api protected
## [br]
## @since 11.0.0
## [br]
## @param root: 要捕获快照的非物理发射体根节点。
## [br]
## @return: 变换有限时为全局变换与零位移的成功结果；root 不支持时失败原因为 unsupported_body，变换非有限时为 non_finite_body_result。
func _capture_body(root: Node) -> GFProjectileBodyResult2D:
	if _validate_root(root) != OK:
		return GFProjectileBodyResult2D.failed(&"unsupported_body")
	var body: Node2D = root
	return GFProjectileBodyResult2D.successful(body.global_transform)


## 按 MOVE 的速度乘以时长直接写入 Node2D.global_position，不执行碰撞移动。
## 写入前检查位移与目标位置是否有限；其他有效 intent 种类保持位置不变。
## 结果工厂若因最终变换或实际位置差非有限而失败，不撤销已经写入的位置。
## [br]
## @api protected
## [br]
## @since 11.0.0
## [br]
## @param root: 可由本适配器直接移动的非物理根节点。
## [br]
## @param intent: 本帧 intent；空值或 REJECTED 会在写入前失败，并尽量保留 intent 的失败原因。
## [br]
## @return: 成功时为操作后的变换与实际位置差；root、intent 或目标位移非法时失败，最终变换或实际位置差非有限时返回 non_finite_body_result。
func _apply_intent(
	root: Node,
	intent: GFProjectileMotionIntent2D
) -> GFProjectileBodyResult2D:
	if _validate_root(root) != OK:
		return GFProjectileBodyResult2D.failed(&"unsupported_body")
	var body: Node2D = root
	var before_transform: Transform2D = body.global_transform
	if intent == null or not intent.is_valid():
		var reason: StringName = &"invalid_motion_intent"
		if intent != null and intent.get_failure_reason() != &"":
			reason = intent.get_failure_reason()
		return GFProjectileBodyResult2D.failed(reason, before_transform)
	if intent.get_kind() == GFProjectileMotionIntent2D.Kind.MOVE:
		var displacement: Vector2 = intent.get_velocity() * intent.get_delta_seconds()
		var target_position: Vector2 = before_transform.origin + displacement
		if not displacement.is_finite() or not target_position.is_finite():
			return GFProjectileBodyResult2D.failed(
				&"non_finite_motion_intent",
				before_transform
			)
		body.global_position = target_position
	var after_transform: Transform2D = body.global_transform
	return GFProjectileBodyResult2D.successful(
		after_transform,
		after_transform.origin - before_transform.origin
	)


## 读取普通 Node2D 的当前变换并构造静止快照；本适配器不持有持续速度，因此无需写入节点。
## [br]
## @api protected
## [br]
## @since 11.0.0
## [br]
## @param root: 要结束直接位移驱动的非物理根节点。
## [br]
## @return: 变换有限时为当前全局变换与零位移的成功结果；root 不支持时失败原因为 unsupported_body，变换非有限时为 non_finite_body_result。
func _stop(root: Node) -> GFProjectileBodyResult2D:
	if _validate_root(root) != OK:
		return GFProjectileBodyResult2D.failed(&"unsupported_body")
	var body: Node2D = root
	return GFProjectileBodyResult2D.successful(
		body.global_transform,
		Vector2.ZERO
	)
