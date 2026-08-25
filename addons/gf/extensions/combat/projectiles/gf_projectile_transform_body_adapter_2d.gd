## GFProjectileTransformBodyAdapter2D: 直接应用 Node2D 变换的 body adapter。
## [br]
## @api public
## [br]
## @category resource_definition
## [br]
## @since unreleased
class_name GFProjectileTransformBodyAdapter2D
extends GFProjectileBodyAdapter2D


# --- 可重写钩子 / 虚方法 ---

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


func _capture_body(root: Node) -> GFProjectileBodyResult2D:
	if _validate_root(root) != OK:
		return GFProjectileBodyResult2D.failed(&"unsupported_body")
	var body: Node2D = root
	return GFProjectileBodyResult2D.successful(body.global_transform)


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


func _stop(root: Node) -> GFProjectileBodyResult2D:
	if _validate_root(root) != OK:
		return GFProjectileBodyResult2D.failed(&"unsupported_body")
	var body: Node2D = root
	return GFProjectileBodyResult2D.successful(
		body.global_transform,
		Vector2.ZERO
	)
