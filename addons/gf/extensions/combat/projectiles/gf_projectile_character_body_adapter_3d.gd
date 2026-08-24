## GFProjectileCharacterBodyAdapter3D: CharacterBody3D 运动适配器。
## [br]
## @api public
## [br]
## @category resource_definition
## [br]
## @since unreleased
class_name GFProjectileCharacterBodyAdapter3D
extends GFProjectileBodyAdapter3D


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
	body.velocity = intent.get_velocity() if intent.get_kind() == GFProjectileMotionIntent3D.Kind.MOVE else Vector3.ZERO
	var _collided: bool = body.move_and_slide()
	var after_transform: Transform3D = body.global_transform
	return GFProjectileBodyResult3D.successful(
		after_transform,
		after_transform.origin - before_transform.origin
	)


func _stop(root: Node) -> GFProjectileBodyResult3D:
	if _validate_root(root) != OK:
		return GFProjectileBodyResult3D.failed(&"unsupported_body")
	var body: CharacterBody3D = root
	body.velocity = Vector3.ZERO
	return GFProjectileBodyResult3D.successful(body.global_transform)
