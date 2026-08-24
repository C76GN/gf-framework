## GFProjectileCharacterBodyAdapter2D: CharacterBody2D 运动适配器。
## [br]
## @api public
## [br]
## @category resource_definition
## [br]
## @since unreleased
class_name GFProjectileCharacterBodyAdapter2D
extends GFProjectileBodyAdapter2D


func _validate_root(root: Node) -> Error:
	if (
		root == null
		or not is_instance_valid(root)
		or root.is_queued_for_deletion()
		or not root is CharacterBody2D
	):
		return ERR_INVALID_PARAMETER
	return OK


func _capture_body(root: Node) -> GFProjectileBodyResult2D:
	if _validate_root(root) != OK:
		return GFProjectileBodyResult2D.failed(&"unsupported_body")
	var body: CharacterBody2D = root
	return GFProjectileBodyResult2D.successful(body.global_transform)


func _apply_intent(
	root: Node,
	intent: GFProjectileMotionIntent2D
) -> GFProjectileBodyResult2D:
	if _validate_root(root) != OK:
		return GFProjectileBodyResult2D.failed(&"unsupported_body")
	var body: CharacterBody2D = root
	var before_transform: Transform2D = body.global_transform
	if intent == null or not intent.is_valid():
		var reason: StringName = &"invalid_motion_intent"
		if intent != null and intent.get_failure_reason() != &"":
			reason = intent.get_failure_reason()
		return GFProjectileBodyResult2D.failed(reason, before_transform)
	body.velocity = intent.get_velocity() if intent.get_kind() == GFProjectileMotionIntent2D.Kind.MOVE else Vector2.ZERO
	var _collided: bool = body.move_and_slide()
	var after_transform: Transform2D = body.global_transform
	return GFProjectileBodyResult2D.successful(
		after_transform,
		after_transform.origin - before_transform.origin
	)


func _stop(root: Node) -> GFProjectileBodyResult2D:
	if _validate_root(root) != OK:
		return GFProjectileBodyResult2D.failed(&"unsupported_body")
	var body: CharacterBody2D = root
	body.velocity = Vector2.ZERO
	return GFProjectileBodyResult2D.successful(body.global_transform)
