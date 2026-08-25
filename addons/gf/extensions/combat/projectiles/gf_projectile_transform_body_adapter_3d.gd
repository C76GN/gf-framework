## GFProjectileTransformBodyAdapter3D: 直接应用 Node3D 变换的 body adapter。
## [br]
## @api public
## [br]
## @category resource_definition
## [br]
## @since unreleased
class_name GFProjectileTransformBodyAdapter3D
extends GFProjectileBodyAdapter3D


func _validate_root(root: Node) -> Error:
	if (
		root == null
		or not is_instance_valid(root)
		or root.is_queued_for_deletion()
		or not root is Node3D
	):
		return ERR_INVALID_PARAMETER
	if root is PhysicsBody3D:
		return ERR_UNAVAILABLE
	return OK


func _capture_body(root: Node) -> GFProjectileBodyResult3D:
	if _validate_root(root) != OK:
		return GFProjectileBodyResult3D.failed(&"unsupported_body")
	var body: Node3D = root
	return GFProjectileBodyResult3D.successful(body.global_transform)


func _apply_intent(
	root: Node,
	intent: GFProjectileMotionIntent3D
) -> GFProjectileBodyResult3D:
	if _validate_root(root) != OK:
		return GFProjectileBodyResult3D.failed(&"unsupported_body")
	var body: Node3D = root
	var before_transform: Transform3D = body.global_transform
	if intent == null or not intent.is_valid():
		var reason: StringName = &"invalid_motion_intent"
		if intent != null and intent.get_failure_reason() != &"":
			reason = intent.get_failure_reason()
		return GFProjectileBodyResult3D.failed(reason, before_transform)
	if intent.get_kind() == GFProjectileMotionIntent3D.Kind.MOVE:
		var displacement: Vector3 = intent.get_velocity() * intent.get_delta_seconds()
		var target_position: Vector3 = before_transform.origin + displacement
		if not displacement.is_finite() or not target_position.is_finite():
			return GFProjectileBodyResult3D.failed(
				&"non_finite_motion_intent",
				before_transform
			)
		body.global_position = target_position
	var after_transform: Transform3D = body.global_transform
	return GFProjectileBodyResult3D.successful(
		after_transform,
		after_transform.origin - before_transform.origin
	)


func _stop(root: Node) -> GFProjectileBodyResult3D:
	if _validate_root(root) != OK:
		return GFProjectileBodyResult3D.failed(&"unsupported_body")
	var body: Node3D = root
	return GFProjectileBodyResult3D.successful(
		body.global_transform,
		Vector3.ZERO
	)
