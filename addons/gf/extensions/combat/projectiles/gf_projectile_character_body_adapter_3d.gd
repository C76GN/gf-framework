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

func _validate_root(root: Node) -> Error:
	if (
		root == null
		or not is_instance_valid(root)
		or root.is_queued_for_deletion()
		or not root is CharacterBody3D
	):
		return ERR_INVALID_PARAMETER
	return OK


func _capture_body(root: Node) -> GFProjectileBodyResult3D:
	if _validate_root(root) != OK:
		return GFProjectileBodyResult3D.failed(&"unsupported_body")
	var body: CharacterBody3D = root
	return GFProjectileBodyResult3D.successful(body.global_transform)


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


func _stop(root: Node) -> GFProjectileBodyResult3D:
	if _validate_root(root) != OK:
		return GFProjectileBodyResult3D.failed(&"unsupported_body")
	var body: CharacterBody3D = root
	body.velocity = Vector3.ZERO
	return GFProjectileBodyResult3D.successful(body.global_transform)
