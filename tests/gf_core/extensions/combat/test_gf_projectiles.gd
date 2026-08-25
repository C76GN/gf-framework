## 测试 Combat 扩展的 typed projectile topology、runtime 与发射事务。
extends GutTest


# --- 常量 ---



# --- 辅助子类 ---

class HitReceiver2D:
	extends Node2D

	var received_context: GFCombatHitContext = null

	func receive_hit(context: GFCombatHitContext) -> Dictionary:
		received_context = context
		return { "ok": true }


class RejectingHitReceiver2D:
	extends Node2D

	func receive_hit(_context: GFCombatHitContext) -> Dictionary:
		return {
			"ok": false,
			"reason": "blocked",
		}


class DuckImpactSource2D:
	extends Node2D

	signal hit_accepted(
		context: GFCombatHitContext,
		receiver: Object,
		report: Dictionary
	)

	func emit_hit_for_test(
		context: GFCombatHitContext,
		receiver: Object,
		report: Dictionary
	) -> void:
		hit_accepted.emit(context, receiver, report)


class InvalidStateMotion extends GFProjectileMotion:
	func _create_state_2d(
		_launch_input: GFProjectileLaunchInput2D,
		_initial_body: GFProjectileBodyResult2D
	) -> Variant:
		return null

	func _create_state_3d(
		_launch_input: GFProjectileLaunchInput3D,
		_initial_body: GFProjectileBodyResult3D
	) -> Variant:
		return null


class TrackingMotionStateLifecycle extends GFProjectileMotion:
	var state_refs: Array[WeakRef] = []
	var computed_state_ids: Array[int] = []
	var invalidate_definition_2d: GFProjectileDefinition2D = null
	var invalidate_definition_3d: GFProjectileDefinition3D = null

	func _create_state_2d(
		_launch_input: GFProjectileLaunchInput2D,
		_initial_body: GFProjectileBodyResult2D
	) -> Variant:
		var state: GFProjectileMotionState = GFProjectileMotionState.new()
		state_refs.append(weakref(state))
		if invalidate_definition_2d != null:
			invalidate_definition_2d.runtime_path = NodePath("MutatedRuntime")
		return state

	func _create_state_3d(
		_launch_input: GFProjectileLaunchInput3D,
		_initial_body: GFProjectileBodyResult3D
	) -> Variant:
		var state: GFProjectileMotionState = GFProjectileMotionState.new()
		state_refs.append(weakref(state))
		if invalidate_definition_3d != null:
			invalidate_definition_3d.runtime_path = NodePath("MutatedRuntime")
		return state

	func _compute_intent_2d(
		state: GFProjectileMotionState,
		_current_body: GFProjectileBodyResult2D,
		delta: float
	) -> Variant:
		computed_state_ids.append(state.get_instance_id())
		return GFProjectileMotionIntent2D.move(Vector2.ZERO, maxf(delta, 0.0))

	func _compute_intent_3d(
		state: GFProjectileMotionState,
		_current_body: GFProjectileBodyResult3D,
		delta: float
	) -> Variant:
		computed_state_ids.append(state.get_instance_id())
		return GFProjectileMotionIntent3D.move(Vector3.ZERO, maxf(delta, 0.0))


class FinishingMotion extends GFProjectileMotion:
	func _compute_intent_2d(
		_state: GFProjectileMotionState,
		_current_body: GFProjectileBodyResult2D,
		_delta: float
	) -> Variant:
		return GFProjectileMotionIntent2D.finish()

	func _compute_intent_3d(
		_state: GFProjectileMotionState,
		_current_body: GFProjectileBodyResult3D,
		_delta: float
	) -> Variant:
		return GFProjectileMotionIntent3D.finish()


class FinishingApplyAdapter2D extends GFProjectileTransformBodyAdapter2D:
	var active_session: GFProjectileSession = null
	var displacement: Vector2 = Vector2(3.0, 4.0)
	var apply_count: int = 0

	func _apply_intent(
		root: Node,
		_intent: GFProjectileMotionIntent2D
	) -> GFProjectileBodyResult2D:
		apply_count += 1
		if not root is Node2D:
			return GFProjectileBodyResult2D.failed(&"unsupported_body")
		var body: Node2D = root
		var before_position: Vector2 = body.global_position
		body.global_position += displacement
		if active_session != null and active_session.is_active():
			var _finished: bool = active_session.finish(
				GFProjectileSession.EndReason.CALLER_FINISHED
			)
		return GFProjectileBodyResult2D.successful(
			body.global_transform,
			body.global_position - before_position
		)


class FinishingApplyAdapter3D extends GFProjectileTransformBodyAdapter3D:
	var active_session: GFProjectileSession = null
	var displacement: Vector3 = Vector3(2.0, 3.0, 6.0)
	var apply_count: int = 0

	func _apply_intent(
		root: Node,
		_intent: GFProjectileMotionIntent3D
	) -> GFProjectileBodyResult3D:
		apply_count += 1
		if not root is Node3D:
			return GFProjectileBodyResult3D.failed(&"unsupported_body")
		var body: Node3D = root
		var before_position: Vector3 = body.global_position
		body.global_position += displacement
		if active_session != null and active_session.is_active():
			var _finished: bool = active_session.finish(
				GFProjectileSession.EndReason.CALLER_FINISHED
			)
		return GFProjectileBodyResult3D.successful(
			body.global_transform,
			body.global_position - before_position
		)


class RecordingSpawnPattern2D extends GFProjectileSpawnPattern2D:
	var received_count: int = 0
	var default_count: int = 1

	func _get_default_spawn_count() -> int:
		return default_count

	func _get_spawn_transforms(
		emitter: Node2D,
		_launch_input: GFProjectileLaunchInput2D = null,
		emit_count: int = -1
	) -> Array[Transform2D]:
		received_count = emit_count
		var result: Array[Transform2D] = []
		for index: int in range(maxi(emit_count, 0)):
			var spawn_transform: Transform2D = emitter.global_transform
			spawn_transform.origin += Vector2(float(index) * 10.0, 0.0)
			result.append(spawn_transform)
		return result


class RecordingSpawnPattern3D extends GFProjectileSpawnPattern3D:
	var received_count: int = 0

	func _get_spawn_transforms(
		emitter: Node3D,
		_launch_input: GFProjectileLaunchInput3D = null,
		emit_count: int = -1
	) -> Array[Transform3D]:
		received_count = emit_count
		var result: Array[Transform3D] = []
		for index: int in range(maxi(emit_count, 0)):
			var spawn_transform: Transform3D = emitter.global_transform
			spawn_transform.origin += Vector3(0.0, 0.0, float(index) * -10.0)
			result.append(spawn_transform)
		return result


class RecordingEmissionPolicy extends GFProjectileEmissionPolicy:
	var commit_hook_count: int = 0
	var event_log: Array[StringName] = []

	func _commit_emission(
		_emitter: Node,
		_prepare_report: Dictionary,
		_emitted_count: int
	) -> void:
		commit_hook_count += 1
		event_log.append(&"commit_hook")


class HostileFailureEmissionPolicy extends GFProjectileEmissionPolicy:
	var hostile_object: Object = null

	func _prepare_emission(
		_emitter: Node,
		_projectile_id: StringName,
		_prepare_report: Dictionary
	) -> Dictionary:
		var report: Dictionary = {}
		report["ok"] = false
		report["reason"] = "r".repeat(300)
		report["policy_id"] = StringName("p".repeat(200))
		report["projectile_id"] = NodePath("n".repeat(300))
		report["remaining_cooldown_seconds"] = hostile_object
		report["available_charges"] = NAN
		report["required_charges"] = INF
		report["unknown_detail"] = "must_not_escape"
		report[NodePath("published")] = true
		report[&"committed"] = true
		report["compensated"] = false
		report[NodePath("rolled_back")] = false
		report[&"emitted_count"] = 3
		report["consumed_charges"] = 1.5
		report[&"emission_count"] = 7
		report["hard_limit"] = 99
		report[&"state"] = StringName("s".repeat(200))
		return report


class RecordingPreflightAdapter2D extends GFProjectileTransformBodyAdapter2D:
	var capture_count: int = 0

	func _capture_body(root: Node) -> GFProjectileBodyResult2D:
		capture_count += 1
		return super._capture_body(root)


class RecordingPreflightMotion extends GFLinearProjectileMotion:
	var create_state_count: int = 0

	func _create_state_2d(
		launch_input: GFProjectileLaunchInput2D,
		initial_body: GFProjectileBodyResult2D
	) -> GFProjectileMotionState:
		create_state_count += 1
		return super._create_state_2d(launch_input, initial_body)


class FinishingCaptureAdapter2D extends GFProjectileTransformBodyAdapter2D:
	var active_session: GFProjectileSession = null
	var capture_count: int = 0

	func _capture_body(root: Node) -> GFProjectileBodyResult2D:
		capture_count += 1
		if active_session != null and active_session.is_active():
			var _finished: bool = active_session.finish(
				GFProjectileSession.EndReason.CALLER_FINISHED
			)
		return super._capture_body(root)


class FreeingValidateAdapter2D extends GFProjectileTransformBodyAdapter2D:
	var validate_count: int = 0

	func _validate_root(root: Node) -> Error:
		validate_count += 1
		root.free()
		return OK


class MutatingValidateAdapter2D extends GFProjectileTransformBodyAdapter2D:
	var definition: GFProjectileDefinition2D = null
	var validate_count: int = 0

	func _validate_root(_root: Node) -> Error:
		validate_count += 1
		if definition != null:
			definition.runtime_path = NodePath("MutatedRuntime")
		return OK


class FinishingCommitPolicy extends GFProjectileEmissionPolicy:
	var event_log: Array[StringName] = []

	func _commit_emission(
		emitter: Node,
		_prepare_report: Dictionary,
		_emitted_count: int
	) -> void:
		event_log.append(&"commit_hook")
		var parent: Node = emitter.get_parent() if emitter != null else null
		if parent == null:
			return
		for candidate: Node in parent.get_children():
			var runtime_value: Node = candidate.get_node_or_null(
				NodePath("ProjectileRuntime")
			)
			if not runtime_value is GFProjectile2D:
				continue
			var runtime: GFProjectile2D = runtime_value
			var session: GFProjectileSession = runtime.get_active_session()
			if session == null:
				continue
			var on_finished: Callable = func(
				_finished_session: GFProjectileSession,
				_reason: int
			) -> void:
				event_log.append(&"finished")
			var _connected: int = session.finished.connect(on_finished)
			var _finished: bool = session.finish(
				GFProjectileSession.EndReason.CALLER_FINISHED
			)
			event_log.append(&"hook_finished")


class InvalidatingCommitPolicy extends GFProjectileEmissionPolicy:
	var source_path: NodePath = NodePath("Impact")

	func _commit_emission(
		emitter: Node,
		_prepare_report: Dictionary,
		_emitted_count: int
	) -> void:
		var parent: Node = emitter.get_parent() if emitter != null else null
		if parent == null:
			return
		for candidate: Node in parent.get_children():
			var source: Node = candidate.get_node_or_null(source_path)
			if source == null:
				continue
			candidate.remove_child(source)
			source.free()


class ReleasingCommitPolicy extends GFProjectileEmissionPolicy:
	enum ReleaseMode {
		REMOVE_FROM_PARENT = 0,
		QUEUE_FREE = 1,
		FREE = 2,
		DEFERRED_FREE = 3,
	}

	var release_mode: ReleaseMode = ReleaseMode.REMOVE_FROM_PARENT
	var event_log: Array[StringName] = []
	var observed_sessions: Array[GFProjectileSession] = []

	func _commit_emission(
		emitter: Node,
		_prepare_report: Dictionary,
		_emitted_count: int
	) -> void:
		event_log.append(&"commit_hook")
		var parent: Node = emitter.get_parent() if emitter != null else null
		if parent == null:
			return
		for candidate: Node in parent.get_children():
			var runtime_value: Node = candidate.get_node_or_null(
				NodePath("ProjectileRuntime")
			)
			var session: GFProjectileSession = null
			if runtime_value is GFProjectile2D:
				var runtime_2d: GFProjectile2D = runtime_value
				session = runtime_2d.get_active_session()
			elif runtime_value is GFProjectile3D:
				var runtime_3d: GFProjectile3D = runtime_value
				session = runtime_3d.get_active_session()
			if session == null:
				continue
			observed_sessions.append(session)
			var on_finished: Callable = func(
				_finished_session: GFProjectileSession,
				_reason: int
			) -> void:
				event_log.append(&"finished")
			var _connected: int = session.finished.connect(on_finished)
		match release_mode:
			ReleaseMode.QUEUE_FREE:
				emitter.queue_free()
			ReleaseMode.FREE:
				emitter.free()
			ReleaseMode.DEFERRED_FREE:
				emitter.call_deferred(&"free")
			_:
				parent.remove_child(emitter)
		event_log.append(&"release_requested")


class ReleasingPreparePolicy extends GFProjectileEmissionPolicy:
	var prepare_hook_count: int = 0
	var reentrant_roots: Array[Node] = []

	func _prepare_emission(
		emitter: Node,
		_projectile_id: StringName,
		_prepare_report: Dictionary
	) -> Dictionary:
		prepare_hook_count += 1
		if emitter is GFProjectileEmitter2D:
			var emitter_2d: GFProjectileEmitter2D = emitter
			reentrant_roots = emitter_2d.emit_projectiles(
				GFProjectileLaunchInput2D.new(),
				&"",
				1
			)
		var parent: Node = emitter.get_parent() if emitter != null else null
		if parent != null:
			parent.remove_child(emitter)
		return {}


class ReleasingDeferredCommitPolicy extends GFProjectileEmissionPolicy:
	enum ReleaseMode {
		REMOVE_FROM_PARENT = 0,
		QUEUE_FREE = 1,
	}

	var deferred_commit_count: int = 0
	var release_mode: ReleaseMode = ReleaseMode.REMOVE_FROM_PARENT

	func commit_deferred_for_framework(
		emitter: Node,
		prepare_report: Dictionary,
		emitted_count: int
	) -> Dictionary:
		deferred_commit_count += 1
		var report: Dictionary = super.commit_deferred_for_framework(
			emitter,
			prepare_report,
			emitted_count
		)
		var parent: Node = emitter.get_parent() if emitter != null else null
		match release_mode:
			ReleaseMode.QUEUE_FREE:
				emitter.queue_free()
			_:
				if parent != null:
					parent.remove_child(emitter)
		return report


class ReentrantReceiptPolicy extends GFProjectileEmissionPolicy:
	var receipt: GFProjectileEmissionReceipt = null
	var commit_hook_count: int = 0
	var nested_publish_report: Dictionary = {}
	var nested_commit_report: Dictionary = {}

	func _commit_emission(
		emitter: Node,
		_prepare_report: Dictionary,
		_emitted_count: int
	) -> void:
		commit_hook_count += 1
		if receipt != null:
			nested_publish_report = receipt.publish_for_framework()
		var nested_prepare: Dictionary = prepare_emission(
			emitter,
			&"nested",
			{},
			1,
			0
		)
		nested_commit_report = commit_emission(emitter, nested_prepare, 1)


class RejectingConsumeProjectile2D extends GFProjectile2D:
	var reject_consume: bool = false

	func consume_launch_reservation_for_framework(
		reservation: GFProjectileLaunchReservation,
		binding: GFProjectileBinding2D,
		launch_input: GFProjectileLaunchInput2D
	) -> GFProjectileSession:
		if reject_consume:
			return null
		return super.consume_launch_reservation_for_framework(
			reservation,
			binding,
			launch_input
		)


class FinishingConsumeProjectile2D extends GFProjectile2D:
	func consume_launch_reservation_for_framework(
		reservation: GFProjectileLaunchReservation,
		binding: GFProjectileBinding2D,
		launch_input: GFProjectileLaunchInput2D
	) -> GFProjectileSession:
		var session: GFProjectileSession = super.consume_launch_reservation_for_framework(
			reservation,
			binding,
			launch_input
		)
		if session != null:
			var _finished: bool = session.finish(
				GFProjectileSession.EndReason.INTERNAL_FAILURE
			)
		return session


class RelaunchingStopAdapter2D extends GFProjectileTransformBodyAdapter2D:
	var definition: GFProjectileDefinition2D = null
	var stop_binding_reason: GFProjectileBinding.FailureReason = (
		GFProjectileBinding.FailureReason.NONE
	)
	var relaunch_result: GFProjectileSession = null
	var active_getter_during_stop: GFProjectileSession = null

	func _stop(root: Node) -> GFProjectileBodyResult2D:
		var runtime_value: Node = root.get_node_or_null(
			NodePath("ProjectileRuntime")
		)
		var runtime: GFProjectile2D = null
		if runtime_value is GFProjectile2D:
			runtime = runtime_value
		if runtime != null:
			active_getter_during_stop = runtime.get_active_session()
		var binding: GFProjectileBinding2D = definition.bind_instance(root)
		stop_binding_reason = binding.get_failure_reason()
		if binding.is_valid() and runtime != null:
			relaunch_result = runtime.launch(binding)
		return super._stop(root)


class RecordingObjectPool extends GFObjectPoolUtility:
	var acquire_count: int = 0
	var release_count: int = 0
	var invalidate_acquire_index: int = -1
	var reuse_released_nodes: bool = false
	var acquired_nodes: Array[Node] = []
	var released_nodes: Array[Node] = []
	var _available_nodes: Array[Node] = []

	func acquire(
		scene: PackedScene,
		parent: Node,
		before_add: Callable = Callable()
	) -> Node:
		acquire_count += 1
		var candidate: Node = null
		if reuse_released_nodes and not _available_nodes.is_empty():
			candidate = _available_nodes.pop_front()
		else:
			var candidate_value: Variant = scene.instantiate()
			if not candidate_value is Node:
				return null
			candidate = candidate_value
		if before_add.is_valid():
			var _before_add_result: Variant = before_add.call(candidate)
		parent.add_child(candidate)
		if acquire_count - 1 == invalidate_acquire_index:
			var runtime: Node = candidate.get_node_or_null(NodePath("ProjectileRuntime"))
			if runtime != null:
				candidate.remove_child(runtime)
				runtime.free()
		if not acquired_nodes.has(candidate):
			acquired_nodes.append(candidate)
		return candidate

	func release(node: Node, _scene: PackedScene) -> void:
		release_count += 1
		released_nodes.append(node)
		if node != null and is_instance_valid(node) and node.get_parent() != null:
			node.get_parent().remove_child(node)
		if reuse_released_nodes and node != null and is_instance_valid(node):
			_available_nodes.append(node)


class LostLeaseRecordingPool extends GFObjectPoolUtility:
	var lost_retirement_count: int = 0
	var lost_retirement_ids: Array[int] = []

	func retire_lost_lease_for_framework(
		scene: PackedScene,
		instance_id: int
	) -> bool:
		var settled: bool = super.retire_lost_lease_for_framework(scene, instance_id)
		if settled:
			lost_retirement_count += 1
			lost_retirement_ids.append(instance_id)
		return settled


class ReleasingPrewarmPool extends RecordingObjectPool:
	var emitter: GFProjectileEmitter2D = null
	var prewarm_count: int = 0
	var reentrant_roots: Array[Node] = []

	func prewarm(
		_scene: PackedScene,
		_parent: Node,
		_count: int,
		_before_add: Callable = Callable()
	) -> void:
		prewarm_count += 1
		if emitter == null:
			return
		reentrant_roots = emitter.emit_projectiles(
			GFProjectileLaunchInput2D.new(),
			&"",
			1
		)
		var emitter_parent: Node = emitter.get_parent()
		if emitter_parent != null:
			emitter_parent.remove_child(emitter)


# --- 私有/辅助方法 ---


func _make_bound_projectile_root_2d(
	impact_source_names: Array[StringName] = []
) -> Node2D:
	var root: Node2D = Node2D.new()
	root.name = &"ProjectileRoot2D"
	var runtime: GFProjectile2D = GFProjectile2D.new()
	runtime.name = &"ProjectileRuntime"
	root.add_child(runtime)
	for source_name: StringName in impact_source_names:
		var source: GFHitBox2D = GFHitBox2D.new()
		source.name = source_name
		root.add_child(source)
	return root


func _make_bound_projectile_root_3d(
	impact_source_names: Array[StringName] = []
) -> Node3D:
	var root: Node3D = Node3D.new()
	root.name = &"ProjectileRoot3D"
	var runtime: GFProjectile3D = GFProjectile3D.new()
	runtime.name = &"ProjectileRuntime"
	root.add_child(runtime)
	for source_name: StringName in impact_source_names:
		var source: GFHitBox3D = GFHitBox3D.new()
		source.name = source_name
		root.add_child(source)
	return root


func _pack_projectile_root(root: Node) -> PackedScene:
	_set_scene_owner_recursively(root, root)
	var scene: PackedScene = PackedScene.new()
	var pack_result: Error = scene.pack(root)
	root.free()
	assert_eq(pack_result, OK, "Projectile 测试场景必须可稳定打包。")
	return scene if pack_result == OK else null


func _set_scene_owner_recursively(node: Node, scene_owner: Node) -> void:
	for child: Node in node.get_children():
		child.owner = scene_owner
		_set_scene_owner_recursively(child, scene_owner)


func _make_projectile_definition_2d(
	impact_source_paths: Array[NodePath] = []
) -> GFProjectileDefinition2D:
	var source_names: Array[StringName] = []
	for source_path: NodePath in impact_source_paths:
		if source_path.get_name_count() == 1:
			source_names.append(StringName(source_path.get_name(0)))
	var definition: GFProjectileDefinition2D = GFProjectileDefinition2D.new()
	definition.scene = _pack_projectile_root(
		_make_bound_projectile_root_2d(source_names)
	)
	definition.runtime_path = NodePath("ProjectileRuntime")
	definition.impact_source_paths = impact_source_paths.duplicate()
	definition.motion = GFLinearProjectileMotion.new()
	definition.body_adapter = GFProjectileTransformBodyAdapter2D.new()
	return definition


func _make_projectile_definition_3d(
	impact_source_paths: Array[NodePath] = []
) -> GFProjectileDefinition3D:
	var source_names: Array[StringName] = []
	for source_path: NodePath in impact_source_paths:
		if source_path.get_name_count() == 1:
			source_names.append(StringName(source_path.get_name(0)))
	var definition: GFProjectileDefinition3D = GFProjectileDefinition3D.new()
	definition.scene = _pack_projectile_root(
		_make_bound_projectile_root_3d(source_names)
	)
	definition.runtime_path = NodePath("ProjectileRuntime")
	definition.impact_source_paths = impact_source_paths.duplicate()
	definition.motion = GFLinearProjectileMotion.new()
	definition.body_adapter = GFProjectileTransformBodyAdapter3D.new()
	return definition


func _runtime_2d_from(root: Node) -> GFProjectile2D:
	var value: Node = root.get_node_or_null(NodePath("ProjectileRuntime"))
	if value is GFProjectile2D:
		var runtime: GFProjectile2D = value
		return runtime
	return null


func _runtime_3d_from(root: Node) -> GFProjectile3D:
	var value: Node = root.get_node_or_null(NodePath("ProjectileRuntime"))
	if value is GFProjectile3D:
		var runtime: GFProjectile3D = value
		return runtime
	return null


func _weakref_points_to_live_lifetime(reference: WeakRef) -> bool:
	if reference == null:
		return false
	var value: Variant = reference.get_ref()
	if not value is GFProjectileLifetimePolicy:
		return false
	var lifetime: GFProjectileLifetimePolicy = value
	return is_instance_valid(lifetime)


func _weakref_points_to_live_motion_state(reference: WeakRef) -> bool:
	if reference == null:
		return false
	var value: Variant = reference.get_ref()
	if not value is GFProjectileMotionState:
		return false
	var state: GFProjectileMotionState = value
	return is_instance_valid(state)


func _assert_hostile_failure_details(details: Dictionary) -> void:
	var expected_keys: Array[StringName] = [
		&"ok",
		&"reason",
		&"policy_id",
		&"projectile_id",
		&"requested_count",
		&"emit_count",
		&"now_msec",
		&"policy_instance_id",
		&"policy_state_generation",
		&"policy_enabled",
		&"published",
		&"committed",
		&"compensated",
		&"rolled_back",
		&"emitted_count",
		&"consumed_charges",
	]
	assert_eq(details.size(), 16, "失败详情必须在 16 个已接受字段处封顶。")
	for key: StringName in expected_keys:
		assert_true(details.has(key), "失败详情缺少允许字段 %s。" % key)
	var forbidden_keys: Array[StringName] = [
		&"unknown_detail",
		&"remaining_cooldown_seconds",
		&"available_charges",
		&"required_charges",
		&"emission_count",
		&"hard_limit",
		&"state",
	]
	for forbidden_key: StringName in forbidden_keys:
		assert_false(details.has(forbidden_key), "失败详情不得泄漏字段 %s。" % forbidden_key)
	var reason_value: Variant = details[&"reason"]
	assert_eq(typeof(reason_value), TYPE_STRING)
	var reason_text: String = reason_value if reason_value is String else ""
	assert_eq(reason_text.length(), 256)
	var policy_id_value: Variant = details[&"policy_id"]
	assert_eq(typeof(policy_id_value), TYPE_STRING_NAME)
	var policy_id: StringName = policy_id_value if policy_id_value is StringName else &""
	assert_eq(String(policy_id).length(), 128)
	var projectile_id_value: Variant = details[&"projectile_id"]
	assert_eq(typeof(projectile_id_value), TYPE_NODE_PATH)
	var projectile_id: NodePath = (
		projectile_id_value if projectile_id_value is NodePath else NodePath("")
	)
	assert_eq(String(projectile_id).length(), 256)
	for value: Variant in details.values():
		assert_ne(typeof(value), TYPE_OBJECT, "失败详情不得保留 Object/RefCounted。")
		if typeof(value) == TYPE_FLOAT:
			var float_value: float = value
			assert_true(is_finite(float_value), "失败详情只允许有限 float。")


func _hit_box_2d_from(root: Node, source_path: NodePath) -> GFHitBox2D:
	var value: Node = root.get_node_or_null(source_path)
	if value is GFHitBox2D:
		var source: GFHitBox2D = value
		return source
	return null


func _hit_box_3d_from(root: Node, source_path: NodePath) -> GFHitBox3D:
	var value: Node = root.get_node_or_null(source_path)
	if value is GFHitBox3D:
		var source: GFHitBox3D = value
		return source
	return null


func _first_signal_callable(source: Object, signal_name: StringName) -> Callable:
	for connection: Dictionary in source.get_signal_connection_list(signal_name):
		var callback_value: Variant = GFVariantData.get_option_value(connection, "callable")
		if callback_value is Callable:
			var callback: Callable = callback_value
			return callback
	return Callable()


func _count_retirement_records_in_tree(name_prefix: StringName) -> int:
	var scene_tree: SceneTree = get_tree()
	if scene_tree == null or scene_tree.root == null:
		return 0
	var count: int = 0
	var prefix: String = String(name_prefix)
	for child: Node in scene_tree.root.get_children():
		if String(child.name).contains(prefix):
			count += 1
	return count


func _finish_projectile_sessions(sessions: Array[GFProjectileSession]) -> void:
	for active_session: GFProjectileSession in sessions:
		if active_session != null and active_session.is_active():
			var _finished: bool = active_session.finish(
				GFProjectileSession.EndReason.CALLER_FINISHED
			)


# --- 测试 ---

func test_projectile_definition_binds_zero_one_or_many_explicit_impact_sources() -> void:
	for source_count: int in [0, 1, 3]:
		var source_names: Array[StringName] = []
		var source_paths: Array[NodePath] = []
		for source_index: int in range(source_count):
			var source_name: StringName = StringName("Impact%d" % source_index)
			source_names.append(source_name)
			source_paths.append(NodePath(String(source_name)))

		var root_2d: Node2D = _make_bound_projectile_root_2d(source_names)
		add_child_autofree(root_2d)
		var definition_2d: GFProjectileDefinition2D = (
			_make_projectile_definition_2d(source_paths)
		)
		var binding_2d: GFProjectileBinding2D = definition_2d.bind_instance(root_2d)
		var typed_definition_2d: GFProjectileDefinition2D = binding_2d.get_definition()
		var typed_root_2d: Node2D = binding_2d.get_instance_root()
		var typed_runtime_2d: GFProjectile2D = binding_2d.get_runtime()
		var typed_adapter_2d: GFProjectileBodyAdapter2D = binding_2d.get_body_adapter()

		assert_true(binding_2d.is_valid(), "2D 定义应接受显式 0..N 个同根命中源。")
		assert_eq(
			binding_2d.get_failure_reason(),
			GFProjectileBinding.FailureReason.NONE
		)
		assert_same(typed_definition_2d, definition_2d)
		assert_same(typed_root_2d, root_2d)
		assert_same(typed_runtime_2d, _runtime_2d_from(root_2d))
		assert_same(typed_adapter_2d, definition_2d.body_adapter)
		assert_eq(binding_2d.get_impact_sources().size(), source_count)
		assert_true(binding_2d.is_current())

		var root_3d: Node3D = _make_bound_projectile_root_3d(source_names)
		add_child_autofree(root_3d)
		var definition_3d: GFProjectileDefinition3D = (
			_make_projectile_definition_3d(source_paths)
		)
		var binding_3d: GFProjectileBinding3D = definition_3d.bind_instance(root_3d)
		var typed_definition_3d: GFProjectileDefinition3D = binding_3d.get_definition()
		var typed_root_3d: Node3D = binding_3d.get_instance_root()
		var typed_runtime_3d: GFProjectile3D = binding_3d.get_runtime()
		var typed_adapter_3d: GFProjectileBodyAdapter3D = binding_3d.get_body_adapter()

		assert_true(binding_3d.is_valid(), "3D 定义应与 2D 对称地接受显式 0..N 个命中源。")
		assert_eq(
			binding_3d.get_failure_reason(),
			GFProjectileBinding.FailureReason.NONE
		)
		assert_same(typed_definition_3d, definition_3d)
		assert_same(typed_root_3d, root_3d)
		assert_same(typed_runtime_3d, _runtime_3d_from(root_3d))
		assert_same(typed_adapter_3d, definition_3d.body_adapter)
		assert_eq(binding_3d.get_impact_sources().size(), source_count)
		assert_true(binding_3d.is_current())


func test_projectile_binding_default_constructor_is_closed_internal_failure() -> void:
	var binding: GFProjectileBinding = GFProjectileBinding.new()
	assert_false(binding.is_valid())
	assert_false(binding.is_current())
	assert_eq(
		binding.get_failure_reason(),
		GFProjectileBinding.FailureReason.INTERNAL_FAILURE
	)
	assert_null(binding.get_definition())
	assert_null(binding.get_instance_root())
	assert_null(binding.get_runtime())
	assert_true(binding.get_impact_sources().is_empty())
	assert_null(binding.get_body_adapter())


func test_projectile_binding_rejects_malformed_runtime_topology() -> void:
	var valid_root: Node2D = _make_bound_projectile_root_2d()
	add_child_autofree(valid_root)
	var missing_path_definition: GFProjectileDefinition2D = _make_projectile_definition_2d()
	missing_path_definition.runtime_path = NodePath("")
	var missing_path: GFProjectileBinding2D = missing_path_definition.bind_instance(valid_root)
	assert_false(missing_path.is_valid())
	assert_eq(
		missing_path.get_failure_reason(),
		GFProjectileBinding.FailureReason.MISSING_RUNTIME_PATH
	)

	var missing_root: Node2D = Node2D.new()
	add_child_autofree(missing_root)
	var definition: GFProjectileDefinition2D = _make_projectile_definition_2d()
	var missing_runtime: GFProjectileBinding2D = definition.bind_instance(missing_root)
	assert_false(missing_runtime.is_valid())
	assert_eq(
		missing_runtime.get_failure_reason(),
		GFProjectileBinding.FailureReason.MISSING_RUNTIME
	)

	var ambiguous_root: Node2D = _make_bound_projectile_root_2d()
	var extra_runtime: GFProjectile2D = GFProjectile2D.new()
	extra_runtime.name = &"OtherRuntime"
	ambiguous_root.add_child(extra_runtime)
	add_child_autofree(ambiguous_root)
	var ambiguous: GFProjectileBinding2D = definition.bind_instance(ambiguous_root)
	assert_false(ambiguous.is_valid())
	assert_eq(
		ambiguous.get_failure_reason(),
		GFProjectileBinding.FailureReason.AMBIGUOUS_RUNTIME
	)

	var mismatched_root: Node2D = Node2D.new()
	var marker: Node2D = Node2D.new()
	marker.name = &"ProjectileRuntime"
	mismatched_root.add_child(marker)
	var actual_runtime: GFProjectile2D = GFProjectile2D.new()
	actual_runtime.name = &"ActualRuntime"
	mismatched_root.add_child(actual_runtime)
	add_child_autofree(mismatched_root)
	var mismatched: GFProjectileBinding2D = definition.bind_instance(mismatched_root)
	assert_false(mismatched.is_valid())
	assert_eq(
		mismatched.get_failure_reason(),
		GFProjectileBinding.FailureReason.RUNTIME_PATH_MISMATCH
	)


func test_projectile_binding_rejects_outside_or_wrong_dimension_runtime() -> void:
	var common_parent: Node = Node.new()
	add_child_autofree(common_parent)
	var root_2d: Node2D = Node2D.new()
	root_2d.name = &"BoundRoot"
	common_parent.add_child(root_2d)
	var outside_runtime: GFProjectile2D = GFProjectile2D.new()
	outside_runtime.name = &"OutsideRuntime"
	common_parent.add_child(outside_runtime)
	var outside_definition: GFProjectileDefinition2D = _make_projectile_definition_2d()
	outside_definition.runtime_path = NodePath("../OutsideRuntime")
	var outside: GFProjectileBinding2D = outside_definition.bind_instance(root_2d)
	assert_false(outside.is_valid())
	assert_eq(
		outside.get_failure_reason(),
		GFProjectileBinding.FailureReason.RUNTIME_OUTSIDE_ROOT
	)

	var root_3d: Node3D = _make_bound_projectile_root_3d()
	add_child_autofree(root_3d)
	var definition_2d: GFProjectileDefinition2D = _make_projectile_definition_2d()
	var wrong_dimension: GFProjectileBinding2D = definition_2d.bind_instance(root_3d)
	assert_false(wrong_dimension.is_valid())
	assert_eq(
		wrong_dimension.get_failure_reason(),
		GFProjectileBinding.FailureReason.ROOT_DIMENSION_MISMATCH
	)

	var dimensional_runtime_root: Node2D = Node2D.new()
	var dimensional_runtime: GFProjectile3D = GFProjectile3D.new()
	dimensional_runtime.name = &"ProjectileRuntime"
	dimensional_runtime_root.add_child(dimensional_runtime)
	add_child_autofree(dimensional_runtime_root)
	var runtime_dimension_mismatch: GFProjectileBinding2D = (
		definition_2d.bind_instance(dimensional_runtime_root)
	)
	assert_false(runtime_dimension_mismatch.is_valid())
	assert_eq(
		runtime_dimension_mismatch.get_failure_reason(),
		GFProjectileBinding.FailureReason.RUNTIME_DIMENSION_MISMATCH
	)


func test_projectile_binding_rejects_invalid_definition_root_and_dependencies() -> void:
	var definition: GFProjectileDefinition2D = _make_projectile_definition_2d()
	var invalid_root: GFProjectileBinding2D = definition.bind_instance(null)
	assert_false(invalid_root.is_valid())
	assert_eq(
		invalid_root.get_failure_reason(),
		GFProjectileBinding.FailureReason.INVALID_ROOT
	)

	var detached_root: Node2D = _make_bound_projectile_root_2d()
	var detached: GFProjectileBinding2D = definition.bind_instance(detached_root)
	assert_false(detached.is_valid())
	assert_eq(
		detached.get_failure_reason(),
		GFProjectileBinding.FailureReason.ROOT_NOT_IN_TREE
	)
	detached_root.free()

	var root: Node2D = _make_bound_projectile_root_2d()
	add_child_autofree(root)
	var invalid_definition: GFProjectileDefinition2D = _make_projectile_definition_2d()
	invalid_definition.scene = null
	var invalid: GFProjectileBinding2D = invalid_definition.bind_instance(root)
	assert_false(invalid.is_valid())
	assert_eq(
		invalid.get_failure_reason(),
		GFProjectileBinding.FailureReason.INVALID_DEFINITION
	)

	var missing_motion_definition: GFProjectileDefinition2D = _make_projectile_definition_2d()
	missing_motion_definition.motion = null
	var missing_motion: GFProjectileBinding2D = missing_motion_definition.bind_instance(root)
	assert_false(missing_motion.is_valid())
	assert_eq(
		missing_motion.get_failure_reason(),
		GFProjectileBinding.FailureReason.MISSING_MOTION
	)

	var missing_adapter_definition: GFProjectileDefinition2D = _make_projectile_definition_2d()
	missing_adapter_definition.body_adapter = null
	var missing_adapter: GFProjectileBinding2D = missing_adapter_definition.bind_instance(root)
	assert_false(missing_adapter.is_valid())
	assert_eq(
		missing_adapter.get_failure_reason(),
		GFProjectileBinding.FailureReason.MISSING_BODY_ADAPTER
	)


func test_projectile_binding_rechecks_root_after_adapter_validation_callback() -> void:
	var root: Node2D = _make_bound_projectile_root_2d()
	add_child(root)
	var root_ref: WeakRef = weakref(root)
	var definition: GFProjectileDefinition2D = _make_projectile_definition_2d()
	var adapter: FreeingValidateAdapter2D = FreeingValidateAdapter2D.new()
	definition.body_adapter = adapter

	var binding: GFProjectileBinding2D = definition.bind_instance(root)
	assert_false(binding.is_valid())
	assert_eq(
		binding.get_failure_reason(),
		GFProjectileBinding.FailureReason.INVALID_ROOT,
		"adapter validation callback 释放 root 后 binding 必须 fail-close，不能继续解析 topology。"
	)
	assert_eq(adapter.validate_count, 1)
	assert_true(root_ref.get_ref() == null)


func test_projectile_binding_rejects_definition_mutation_during_adapter_validation() -> void:
	var root: Node2D = _make_bound_projectile_root_2d()
	add_child_autofree(root)
	var definition: GFProjectileDefinition2D = _make_projectile_definition_2d()
	var adapter: MutatingValidateAdapter2D = MutatingValidateAdapter2D.new()
	adapter.definition = definition
	definition.body_adapter = adapter

	var binding: GFProjectileBinding2D = definition.bind_instance(root)
	assert_false(binding.is_valid())
	assert_eq(
		binding.get_failure_reason(),
		GFProjectileBinding.FailureReason.INVALID_DEFINITION,
		"adapter callback 改写 definition 后必须由同一 bind fence fail-close。"
	)
	assert_eq(adapter.validate_count, 1)
	adapter.definition = null


func test_projectile_binding_rejects_runtime_already_claimed_by_active_session() -> void:
	var root: Node2D = _make_bound_projectile_root_2d()
	add_child_autofree(root)
	var definition: GFProjectileDefinition2D = _make_projectile_definition_2d()
	var first_binding: GFProjectileBinding2D = definition.bind_instance(root)
	assert_true(first_binding.is_valid())
	if not first_binding.is_valid():
		return
	var runtime: GFProjectile2D = _runtime_2d_from(root)
	var session: GFProjectileSession = runtime.launch(first_binding)
	assert_true(session.is_active())
	var busy_binding: GFProjectileBinding2D = definition.bind_instance(root)
	assert_false(busy_binding.is_valid())
	assert_eq(
		busy_binding.get_failure_reason(),
		GFProjectileBinding.FailureReason.RUNTIME_BUSY
	)
	var _finished: bool = session.finish(GFProjectileSession.EndReason.CALLER_FINISHED)


func test_projectile_binding_rejects_invalid_impact_source_topology() -> void:
	var invalid_root: Node2D = _make_bound_projectile_root_2d()
	add_child_autofree(invalid_root)
	var invalid_paths: Array[NodePath] = [NodePath("")]
	var invalid_definition: GFProjectileDefinition2D = (
		_make_projectile_definition_2d(invalid_paths)
	)
	var invalid: GFProjectileBinding2D = invalid_definition.bind_instance(invalid_root)
	assert_false(invalid.is_valid())
	assert_eq(
		invalid.get_failure_reason(),
		GFProjectileBinding.FailureReason.INVALID_IMPACT_SOURCE
	)

	var duplicate_root: Node2D = _make_bound_projectile_root_2d([&"Impact"])
	add_child_autofree(duplicate_root)
	var duplicate_paths: Array[NodePath] = [NodePath("Impact"), NodePath("Impact")]
	var duplicate_definition: GFProjectileDefinition2D = (
		_make_projectile_definition_2d(duplicate_paths)
	)
	var duplicate_binding: GFProjectileBinding2D = duplicate_definition.bind_instance(duplicate_root)
	assert_false(duplicate_binding.is_valid())
	assert_eq(
		duplicate_binding.get_failure_reason(),
		GFProjectileBinding.FailureReason.DUPLICATE_IMPACT_SOURCE
	)
	var alias_root: Node2D = _make_bound_projectile_root_2d([&"Impact"])
	var alias_folder: Node = Node.new()
	alias_folder.name = &"Folder"
	alias_root.add_child(alias_folder)
	add_child_autofree(alias_root)
	var alias_paths: Array[NodePath] = [
		NodePath("Impact"),
		NodePath("Folder/../Impact"),
	]
	var alias_definition: GFProjectileDefinition2D = _make_projectile_definition_2d(
		alias_paths
	)
	var alias_binding: GFProjectileBinding2D = alias_definition.bind_instance(alias_root)
	assert_false(alias_binding.is_valid())
	assert_eq(
		alias_binding.get_failure_reason(),
		GFProjectileBinding.FailureReason.DUPLICATE_IMPACT_SOURCE,
		"不同 NodePath 别名解析到同一 source 时也必须拒绝，避免一次 impact 重复计数。"
	)

	var missing_root: Node2D = _make_bound_projectile_root_2d()
	add_child_autofree(missing_root)
	var missing_paths: Array[NodePath] = [NodePath("MissingImpact")]
	var missing_definition: GFProjectileDefinition2D = (
		_make_projectile_definition_2d(missing_paths)
	)
	var missing: GFProjectileBinding2D = missing_definition.bind_instance(missing_root)
	assert_false(missing.is_valid())
	assert_eq(
		missing.get_failure_reason(),
		GFProjectileBinding.FailureReason.MISSING_IMPACT_SOURCE
	)

	var common_parent: Node2D = Node2D.new()
	add_child_autofree(common_parent)
	var outside_root: Node2D = _make_bound_projectile_root_2d()
	outside_root.name = &"BoundRoot"
	common_parent.add_child(outside_root)
	var outside_source: GFHitBox2D = GFHitBox2D.new()
	outside_source.name = &"OutsideImpact"
	common_parent.add_child(outside_source)
	var outside_paths: Array[NodePath] = [NodePath("../OutsideImpact")]
	var outside_definition: GFProjectileDefinition2D = (
		_make_projectile_definition_2d(outside_paths)
	)
	var outside: GFProjectileBinding2D = outside_definition.bind_instance(outside_root)
	assert_false(outside.is_valid())
	assert_eq(
		outside.get_failure_reason(),
		GFProjectileBinding.FailureReason.IMPACT_SOURCE_OUTSIDE_ROOT
	)

	var dimensional_root: Node2D = _make_bound_projectile_root_2d()
	var dimensional_source: GFHitBox3D = GFHitBox3D.new()
	dimensional_source.name = &"WrongDimensionImpact"
	dimensional_root.add_child(dimensional_source)
	add_child_autofree(dimensional_root)
	var dimensional_paths: Array[NodePath] = [NodePath("WrongDimensionImpact")]
	var dimensional_definition: GFProjectileDefinition2D = (
		_make_projectile_definition_2d(dimensional_paths)
	)
	var dimensional: GFProjectileBinding2D = (
		dimensional_definition.bind_instance(dimensional_root)
	)
	assert_false(dimensional.is_valid())
	assert_eq(
		dimensional.get_failure_reason(),
		GFProjectileBinding.FailureReason.IMPACT_SOURCE_DIMENSION_MISMATCH
	)


func test_projectile_body_adapters_are_dimension_symmetric_and_body_specific() -> void:
	var transform_2d: GFProjectileTransformBodyAdapter2D = (
		GFProjectileTransformBodyAdapter2D.new()
	)
	var transform_3d: GFProjectileTransformBodyAdapter3D = (
		GFProjectileTransformBodyAdapter3D.new()
	)
	var character_2d: GFProjectileCharacterBodyAdapter2D = (
		GFProjectileCharacterBodyAdapter2D.new()
	)
	var character_3d: GFProjectileCharacterBodyAdapter3D = (
		GFProjectileCharacterBodyAdapter3D.new()
	)
	var node_2d: Node2D = Node2D.new()
	var node_3d: Node3D = Node3D.new()
	var body_2d: CharacterBody2D = CharacterBody2D.new()
	var body_3d: CharacterBody3D = CharacterBody3D.new()

	assert_eq(transform_2d.validate_root(node_2d), OK)
	assert_eq(transform_3d.validate_root(node_3d), OK)
	assert_ne(transform_2d.validate_root(body_2d), OK, "Transform adapter 必须拒绝 2D PhysicsBody。")
	assert_ne(transform_3d.validate_root(body_3d), OK, "Transform adapter 必须拒绝 3D PhysicsBody。")
	assert_eq(character_2d.validate_root(body_2d), OK)
	assert_eq(character_3d.validate_root(body_3d), OK)
	assert_ne(character_2d.validate_root(node_2d), OK)
	assert_ne(character_3d.validate_root(node_3d), OK)

	node_2d.free()
	node_3d.free()
	body_2d.free()
	body_3d.free()


func test_projectile_motion_2d_only_moves_root_through_body_adapter() -> void:
	var root: Node2D = Node2D.new()
	root.position = Vector2(1.0, 2.0)
	add_child_autofree(root)
	var adapter: GFProjectileTransformBodyAdapter2D = (
		GFProjectileTransformBodyAdapter2D.new()
	)
	var initial_body: GFProjectileBodyResult2D = adapter.capture_body(root)
	assert_true(initial_body.is_successful())
	assert_eq(initial_body.get_position(), Vector2(1.0, 2.0))
	assert_eq(initial_body.get_actual_displacement(), Vector2.ZERO)
	var input: GFProjectileLaunchInput2D = GFProjectileLaunchInput2D.new()
	input.set_target_none()
	var motion: GFLinearProjectileMotion = GFLinearProjectileMotion.new()
	motion.speed = 4.0
	motion.use_local_direction = false
	motion.direction_2d = Vector2.RIGHT
	var state: GFProjectileMotionState = motion.create_state_2d(input, initial_body)
	var before_compute: Transform2D = root.transform

	var intent: GFProjectileMotionIntent2D = motion.compute_intent_2d(
		state,
		initial_body,
		0.5
	)
	assert_eq(root.transform, before_compute, "Motion policy 计算 intent 时不得触碰宿主 Node。")
	assert_true(intent.is_valid())
	assert_eq(intent.get_kind(), GFProjectileMotionIntent2D.Kind.MOVE)
	assert_eq(intent.get_velocity(), Vector2(4.0, 0.0))
	assert_almost_eq(intent.get_delta_seconds(), 0.5, 0.0001)
	assert_eq(intent.get_failure_reason(), &"")

	var applied_body: GFProjectileBodyResult2D = adapter.apply_intent(root, intent)
	assert_true(applied_body.is_successful())
	assert_eq(root.position, Vector2(3.0, 2.0))
	assert_eq(applied_body.get_position(), Vector2(3.0, 2.0))
	assert_eq(applied_body.get_actual_displacement(), Vector2(2.0, 0.0))
	assert_eq(applied_body.get_transform(), root.transform)


func test_projectile_motion_3d_only_moves_root_through_body_adapter() -> void:
	var root: Node3D = Node3D.new()
	root.position = Vector3(1.0, 2.0, 3.0)
	add_child_autofree(root)
	var adapter: GFProjectileTransformBodyAdapter3D = (
		GFProjectileTransformBodyAdapter3D.new()
	)
	var initial_body: GFProjectileBodyResult3D = adapter.capture_body(root)
	assert_true(initial_body.is_successful())
	assert_eq(initial_body.get_position(), Vector3(1.0, 2.0, 3.0))
	assert_eq(initial_body.get_actual_displacement(), Vector3.ZERO)
	var input: GFProjectileLaunchInput3D = GFProjectileLaunchInput3D.new()
	input.set_target_none()
	var motion: GFLinearProjectileMotion = GFLinearProjectileMotion.new()
	motion.speed = 6.0
	motion.use_local_direction = false
	motion.direction_3d = Vector3(0.0, 0.0, -1.0)
	var state: GFProjectileMotionState = motion.create_state_3d(input, initial_body)
	var before_compute: Transform3D = root.transform

	var intent: GFProjectileMotionIntent3D = motion.compute_intent_3d(
		state,
		initial_body,
		0.25
	)
	assert_eq(root.transform, before_compute, "3D Motion policy 计算 intent 时同样不得触碰宿主 Node。")
	assert_true(intent.is_valid())
	assert_eq(intent.get_kind(), GFProjectileMotionIntent3D.Kind.MOVE)
	assert_eq(intent.get_velocity(), Vector3(0.0, 0.0, -6.0))
	assert_almost_eq(intent.get_delta_seconds(), 0.25, 0.0001)
	assert_eq(intent.get_failure_reason(), &"")

	var applied_body: GFProjectileBodyResult3D = adapter.apply_intent(root, intent)
	assert_true(applied_body.is_successful())
	assert_eq(root.position, Vector3(1.0, 2.0, 1.5))
	assert_eq(applied_body.get_position(), Vector3(1.0, 2.0, 1.5))
	assert_eq(applied_body.get_actual_displacement(), Vector3(0.0, 0.0, -1.5))
	assert_eq(applied_body.get_transform(), root.transform)


func test_projectile_body_adapters_do_not_apply_rejected_intents() -> void:
	var root_2d: Node2D = Node2D.new()
	root_2d.position = Vector2(2.0, 3.0)
	var root_3d: Node3D = Node3D.new()
	root_3d.position = Vector3(2.0, 3.0, 4.0)
	add_child_autofree(root_2d)
	add_child_autofree(root_3d)
	var move_2d: GFProjectileMotionIntent2D = GFProjectileMotionIntent2D.move(
		Vector2(2.0, 0.0),
		0.5
	)
	var move_3d: GFProjectileMotionIntent3D = GFProjectileMotionIntent3D.move(
		Vector3(0.0, 0.0, -2.0),
		0.5
	)
	assert_eq(move_2d.get_kind(), GFProjectileMotionIntent2D.Kind.MOVE)
	assert_eq(move_3d.get_kind(), GFProjectileMotionIntent3D.Kind.MOVE)
	assert_eq(move_2d.get_velocity(), Vector2(2.0, 0.0))
	assert_eq(move_3d.get_velocity(), Vector3(0.0, 0.0, -2.0))
	assert_almost_eq(move_2d.get_delta_seconds(), 0.5, 0.0001)
	assert_almost_eq(move_3d.get_delta_seconds(), 0.5, 0.0001)
	assert_true(move_2d.is_valid())
	assert_true(move_3d.is_valid())
	var rejected_2d: GFProjectileMotionIntent2D = (
		GFProjectileMotionIntent2D.rejected(&"motion_blocked")
	)
	var rejected_3d: GFProjectileMotionIntent3D = (
		GFProjectileMotionIntent3D.rejected(&"motion_blocked")
	)
	assert_eq(rejected_2d.get_kind(), GFProjectileMotionIntent2D.Kind.REJECTED)
	assert_eq(rejected_3d.get_kind(), GFProjectileMotionIntent3D.Kind.REJECTED)
	assert_false(rejected_2d.is_valid())
	assert_false(rejected_3d.is_valid())
	assert_eq(rejected_2d.get_failure_reason(), &"motion_blocked")
	assert_eq(rejected_3d.get_failure_reason(), &"motion_blocked")

	var result_2d: GFProjectileBodyResult2D = (
		GFProjectileTransformBodyAdapter2D.new().apply_intent(root_2d, rejected_2d)
	)
	var result_3d: GFProjectileBodyResult3D = (
		GFProjectileTransformBodyAdapter3D.new().apply_intent(root_3d, rejected_3d)
	)
	assert_false(result_2d.is_successful())
	assert_false(result_3d.is_successful())
	assert_eq(result_2d.get_failure_reason(), &"motion_blocked")
	assert_eq(result_3d.get_failure_reason(), &"motion_blocked")
	assert_eq(result_2d.get_actual_displacement(), Vector2.ZERO)
	assert_eq(result_3d.get_actual_displacement(), Vector3.ZERO)
	assert_eq(root_2d.position, Vector2(2.0, 3.0))
	assert_eq(root_3d.position, Vector3(2.0, 3.0, 4.0))


func test_projectile_body_adapters_stop_without_extra_displacement() -> void:
	var transform_root_2d: Node2D = Node2D.new()
	transform_root_2d.position = Vector2(2.0, 3.0)
	var transform_root_3d: Node3D = Node3D.new()
	transform_root_3d.position = Vector3(2.0, 3.0, 4.0)
	var character_root_2d: CharacterBody2D = CharacterBody2D.new()
	character_root_2d.position = Vector2(4.0, 5.0)
	character_root_2d.velocity = Vector2(3.0, 4.0)
	var character_root_3d: CharacterBody3D = CharacterBody3D.new()
	character_root_3d.position = Vector3(4.0, 5.0, 6.0)
	character_root_3d.velocity = Vector3(1.0, 2.0, 3.0)
	add_child_autofree(transform_root_2d)
	add_child_autofree(transform_root_3d)
	add_child_autofree(character_root_2d)
	add_child_autofree(character_root_3d)

	var transform_result_2d: GFProjectileBodyResult2D = (
		GFProjectileTransformBodyAdapter2D.new().stop(transform_root_2d)
	)
	var transform_result_3d: GFProjectileBodyResult3D = (
		GFProjectileTransformBodyAdapter3D.new().stop(transform_root_3d)
	)
	var character_adapter_2d: GFProjectileCharacterBodyAdapter2D = (
		GFProjectileCharacterBodyAdapter2D.new()
	)
	var character_adapter_3d: GFProjectileCharacterBodyAdapter3D = (
		GFProjectileCharacterBodyAdapter3D.new()
	)
	var character_result_2d: GFProjectileBodyResult2D = (
		character_adapter_2d.stop(character_root_2d)
	)
	var character_result_3d: GFProjectileBodyResult3D = (
		character_adapter_3d.stop(character_root_3d)
	)
	assert_true(transform_result_2d.is_successful())
	assert_true(transform_result_3d.is_successful())
	assert_true(character_result_2d.is_successful())
	assert_true(character_result_3d.is_successful())
	assert_eq(transform_result_2d.get_actual_displacement(), Vector2.ZERO)
	assert_eq(transform_result_3d.get_actual_displacement(), Vector3.ZERO)
	assert_eq(character_result_2d.get_actual_displacement(), Vector2.ZERO)
	assert_eq(character_result_3d.get_actual_displacement(), Vector3.ZERO)
	assert_eq(transform_root_2d.position, Vector2(2.0, 3.0))
	assert_eq(transform_root_3d.position, Vector3(2.0, 3.0, 4.0))
	assert_eq(character_root_2d.position, Vector2(4.0, 5.0))
	assert_eq(character_root_3d.position, Vector3(4.0, 5.0, 6.0))
	assert_eq(character_root_2d.velocity, Vector2.ZERO)
	assert_eq(character_root_3d.velocity, Vector3.ZERO)
	var repeated_2d: GFProjectileBodyResult2D = character_adapter_2d.stop(character_root_2d)
	var repeated_3d: GFProjectileBodyResult3D = character_adapter_3d.stop(character_root_3d)
	assert_true(repeated_2d.is_successful())
	assert_true(repeated_3d.is_successful())
	assert_eq(repeated_2d.get_actual_displacement(), Vector2.ZERO)
	assert_eq(repeated_3d.get_actual_displacement(), Vector3.ZERO)


func test_projectile_session_finish_stops_character_body_once() -> void:
	var root: CharacterBody2D = CharacterBody2D.new()
	var runtime: GFProjectile2D = GFProjectile2D.new()
	runtime.name = &"ProjectileRuntime"
	root.add_child(runtime)
	add_child_autofree(root)
	var definition: GFProjectileDefinition2D = _make_projectile_definition_2d()
	definition.body_adapter = GFProjectileCharacterBodyAdapter2D.new()
	var binding: GFProjectileBinding2D = definition.bind_instance(root)
	assert_true(binding.is_valid())
	if not binding.is_valid():
		return
	var session: GFProjectileSession = runtime.launch(binding)
	root.velocity = Vector2(12.0, -3.0)
	var before_finish_position: Vector2 = root.position
	assert_true(session.finish(GFProjectileSession.EndReason.CALLER_FINISHED))
	assert_eq(root.velocity, Vector2.ZERO)
	assert_eq(root.position, before_finish_position)
	assert_false(session.finish(GFProjectileSession.EndReason.INTERNAL_FAILURE))
	assert_eq(root.velocity, Vector2.ZERO)
	assert_eq(root.position, before_finish_position)
	assert_eq(session.get_end_reason(), GFProjectileSession.EndReason.CALLER_FINISHED)


func test_projectile_session_blocks_relaunch_during_adapter_stop_reentry() -> void:
	var root: Node2D = _make_bound_projectile_root_2d()
	add_child_autofree(root)
	var definition: GFProjectileDefinition2D = _make_projectile_definition_2d()
	var adapter: RelaunchingStopAdapter2D = RelaunchingStopAdapter2D.new()
	adapter.definition = definition
	definition.body_adapter = adapter
	var binding: GFProjectileBinding2D = definition.bind_instance(root)
	assert_true(binding.is_valid())
	if not binding.is_valid():
		adapter.definition = null
		return
	var runtime: GFProjectile2D = binding.get_runtime()
	var session: GFProjectileSession = runtime.launch(binding)
	assert_not_null(session)
	if session == null:
		adapter.definition = null
		return
	assert_true(session.finish(GFProjectileSession.EndReason.CALLER_FINISHED))
	assert_null(
		adapter.active_getter_during_stop,
		"FINISHED 已冻结后 get_active_session() 不得暴露 terminal session。"
	)
	assert_eq(
		adapter.stop_binding_reason,
		GFProjectileBinding.FailureReason.RUNTIME_BUSY,
		"stop callback 返回前 runtime ownership 仍必须阻止同 root 重入 launch。"
	)
	assert_null(adapter.relaunch_result)
	assert_false(runtime.is_active())
	assert_null(runtime.get_active_session())
	adapter.definition = null


func test_projectile_runtime_holds_terminal_claim_through_started_and_finished_signals() -> void:
	var root: Node2D = _make_bound_projectile_root_2d()
	add_child_autofree(root)
	var definition: GFProjectileDefinition2D = _make_projectile_definition_2d()
	var binding: GFProjectileBinding2D = definition.bind_instance(root)
	assert_true(binding.is_valid())
	if not binding.is_valid():
		return
	var runtime: GFProjectile2D = binding.get_runtime()
	var event_log: Array[StringName] = []
	var started_reentry_reason: Array[GFProjectileBinding.FailureReason] = [
		GFProjectileBinding.FailureReason.NONE,
	]
	var finished_reentry_reason: Array[GFProjectileBinding.FailureReason] = [
		GFProjectileBinding.FailureReason.NONE,
	]
	var started_relaunch: Array[GFProjectileSession] = [null]
	var finished_relaunch: Array[GFProjectileSession] = [null]
	var on_runtime_finished: Callable = func(
		_finished_session: GFProjectileSession,
		_reason: int
	) -> void:
		event_log.append(&"projectile_finished")
		var reentry_binding: GFProjectileBinding2D = definition.bind_instance(root)
		finished_reentry_reason[0] = reentry_binding.get_failure_reason()
		if reentry_binding.is_valid():
			finished_relaunch[0] = runtime.launch(reentry_binding)
	var _runtime_finished_connected: int = runtime.projectile_finished.connect(
		on_runtime_finished
	)
	var on_started_first: Callable = func(started_session: GFProjectileSession) -> void:
		event_log.append(&"started_first")
		var on_session_finished: Callable = func(
			_finished_session: GFProjectileSession,
			_reason: int
		) -> void:
			event_log.append(&"session_finished")
		var _session_finished_connected: int = started_session.finished.connect(on_session_finished)
		var _finished: bool = started_session.finish(
			GFProjectileSession.EndReason.CALLER_FINISHED
		)
	var on_started_second: Callable = func(_session: GFProjectileSession) -> void:
		event_log.append(&"started_second")
		var reentry_binding: GFProjectileBinding2D = definition.bind_instance(root)
		started_reentry_reason[0] = reentry_binding.get_failure_reason()
		if reentry_binding.is_valid():
			started_relaunch[0] = runtime.launch(reentry_binding)
	var _started_first_connected: int = runtime.projectile_started.connect(on_started_first)
	var _started_second_connected: int = runtime.projectile_started.connect(on_started_second)

	var session: GFProjectileSession = runtime.launch(binding)
	assert_not_null(session)
	assert_eq(
		event_log,
		[&"started_first", &"started_second", &"projectile_finished", &"session_finished"],
		"direct launch 也必须完整发布 started 后才释放 deferred finished。"
	)
	assert_eq(
		started_reentry_reason[0],
		GFProjectileBinding.FailureReason.RUNTIME_BUSY
	)
	assert_eq(
		finished_reentry_reason[0],
		GFProjectileBinding.FailureReason.RUNTIME_BUSY
	)
	assert_null(started_relaunch[0])
	assert_null(finished_relaunch[0])
	assert_false(runtime.is_active())
	assert_true(definition.bind_instance(root).is_valid())


func test_projectile_binding_maps_unsupported_motion_body_for_2d_and_3d() -> void:
	var body_2d: CharacterBody2D = CharacterBody2D.new()
	var runtime_2d: GFProjectile2D = GFProjectile2D.new()
	runtime_2d.name = &"ProjectileRuntime"
	body_2d.add_child(runtime_2d)
	add_child_autofree(body_2d)
	var definition_2d: GFProjectileDefinition2D = _make_projectile_definition_2d()
	var binding_2d: GFProjectileBinding2D = definition_2d.bind_instance(body_2d)
	assert_false(binding_2d.is_valid())
	assert_eq(
		binding_2d.get_failure_reason(),
		GFProjectileBinding.FailureReason.UNSUPPORTED_MOTION_BODY
	)

	var body_3d: CharacterBody3D = CharacterBody3D.new()
	var runtime_3d: GFProjectile3D = GFProjectile3D.new()
	runtime_3d.name = &"ProjectileRuntime"
	body_3d.add_child(runtime_3d)
	add_child_autofree(body_3d)
	var definition_3d: GFProjectileDefinition3D = _make_projectile_definition_3d()
	var binding_3d: GFProjectileBinding3D = definition_3d.bind_instance(body_3d)
	assert_false(binding_3d.is_valid())
	assert_eq(
		binding_3d.get_failure_reason(),
		GFProjectileBinding.FailureReason.UNSUPPORTED_MOTION_BODY
	)


func test_projectile_launch_inputs_keep_closed_targets_and_deep_metadata_copies() -> void:
	var target_2d: Node2D = Node2D.new()
	var target_3d: Node3D = Node3D.new()
	add_child_autofree(target_2d)
	add_child_autofree(target_3d)
	var input_2d: GFProjectileLaunchInput2D = GFProjectileLaunchInput2D.new()
	input_2d.set_target_none()
	assert_eq(input_2d.get_target_kind(), GFProjectileLaunchInput2D.TargetKind.NONE)
	assert_null(input_2d.get_target_node())
	input_2d.set_target_position(Vector2(4.0, 5.0))
	assert_eq(input_2d.get_target_kind(), GFProjectileLaunchInput2D.TargetKind.POSITION)
	assert_eq(input_2d.get_target_position(), Vector2(4.0, 5.0))
	assert_null(input_2d.get_target_node())
	input_2d.set_target_node(target_2d)
	assert_eq(input_2d.get_target_kind(), GFProjectileLaunchInput2D.TargetKind.NODE)
	assert_same(input_2d.get_target_node(), target_2d)

	var input_3d: GFProjectileLaunchInput3D = GFProjectileLaunchInput3D.new()
	input_3d.set_target_none()
	assert_eq(input_3d.get_target_kind(), GFProjectileLaunchInput3D.TargetKind.NONE)
	assert_null(input_3d.get_target_node())
	input_3d.set_target_position(Vector3(4.0, 5.0, 6.0))
	assert_eq(input_3d.get_target_kind(), GFProjectileLaunchInput3D.TargetKind.POSITION)
	assert_eq(input_3d.get_target_position(), Vector3(4.0, 5.0, 6.0))
	assert_null(input_3d.get_target_node())
	input_3d.set_target_node(target_3d)
	assert_eq(input_3d.get_target_kind(), GFProjectileLaunchInput3D.TargetKind.NODE)
	assert_same(input_3d.get_target_node(), target_3d)

	var source_nested: Dictionary = { "value": 7 }
	var source_metadata: Dictionary = { "nested": source_nested }
	input_2d.set_metadata(source_metadata)
	input_3d.set_metadata(source_metadata)
	var duplicate_2d: GFProjectileLaunchInput2D = input_2d.duplicate_input()
	var duplicate_3d: GFProjectileLaunchInput3D = input_3d.duplicate_input()
	source_nested["value"] = 99
	input_2d.set_metadata({ "nested": { "value": -1 } })
	input_3d.set_metadata({ "nested": { "value": -1 } })
	assert_eq(
		GFVariantData.get_option_int(
			GFVariantData.get_option_dictionary(duplicate_2d.get_metadata(), "nested"),
			"value"
		),
		7
	)
	assert_eq(
		GFVariantData.get_option_int(
			GFVariantData.get_option_dictionary(duplicate_3d.get_metadata(), "nested"),
			"value"
		),
		7
	)
	assert_same(duplicate_2d.get_target_node(), target_2d)
	assert_same(duplicate_3d.get_target_node(), target_3d)


func test_projectile_emitter_merges_default_and_call_inputs_before_candidate_snapshots() -> void:
	var parent: Node2D = Node2D.new()
	add_child_autofree(parent)
	var emitter: GFProjectileEmitter2D = GFProjectileEmitter2D.new()
	parent.add_child(emitter)
	emitter.projectile_definition = _make_projectile_definition_2d()
	var policy: RecordingEmissionPolicy = RecordingEmissionPolicy.new()
	emitter.emission_policy = policy
	var default_input: GFProjectileLaunchInput2D = GFProjectileLaunchInput2D.new()
	default_input.set_target_position(Vector2(1.0, 2.0))
	default_input.set_metadata({
		"shared": "default",
		"team": "player",
	})
	emitter.default_launch_input = default_input
	var call_input: GFProjectileLaunchInput2D = GFProjectileLaunchInput2D.new()
	call_input.set_target_position(Vector2(8.0, 9.0))
	call_input.set_metadata({
		"shared": "call",
		"skill": "fan",
	})
	var sessions: Array[GFProjectileSession] = []
	var snapshots: Array[GFProjectileLaunchInput2D] = []
	var on_emitted: Callable = func(
		_projectile_root: Node,
		session: GFProjectileSession,
		launch_input: GFProjectileLaunchInput2D
	) -> void:
		sessions.append(session)
		snapshots.append(launch_input)
		policy.event_log.append(&"emitted_active" if session.is_active() else &"emitted_inactive")
	var _emitted_connected: int = emitter.projectile_emitted.connect(on_emitted)

	var roots: Array[Node] = emitter.emit_projectiles(call_input, &"", 2)
	assert_eq(roots.size(), 2)
	assert_eq(snapshots.size(), 2)
	assert_eq(
		policy.event_log,
		[&"commit_hook", &"emitted_active", &"emitted_active"],
		"commit hook 必须在全部 session ACTIVE 后、emitted 发布前恰好执行一次。"
	)
	if snapshots.size() != 2:
		_finish_projectile_sessions(sessions)
		return
	for snapshot: GFProjectileLaunchInput2D in snapshots:
		assert_eq(snapshot.get_target_kind(), GFProjectileLaunchInput2D.TargetKind.POSITION)
		assert_eq(snapshot.get_target_position(), Vector2(8.0, 9.0))
		var metadata: Dictionary = snapshot.get_metadata()
		assert_eq(GFVariantData.get_option_string(metadata, "shared"), "call")
		assert_eq(GFVariantData.get_option_string(metadata, "team"), "player")
		assert_eq(GFVariantData.get_option_string(metadata, "skill"), "fan")
	assert_ne(snapshots[0], snapshots[1])
	call_input.set_target_none()
	call_input.set_metadata({ "shared": "mutated" })
	assert_eq(snapshots[0].get_target_kind(), GFProjectileLaunchInput2D.TargetKind.POSITION)
	assert_eq(
		GFVariantData.get_option_string(snapshots[0].get_metadata(), "shared"),
		"call"
	)
	_finish_projectile_sessions(sessions)


func test_projectile_emitter_defers_hostile_finish_until_started_and_emitted() -> void:
	var parent: Node2D = Node2D.new()
	add_child_autofree(parent)
	var emitter: GFProjectileEmitter2D = GFProjectileEmitter2D.new()
	parent.add_child(emitter)
	emitter.projectile_definition = _make_projectile_definition_2d()
	var policy: FinishingCommitPolicy = FinishingCommitPolicy.new()
	emitter.emission_policy = policy
	var on_child_entered: Callable = func(candidate: Node) -> void:
		var runtime_value: Node = candidate.get_node_or_null(
			NodePath("ProjectileRuntime")
		)
		if not runtime_value is GFProjectile2D:
			return
		var runtime: GFProjectile2D = runtime_value
		var on_started: Callable = func(_session: GFProjectileSession) -> void:
			policy.event_log.append(&"started")
		var _started_connected: int = runtime.projectile_started.connect(on_started)
	var _child_connected: int = parent.child_entered_tree.connect(on_child_entered)
	var on_emitted: Callable = func(
		_projectile_root: Node,
		_session: GFProjectileSession,
		_launch_input: GFProjectileLaunchInput2D
	) -> void:
		policy.event_log.append(&"emitted")
	var _emitted_connected: int = emitter.projectile_emitted.connect(on_emitted)

	var roots: Array[Node] = emitter.emit_projectiles(
		GFProjectileLaunchInput2D.new(),
		&"",
		1
	)
	assert_eq(roots.size(), 1)
	assert_eq(
		policy.event_log,
		[&"commit_hook", &"hook_finished", &"started", &"emitted", &"finished"],
		"publish hook 内同步 finish 也必须被 barrier 延后到 started+emitted 之后。"
	)
	if not roots.is_empty() and is_instance_valid(roots[0]):
		assert_true(roots[0].is_queued_for_deletion())
	await get_tree().process_frame
	await get_tree().process_frame


func test_projectile_emitter_prepare_release_aborts_single_flight_before_allocation() -> void:
	var parent: Node2D = Node2D.new()
	add_child_autofree(parent)
	var emitter: GFProjectileEmitter2D = GFProjectileEmitter2D.new()
	parent.add_child(emitter)
	emitter.projectile_definition = _make_projectile_definition_2d()
	emitter.use_object_pool = true
	var pool: RecordingObjectPool = RecordingObjectPool.new()
	emitter.object_pool_utility = pool
	var policy: ReleasingPreparePolicy = ReleasingPreparePolicy.new()
	policy.charge_capacity = 4.0
	policy.charge_cost_per_request = 1.0
	policy.charge_cost_per_projectile = 1.0
	policy.reset(0)
	emitter.emission_policy = policy
	var failure_reasons: Array[StringName] = []
	var on_failed: Callable = func(reason: StringName, _details: Dictionary) -> void:
		failure_reasons.append(reason)
	var _failed_connected: int = emitter.projectile_emit_failed.connect(on_failed)

	var roots: Array[Node] = emitter.emit_projectiles(
		GFProjectileLaunchInput2D.new(),
		&"",
		1
	)
	assert_true(roots.is_empty())
	assert_eq(policy.prepare_hook_count, 1, "同一 request 的 policy prepare 只允许进入一次。")
	assert_true(policy.reentrant_roots.is_empty(), "prepare callback 内重入必须 fail-close。")
	assert_eq(failure_reasons, [&"emitter_released"])
	assert_eq(pool.acquire_count, 0, "prepare callback 释放 emitter 后不得再分配候选。")
	assert_eq(pool.release_count, 0)
	assert_almost_eq(policy.get_available_charges(0), 4.0, 0.0001)
	assert_eq(
		GFVariantData.get_option_int(policy.get_debug_snapshot(0), "emission_count"),
		0,
		"任何 session ACTIVE 前的 release 必须保持零收费。"
	)
	if is_instance_valid(emitter):
		emitter.free()


func test_projectile_emitter_prewarm_holds_single_flight_and_release_generation_fence() -> void:
	var parent: Node2D = Node2D.new()
	add_child_autofree(parent)
	var emitter: GFProjectileEmitter2D = GFProjectileEmitter2D.new()
	parent.add_child(emitter)
	emitter.projectile_definition = _make_projectile_definition_2d()
	var pool: ReleasingPrewarmPool = ReleasingPrewarmPool.new()
	pool.emitter = emitter
	emitter.object_pool_utility = pool

	assert_false(emitter.prewarm_projectiles(2))
	assert_eq(pool.prewarm_count, 1)
	assert_true(pool.reentrant_roots.is_empty(), "prewarm callback 内发射重入必须 fail-close。")
	assert_eq(pool.acquire_count, 0)
	assert_eq(pool.release_count, 0)
	assert_null(emitter.get_parent())
	if is_instance_valid(emitter):
		emitter.free()


func test_projectile_emitter_deferred_commit_release_compensates_before_activation() -> void:
	var parent: Node2D = Node2D.new()
	add_child_autofree(parent)
	var emitter: GFProjectileEmitter2D = GFProjectileEmitter2D.new()
	parent.add_child(emitter)
	emitter.projectile_definition = _make_projectile_definition_2d()
	emitter.use_object_pool = true
	var pool: RecordingObjectPool = RecordingObjectPool.new()
	emitter.object_pool_utility = pool
	var policy: ReleasingDeferredCommitPolicy = ReleasingDeferredCommitPolicy.new()
	policy.charge_capacity = 4.0
	policy.charge_cost_per_request = 1.0
	policy.charge_cost_per_projectile = 1.0
	policy.reset(0)
	emitter.emission_policy = policy
	var emitted_count: Array[int] = [0]
	var failure_reasons: Array[StringName] = []
	var on_emitted: Callable = func(
		_projectile_root: Node,
		_session: GFProjectileSession,
		_launch_input: GFProjectileLaunchInput2D
	) -> void:
		emitted_count[0] += 1
	var _emitted_connected: int = emitter.projectile_emitted.connect(on_emitted)
	var on_failed: Callable = func(reason: StringName, _details: Dictionary) -> void:
		failure_reasons.append(reason)
	var _failed_connected: int = emitter.projectile_emit_failed.connect(on_failed)

	var roots: Array[Node] = emitter.emit_projectiles(
		GFProjectileLaunchInput2D.new(),
		&"",
		1
	)
	assert_true(roots.is_empty())
	assert_eq(policy.deferred_commit_count, 1)
	assert_eq(emitted_count[0], 0, "deferred commit 后 release 不得进入 consume/publication。")
	assert_eq(failure_reasons, [&"emitter_released"])
	assert_eq(pool.acquire_count, 1)
	await get_tree().process_frame
	await get_tree().process_frame
	assert_eq(pool.release_count, 1, "已分配但未 ACTIVE 的 lease 必须恰好一次退休。")
	assert_almost_eq(policy.get_available_charges(0), 4.0, 0.0001)
	assert_eq(
		GFVariantData.get_option_int(policy.get_debug_snapshot(0), "emission_count"),
		0,
		"COMMITTED_UNPUBLISHED receipt 必须精确补偿 charge/cooldown。"
	)
	if is_instance_valid(emitter):
		emitter.free()
	for candidate: Node in pool.acquired_nodes:
		if is_instance_valid(candidate):
			candidate.free()


func test_projectile_emitter_queued_owner_releases_preactive_pool_claim() -> void:
	for release_mode: ReleasingDeferredCommitPolicy.ReleaseMode in [
		ReleasingDeferredCommitPolicy.ReleaseMode.QUEUE_FREE,
	]:
		var parent: Node2D = Node2D.new()
		add_child_autofree(parent)
		var emitter: GFProjectileEmitter2D = GFProjectileEmitter2D.new()
		parent.add_child(emitter)
		emitter.projectile_definition = _make_projectile_definition_2d()
		emitter.use_object_pool = true
		var pool: RecordingObjectPool = RecordingObjectPool.new()
		pool.reuse_released_nodes = true
		emitter.object_pool_utility = pool
		var policy: ReleasingDeferredCommitPolicy = ReleasingDeferredCommitPolicy.new()
		policy.release_mode = release_mode
		policy.charge_capacity = 4.0
		policy.charge_cost_per_request = 1.0
		policy.charge_cost_per_projectile = 1.0
		policy.reset(0)
		emitter.emission_policy = policy

		var roots: Array[Node] = emitter.emit_projectiles(
			GFProjectileLaunchInput2D.new(),
			&"",
			1
		)
		assert_true(roots.is_empty())
		assert_eq(pool.acquire_count, 1)
		assert_almost_eq(
			policy.get_available_charges(0),
			4.0,
			0.0001,
			"ACTIVE 前 lost owner 必须补偿 deferred charge。"
		)
		assert_eq(
			GFVariantData.get_option_int(policy.get_debug_snapshot(0), "emission_count"),
			0,
			"ACTIVE 前 lost owner 不得保留 emission settlement。"
		)
		await get_tree().process_frame
		await get_tree().process_frame
		assert_eq(pool.release_count, 1, "lost owner 的 pool lease 必须恰好一次退休。")
		assert_eq(pool.acquired_nodes.size(), 1)
		if pool.acquired_nodes.is_empty():
			continue
		var candidate: Node = pool.acquired_nodes[0]
		assert_true(is_instance_valid(candidate))
		var runtime: GFProjectile2D = _runtime_2d_from(candidate)
		assert_not_null(runtime)
		if runtime != null:
			assert_false(
				runtime.has_launch_claim_for_framework(),
				"owner queued 后 reservation claim 不得随 pool root 复用。"
			)
		if is_instance_valid(candidate):
			candidate.free()


func test_projectile_emitter_remove_during_commit_publishes_before_exact_retirement() -> void:
	var parent: Node2D = Node2D.new()
	add_child_autofree(parent)
	var emitter: GFProjectileEmitter2D = GFProjectileEmitter2D.new()
	parent.add_child(emitter)
	emitter.projectile_definition = _make_projectile_definition_2d()
	emitter.use_object_pool = true
	var pool: RecordingObjectPool = RecordingObjectPool.new()
	emitter.object_pool_utility = pool
	var policy: ReleasingCommitPolicy = ReleasingCommitPolicy.new()
	policy.charge_capacity = 4.0
	policy.charge_cost_per_request = 1.0
	policy.charge_cost_per_projectile = 1.0
	policy.reset(0)
	emitter.emission_policy = policy
	var published_roots_were_attached: Array[bool] = []
	var emitted_sessions: Array[GFProjectileSession] = []
	var failure_reasons: Array[StringName] = []
	var on_child_entered: Callable = func(candidate: Node) -> void:
		var runtime_value: Node = candidate.get_node_or_null(
			NodePath("ProjectileRuntime")
		)
		if runtime_value is GFProjectile2D:
			var runtime: GFProjectile2D = runtime_value
			var on_started: Callable = func(_session: GFProjectileSession) -> void:
				policy.event_log.append(&"started")
			var _started_connected: int = runtime.projectile_started.connect(on_started)
	var _child_connected: int = parent.child_entered_tree.connect(on_child_entered)
	var on_emitted: Callable = func(
		projectile_root: Node,
		session: GFProjectileSession,
		_launch_input: GFProjectileLaunchInput2D
	) -> void:
		policy.event_log.append(&"emitted")
		published_roots_were_attached.append(
			is_instance_valid(projectile_root) and projectile_root.get_parent() == parent
		)
		emitted_sessions.append(session)
	var _emitted_connected: int = emitter.projectile_emitted.connect(on_emitted)
	var on_failed: Callable = func(reason: StringName, _details: Dictionary) -> void:
		policy.event_log.append(&"failure")
		failure_reasons.append(reason)
	var _failed_connected: int = emitter.projectile_emit_failed.connect(on_failed)

	var roots: Array[Node] = emitter.emit_projectiles(
		GFProjectileLaunchInput2D.new(),
		&"",
		1
	)
	assert_true(roots.is_empty(), "commit hook 释放 emitter 后调用方不得接收已退休 root。")
	assert_eq(
		policy.event_log,
		[&"commit_hook", &"release_requested", &"started", &"emitted", &"finished", &"failure"],
		"已 ACTIVE 的批次必须完整发布 started/emitted 后才发布 EMITTER_RELEASED terminal。"
	)
	assert_eq(published_roots_were_attached, [true])
	assert_eq(failure_reasons, [&"emitter_released"])
	assert_eq(policy.observed_sessions.size(), 1)
	assert_eq(emitted_sessions.size(), 1)
	if not policy.observed_sessions.is_empty():
		assert_true(policy.observed_sessions[0].is_finished())
		assert_eq(
			policy.observed_sessions[0].get_end_reason(),
			GFProjectileSession.EndReason.EMITTER_RELEASED
		)
	assert_eq(pool.acquire_count, 1)
	assert_eq(
		pool.release_count,
		0,
		"remove_child 回调栈内必须先保留 terminal claim，等待树安全点归还 lease。"
	)
	assert_almost_eq(policy.get_available_charges(0), 2.0, 0.0001)
	assert_eq(
		GFVariantData.get_option_int(policy.get_debug_snapshot(0), "emission_count"),
		1,
		"receipt 已发布且 session 已 ACTIVE 后不得补偿 charge/cooldown。"
	)
	await get_tree().process_frame
	await get_tree().process_frame
	assert_eq(pool.release_count, 1, "remove_child publication 必须恰好一次归还 pool lease。")
	policy.observed_sessions.clear()
	if is_instance_valid(emitter):
		emitter.free()
	for candidate: Node in pool.acquired_nodes:
		if is_instance_valid(candidate):
			candidate.free()


func test_projectile_emitter_queue_free_during_commit_publishes_3d_before_retirement() -> void:
	var parent: Node3D = Node3D.new()
	add_child_autofree(parent)
	var emitter: GFProjectileEmitter3D = GFProjectileEmitter3D.new()
	parent.add_child(emitter)
	emitter.projectile_definition = _make_projectile_definition_3d()
	emitter.use_object_pool = true
	var pool: RecordingObjectPool = RecordingObjectPool.new()
	emitter.object_pool_utility = pool
	var policy: ReleasingCommitPolicy = ReleasingCommitPolicy.new()
	policy.release_mode = ReleasingCommitPolicy.ReleaseMode.QUEUE_FREE
	policy.charge_capacity = 4.0
	policy.charge_cost_per_request = 1.0
	policy.charge_cost_per_projectile = 1.0
	policy.reset(0)
	emitter.emission_policy = policy
	var published_roots_were_attached: Array[bool] = []
	var failure_reasons: Array[StringName] = []
	var on_child_entered: Callable = func(candidate: Node) -> void:
		var runtime_value: Node = candidate.get_node_or_null(
			NodePath("ProjectileRuntime")
		)
		if runtime_value is GFProjectile3D:
			var runtime: GFProjectile3D = runtime_value
			var on_started: Callable = func(_session: GFProjectileSession) -> void:
				policy.event_log.append(&"started")
			var _started_connected: int = runtime.projectile_started.connect(on_started)
	var _child_connected: int = parent.child_entered_tree.connect(on_child_entered)
	var on_emitted: Callable = func(
		projectile_root: Node,
		_session: GFProjectileSession,
		_launch_input: GFProjectileLaunchInput3D
	) -> void:
		policy.event_log.append(&"emitted")
		published_roots_were_attached.append(
			is_instance_valid(projectile_root) and projectile_root.get_parent() == parent
		)
	var _emitted_connected: int = emitter.projectile_emitted.connect(on_emitted)
	var on_failed: Callable = func(reason: StringName, _details: Dictionary) -> void:
		policy.event_log.append(&"failure")
		failure_reasons.append(reason)
	var _failed_connected: int = emitter.projectile_emit_failed.connect(on_failed)

	var roots: Array[Node] = emitter.emit_projectiles(
		GFProjectileLaunchInput3D.new(),
		&"",
		1
	)
	assert_true(roots.is_empty(), "queue_free publication 不得返回待释放 root。")
	assert_eq(
		policy.event_log,
		[&"commit_hook", &"release_requested", &"started", &"emitted", &"finished", &"failure"]
	)
	assert_eq(published_roots_were_attached, [true])
	assert_eq(failure_reasons, [&"emitter_released"])
	assert_eq(policy.observed_sessions.size(), 1)
	if not policy.observed_sessions.is_empty():
		assert_true(policy.observed_sessions[0].is_finished())
		assert_eq(
			policy.observed_sessions[0].get_end_reason(),
			GFProjectileSession.EndReason.EMITTER_RELEASED
		)
	policy.observed_sessions.clear()
	assert_eq(pool.acquire_count, 1)
	assert_eq(
		pool.release_count,
		0,
		"queue_free 回调栈内必须先保留 terminal claim，等待树安全点归还 lease。"
	)
	assert_almost_eq(policy.get_available_charges(0), 2.0, 0.0001)
	assert_eq(
		GFVariantData.get_option_int(policy.get_debug_snapshot(0), "emission_count"),
		1
	)
	await get_tree().process_frame
	await get_tree().process_frame
	assert_false(is_instance_valid(emitter))
	assert_eq(pool.release_count, 1, "延迟 _exit_tree 不得重复归还同一 lease。")
	for candidate: Node in pool.acquired_nodes:
		if is_instance_valid(candidate):
			candidate.free()


func test_projectile_emitter_deferred_free_in_commit_hook_publishes_full_batch_and_keeps_charge() -> void:
	var parent: Node2D = Node2D.new()
	add_child_autofree(parent)
	var emitter: GFProjectileEmitter2D = GFProjectileEmitter2D.new()
	parent.add_child(emitter)
	emitter.projectile_definition = _make_projectile_definition_2d()
	emitter.use_object_pool = true
	var pool: RecordingObjectPool = RecordingObjectPool.new()
	emitter.object_pool_utility = pool
	var policy: ReleasingCommitPolicy = ReleasingCommitPolicy.new()
	policy.release_mode = ReleasingCommitPolicy.ReleaseMode.DEFERRED_FREE
	policy.charge_capacity = 4.0
	policy.charge_cost_per_request = 1.0
	policy.charge_cost_per_projectile = 1.0
	policy.reset(0)
	emitter.emission_policy = policy
	var started_count: Array[int] = [0]
	var emitted_count: Array[int] = [0]
	var on_child_entered: Callable = func(candidate: Node) -> void:
		var runtime_value: Node = candidate.get_node_or_null(NodePath("ProjectileRuntime"))
		if runtime_value is GFProjectile2D:
			var runtime: GFProjectile2D = runtime_value
			var on_started: Callable = func(_session: GFProjectileSession) -> void:
				started_count[0] += 1
			var _started_connected: int = runtime.projectile_started.connect(on_started)
	var _child_connected: int = parent.child_entered_tree.connect(on_child_entered)
	var on_emitted: Callable = func(
		_projectile_root: Node,
		_session: GFProjectileSession,
		_launch_input: GFProjectileLaunchInput2D
	) -> void:
		emitted_count[0] += 1
	var _emitted_connected: int = emitter.projectile_emitted.connect(on_emitted)

	var roots: Array[Node] = emitter.emit_projectiles(
		GFProjectileLaunchInput2D.new(),
		&"",
		1
	)
	assert_eq(roots.size(), 1)
	assert_true(is_instance_valid(emitter))
	assert_eq(started_count[0], 1)
	assert_eq(emitted_count[0], 1)
	assert_eq(policy.observed_sessions.size(), 1)
	if not policy.observed_sessions.is_empty():
		assert_true(policy.observed_sessions[0].is_active())
	assert_almost_eq(policy.get_available_charges(0), 2.0, 0.0001)
	assert_eq(
		GFVariantData.get_option_int(policy.get_debug_snapshot(0), "emission_count"),
		1,
		"ACTIVATED receipt 的 charge/cooldown 在 deferred free 后不得补偿。"
	)
	await get_tree().process_frame
	await get_tree().process_frame
	assert_false(is_instance_valid(emitter))
	if not policy.observed_sessions.is_empty():
		assert_true(policy.observed_sessions[0].is_finished())
		assert_eq(
			policy.observed_sessions[0].get_end_reason(),
			GFProjectileSession.EndReason.EMITTER_RELEASED
		)
	assert_eq(pool.release_count, 1)
	policy.observed_sessions.clear()
	for candidate: Node in pool.acquired_nodes:
		if is_instance_valid(candidate):
			candidate.free()


func test_projectile_emitter_deferred_free_in_started_keeps_full_signal_order() -> void:
	var parent: Node3D = Node3D.new()
	add_child_autofree(parent)
	var emitter: GFProjectileEmitter3D = GFProjectileEmitter3D.new()
	parent.add_child(emitter)
	emitter.projectile_definition = _make_projectile_definition_3d()
	var candidates: Array[Node] = []
	var sessions: Array[GFProjectileSession] = []
	var events: Array[StringName] = []
	var emitted_count: Array[int] = [0]
	var on_child_entered: Callable = func(candidate: Node) -> void:
		var runtime_value: Node = candidate.get_node_or_null(NodePath("ProjectileRuntime"))
		if not runtime_value is GFProjectile3D:
			return
		candidates.append(candidate)
		var runtime: GFProjectile3D = runtime_value
		var on_started: Callable = func(session: GFProjectileSession) -> void:
			events.append(&"started")
			sessions.append(session)
			var on_finished: Callable = func(
				_finished_session: GFProjectileSession,
				_reason: int
			) -> void:
				events.append(&"finished")
			var _finished_connected: int = session.finished.connect(on_finished)
			emitter.call_deferred(&"free")
		var _started_connected: int = runtime.projectile_started.connect(on_started)
	var _child_connected: int = parent.child_entered_tree.connect(on_child_entered)
	var on_emitted: Callable = func(
		_projectile_root: Node,
		_session: GFProjectileSession,
		_launch_input: GFProjectileLaunchInput3D
	) -> void:
		events.append(&"emitted")
		emitted_count[0] += 1
	var _emitted_connected: int = emitter.projectile_emitted.connect(on_emitted)

	var roots: Array[Node] = emitter.emit_projectiles(
		GFProjectileLaunchInput3D.new(),
		&"",
		1
	)
	assert_eq(roots.size(), 1)
	assert_true(is_instance_valid(emitter))
	assert_eq(events, [&"started", &"emitted"])
	assert_eq(emitted_count[0], 1)
	assert_eq(sessions.size(), 1)
	await get_tree().process_frame
	await get_tree().process_frame
	assert_false(is_instance_valid(emitter))
	assert_eq(events, [&"started", &"emitted", &"finished"])
	if not sessions.is_empty():
		assert_eq(sessions[0].get_end_reason(), GFProjectileSession.EndReason.EMITTER_RELEASED)
	for candidate: Node in candidates:
		assert_false(is_instance_valid(candidate), "fresh root 必须在独立 retirement handoff 后释放。")


func test_projectile_emitter_deferred_free_in_emitted_completes_fresh_2d_batch() -> void:
	var parent: Node2D = Node2D.new()
	add_child_autofree(parent)
	var emitter: GFProjectileEmitter2D = GFProjectileEmitter2D.new()
	parent.add_child(emitter)
	emitter.projectile_definition = _make_projectile_definition_2d()
	var candidates: Array[Node] = []
	var sessions: Array[GFProjectileSession] = []
	var started_count: Array[int] = [0]
	var emitted_count: Array[int] = [0]
	var on_child_entered: Callable = func(candidate: Node) -> void:
		var runtime_value: Node = candidate.get_node_or_null(NodePath("ProjectileRuntime"))
		if not runtime_value is GFProjectile2D:
			return
		candidates.append(candidate)
		var runtime: GFProjectile2D = runtime_value
		var on_started: Callable = func(_session: GFProjectileSession) -> void:
			started_count[0] += 1
		var _started_connected: int = runtime.projectile_started.connect(on_started)
	var _child_connected: int = parent.child_entered_tree.connect(on_child_entered)
	var on_emitted: Callable = func(
		_projectile_root: Node,
		_session: GFProjectileSession,
		_launch_input: GFProjectileLaunchInput2D
	) -> void:
		emitted_count[0] += 1
		for candidate: Node in candidates:
			var runtime: GFProjectile2D = _runtime_2d_from(candidate)
			if runtime == null:
				continue
			var active_session: GFProjectileSession = runtime.get_active_session()
			if active_session != null and not sessions.has(active_session):
				sessions.append(active_session)
		if emitted_count[0] == 1:
			emitter.call_deferred(&"free")
	var _emitted_connected: int = emitter.projectile_emitted.connect(on_emitted)

	var roots: Array[Node] = emitter.emit_projectiles(
		GFProjectileLaunchInput2D.new(),
		&"",
		2
	)
	assert_eq(roots.size(), 2)
	assert_true(is_instance_valid(emitter))
	assert_eq(started_count[0], 2)
	assert_eq(emitted_count[0], 2)
	assert_eq(sessions.size(), 2)
	await get_tree().process_frame
	await get_tree().process_frame
	assert_false(is_instance_valid(emitter))
	for session: GFProjectileSession in sessions:
		assert_true(session.is_finished())
		assert_eq(session.get_end_reason(), GFProjectileSession.EndReason.EMITTER_RELEASED)
	for candidate: Node in candidates:
		assert_false(is_instance_valid(candidate))


func test_projectile_emitter_deferred_free_in_emitted_releases_3d_pool_batch_once() -> void:
	var parent: Node3D = Node3D.new()
	add_child_autofree(parent)
	var emitter: GFProjectileEmitter3D = GFProjectileEmitter3D.new()
	parent.add_child(emitter)
	emitter.projectile_definition = _make_projectile_definition_3d()
	emitter.use_object_pool = true
	var pool: RecordingObjectPool = RecordingObjectPool.new()
	emitter.object_pool_utility = pool
	var sessions: Array[GFProjectileSession] = []
	var started_count: Array[int] = [0]
	var emitted_count: Array[int] = [0]
	var on_child_entered: Callable = func(candidate: Node) -> void:
		var runtime_value: Node = candidate.get_node_or_null(NodePath("ProjectileRuntime"))
		if runtime_value is GFProjectile3D:
			var runtime: GFProjectile3D = runtime_value
			var on_started: Callable = func(_session: GFProjectileSession) -> void:
				started_count[0] += 1
			var _started_connected: int = runtime.projectile_started.connect(on_started)
	var _child_connected: int = parent.child_entered_tree.connect(on_child_entered)
	var on_emitted: Callable = func(
		_projectile_root: Node,
		_session: GFProjectileSession,
		_launch_input: GFProjectileLaunchInput3D
	) -> void:
		emitted_count[0] += 1
		for candidate: Node in pool.acquired_nodes:
			var runtime: GFProjectile3D = _runtime_3d_from(candidate)
			if runtime == null:
				continue
			var active_session: GFProjectileSession = runtime.get_active_session()
			if active_session != null and not sessions.has(active_session):
				sessions.append(active_session)
		if emitted_count[0] == 1:
			emitter.call_deferred(&"free")
	var _emitted_connected: int = emitter.projectile_emitted.connect(on_emitted)

	var roots: Array[Node] = emitter.emit_projectiles(
		GFProjectileLaunchInput3D.new(),
		&"",
		2
	)
	assert_eq(roots.size(), 2)
	assert_true(is_instance_valid(emitter))
	assert_eq(started_count[0], 2)
	assert_eq(emitted_count[0], 2)
	assert_eq(sessions.size(), 2)
	await get_tree().process_frame
	await get_tree().process_frame
	assert_false(is_instance_valid(emitter))
	for session: GFProjectileSession in sessions:
		assert_true(session.is_finished())
		assert_eq(session.get_end_reason(), GFProjectileSession.EndReason.EMITTER_RELEASED)
	assert_eq(pool.acquire_count, 2)
	assert_eq(pool.release_count, 2)
	assert_eq(pool.released_nodes.size(), 2)
	for candidate: Node in pool.acquired_nodes:
		if is_instance_valid(candidate):
			candidate.free()


func test_projectile_catalog_maps_ids_to_typed_definitions() -> void:
	var catalog: GFProjectileCatalog = GFProjectileCatalog.new()
	var first_definition: GFProjectileDefinition2D = _make_projectile_definition_2d()
	var duplicate_definition: GFProjectileDefinition2D = _make_projectile_definition_2d()
	var replacement_definition: GFProjectileDefinition2D = _make_projectile_definition_2d()
	var first_entry: GFProjectileCatalogEntry = GFProjectileCatalogEntry.new()
	first_entry.projectile_id = &"arrow"
	first_entry.definition = first_definition
	var duplicate_entry: GFProjectileCatalogEntry = GFProjectileCatalogEntry.new()
	duplicate_entry.projectile_id = &"arrow"
	duplicate_entry.definition = duplicate_definition
	catalog.entries = [first_entry, duplicate_entry]

	assert_same(catalog.get_definition(&"arrow"), first_definition)
	assert_eq(catalog.get_projectile_ids(), PackedStringArray(["arrow"]))
	catalog.set_definition(&"arrow", replacement_definition)
	assert_same(catalog.get_definition(&"arrow"), replacement_definition)
	assert_eq(catalog.entries.size(), 1)
	catalog.entries.append(duplicate_entry)
	assert_true(catalog.remove_definition(&"arrow"))
	assert_false(catalog.has_definition(&"arrow"))
	assert_true(catalog.entries.is_empty())


func test_projectile_catalog_uses_first_valid_duplicate_consistently() -> void:
	var catalog: GFProjectileCatalog = GFProjectileCatalog.new()
	var invalid_entry: GFProjectileCatalogEntry = GFProjectileCatalogEntry.new()
	invalid_entry.projectile_id = &"arrow"
	var first_valid_entry: GFProjectileCatalogEntry = GFProjectileCatalogEntry.new()
	first_valid_entry.projectile_id = &"arrow"
	first_valid_entry.definition = _make_projectile_definition_2d()
	var later_valid_entry: GFProjectileCatalogEntry = GFProjectileCatalogEntry.new()
	later_valid_entry.projectile_id = &"arrow"
	later_valid_entry.definition = _make_projectile_definition_3d()
	catalog.entries = [invalid_entry, first_valid_entry, later_valid_entry]

	assert_same(catalog.get_definition(&"arrow"), first_valid_entry.definition)
	assert_true(catalog.has_definition(&"arrow"))
	assert_eq(catalog.get_projectile_ids(), PackedStringArray(["arrow"]))

	var parent: Node2D = Node2D.new()
	add_child_autofree(parent)
	var emitter: GFProjectileEmitter2D = GFProjectileEmitter2D.new()
	parent.add_child(emitter)
	emitter.projectile_catalog = catalog
	emitter.default_projectile_id = &"arrow"
	var sessions: Array[GFProjectileSession] = []
	var on_emitted: Callable = func(
		_projectile_root: Node,
		session: GFProjectileSession,
		_launch_input: GFProjectileLaunchInput2D
	) -> void:
		sessions.append(session)
	var _emitted_connected: int = emitter.projectile_emitted.connect(on_emitted)
	var emitted_root: Node = emitter.emit_projectile()
	assert_not_null(emitted_root, "Emitter 必须跳过同 ID 的前置无效条目。")
	assert_eq(sessions.size(), 1)
	_finish_projectile_sessions(sessions)

	var replacement: GFProjectileDefinition2D = _make_projectile_definition_2d()
	catalog.set_definition(&"arrow", replacement)
	assert_same(catalog.get_definition(&"arrow"), replacement)
	assert_eq(catalog.entries.size(), 1)
	assert_same(
		catalog.entries[0],
		first_valid_entry,
		"set 必须替换首个有效条目，而不是复活前置无效条目。"
	)
	invalid_entry.definition = null
	first_valid_entry.definition = replacement
	catalog.entries = [invalid_entry, first_valid_entry, later_valid_entry]
	assert_eq(catalog.prune_invalid_entries(), 2)
	assert_eq(catalog.entries.size(), 1)
	assert_same(catalog.entries[0], first_valid_entry)
	assert_same(catalog.get_definition(&"arrow"), replacement)
	catalog.entries.append(invalid_entry)
	catalog.entries.append(later_valid_entry)
	assert_true(catalog.remove_definition(&"arrow"))
	assert_false(catalog.remove_definition(&"arrow"), "重复 remove 必须保持 first-wins 终态。")
	assert_false(catalog.has_definition(&"arrow"))
	assert_true(catalog.get_projectile_ids().is_empty())
	assert_true(catalog.entries.is_empty())


func test_projectile_emitter_resolves_typed_definition_from_catalog() -> void:
	var parent: Node2D = Node2D.new()
	add_child_autofree(parent)
	var emitter: GFProjectileEmitter2D = GFProjectileEmitter2D.new()
	parent.add_child(emitter)
	var definition: GFProjectileDefinition2D = _make_projectile_definition_2d()
	var catalog: GFProjectileCatalog = GFProjectileCatalog.new()
	catalog.set_definition(&"arrow", definition)
	emitter.projectile_catalog = catalog
	emitter.default_projectile_id = &"arrow"
	var sessions: Array[GFProjectileSession] = []
	var on_emitted: Callable = func(
		_projectile_root: Node,
		session: GFProjectileSession,
		_launch_input: GFProjectileLaunchInput2D
	) -> void:
		sessions.append(session)
	var _emitted_connected: int = emitter.projectile_emitted.connect(on_emitted)

	var root: Node = emitter.emit_projectile()
	assert_not_null(root)
	assert_true(root is Node2D, "Emitter 应返回目录 definition 分配的完整 instance root。")
	assert_eq(sessions.size(), 1)
	if root != null:
		assert_not_null(root.get_node_or_null(NodePath("ProjectileRuntime")))
	_finish_projectile_sessions(sessions)


func test_projectile_emit_failure_sanitizes_hostile_policy_details_symmetrically() -> void:
	var hostile_policy: HostileFailureEmissionPolicy = HostileFailureEmissionPolicy.new()
	var hostile_object: GFProjectileMotionState = GFProjectileMotionState.new()
	var hostile_ref: WeakRef = weakref(hostile_object)
	hostile_policy.hostile_object = hostile_object
	var failure_reasons: Array[StringName] = []
	var failure_details: Array[Dictionary] = []
	var on_failed: Callable = func(reason: StringName, details: Dictionary) -> void:
		failure_reasons.append(reason)
		failure_details.append(details)

	var parent_2d: Node2D = Node2D.new()
	add_child_autofree(parent_2d)
	var emitter_2d: GFProjectileEmitter2D = GFProjectileEmitter2D.new()
	parent_2d.add_child(emitter_2d)
	emitter_2d.projectile_definition = _make_projectile_definition_2d()
	emitter_2d.emission_policy = hostile_policy
	var _failed_2d_connected: int = emitter_2d.projectile_emit_failed.connect(on_failed)
	assert_true(emitter_2d.emit_projectiles().is_empty())

	var parent_3d: Node3D = Node3D.new()
	add_child_autofree(parent_3d)
	var emitter_3d: GFProjectileEmitter3D = GFProjectileEmitter3D.new()
	parent_3d.add_child(emitter_3d)
	emitter_3d.projectile_definition = _make_projectile_definition_3d()
	emitter_3d.emission_policy = hostile_policy
	var _failed_3d_connected: int = emitter_3d.projectile_emit_failed.connect(on_failed)
	assert_true(emitter_3d.emit_projectiles().is_empty())

	assert_eq(failure_reasons.size(), 2)
	assert_eq(failure_details.size(), 2)
	for reason: StringName in failure_reasons:
		assert_eq(String(reason), "r".repeat(128))
	for details: Dictionary in failure_details:
		_assert_hostile_failure_details(details)
	hostile_policy.hostile_object = null
	hostile_object = null
	assert_eq(
		typeof(hostile_ref.get_ref()),
		TYPE_NIL,
		"信号详情不得通过 hostile Object 值延长 RefCounted 生命周期。"
	)


func test_projectile_emission_policy_caps_before_typed_2d_pattern_generation() -> void:
	var parent: Node2D = Node2D.new()
	add_child_autofree(parent)
	var emitter: GFProjectileEmitter2D = GFProjectileEmitter2D.new()
	parent.add_child(emitter)
	emitter.projectile_definition = _make_projectile_definition_2d()
	var pattern: RecordingSpawnPattern2D = RecordingSpawnPattern2D.new()
	emitter.spawn_pattern = pattern
	var policy: GFProjectileEmissionPolicy = GFProjectileEmissionPolicy.new()
	policy.max_projectiles_per_request = 2
	emitter.emission_policy = policy
	var sessions: Array[GFProjectileSession] = []
	var on_emitted: Callable = func(
		_projectile_root: Node,
		session: GFProjectileSession,
		_launch_input: GFProjectileLaunchInput2D
	) -> void:
		sessions.append(session)
	var _emitted_connected: int = emitter.projectile_emitted.connect(on_emitted)

	var roots: Array[Node] = emitter.emit_projectiles(
		GFProjectileLaunchInput2D.new(),
		&"",
		1_000_000
	)
	assert_eq(pattern.received_count, 2, "策略预算必须在模式分配 transform 前生效。")
	assert_eq(roots.size(), 2)
	assert_eq(sessions.size(), 2)
	for index: int in range(roots.size()):
		var root: Node = roots[index]
		assert_true(root is Node2D)
		if root is Node2D:
			var root_2d: Node2D = root
			assert_eq(root_2d.global_position, Vector2(float(index) * 10.0, 0.0))
	assert_eq(
		GFVariantData.get_option_int(policy.get_debug_snapshot(), "emission_count"),
		1
	)
	_finish_projectile_sessions(sessions)


func test_projectile_emitter_3d_hard_limit_caps_before_typed_pattern_generation() -> void:
	var parent: Node3D = Node3D.new()
	add_child_autofree(parent)
	var emitter: GFProjectileEmitter3D = GFProjectileEmitter3D.new()
	parent.add_child(emitter)
	emitter.projectile_definition = _make_projectile_definition_3d()
	emitter.hard_projectile_limit_per_request = 3
	var pattern: RecordingSpawnPattern3D = RecordingSpawnPattern3D.new()
	emitter.spawn_pattern = pattern
	var sessions: Array[GFProjectileSession] = []
	var on_emitted: Callable = func(
		_projectile_root: Node,
		session: GFProjectileSession,
		_launch_input: GFProjectileLaunchInput3D
	) -> void:
		sessions.append(session)
	var _emitted_connected: int = emitter.projectile_emitted.connect(on_emitted)

	var roots: Array[Node] = emitter.emit_projectiles(
		GFProjectileLaunchInput3D.new(),
		&"",
		1_000_000
	)
	assert_eq(pattern.received_count, 3, "3D 模式也必须服从分配前硬预算。")
	assert_eq(roots.size(), 3)
	assert_eq(sessions.size(), 3)
	for index: int in range(roots.size()):
		var root: Node = roots[index]
		assert_true(root is Node3D)
		if root is Node3D:
			var root_3d: Node3D = root
			assert_eq(
				root_3d.global_position,
				Vector3(0.0, 0.0, float(index) * -10.0)
			)
	_finish_projectile_sessions(sessions)


func test_projectile_emitter_blocks_cooldown_after_active_commit() -> void:
	var parent: Node2D = Node2D.new()
	add_child_autofree(parent)
	var emitter: GFProjectileEmitter2D = GFProjectileEmitter2D.new()
	parent.add_child(emitter)
	emitter.projectile_definition = _make_projectile_definition_2d()
	var policy: GFProjectileEmissionPolicy = GFProjectileEmissionPolicy.new()
	policy.cooldown_seconds = 60.0
	emitter.emission_policy = policy
	var sessions: Array[GFProjectileSession] = []
	var on_emitted: Callable = func(
		_projectile_root: Node,
		session: GFProjectileSession,
		_launch_input: GFProjectileLaunchInput2D
	) -> void:
		sessions.append(session)
	var _emitted_connected: int = emitter.projectile_emitted.connect(on_emitted)
	watch_signals(emitter)

	var first_root: Node = emitter.emit_projectile()
	var blocked_roots: Array[Node] = emitter.emit_projectiles()
	assert_not_null(first_root)
	assert_true(blocked_roots.is_empty())
	assert_signal_emitted(emitter, "projectile_emit_failed")
	assert_eq(sessions.size(), 1)
	_finish_projectile_sessions(sessions)


func test_projectile_line_spawn_pattern_uses_typed_launch_input() -> void:
	var emitter: Node2D = Node2D.new()
	add_child_autofree(emitter)
	var pattern: GFProjectileLineSpawnPattern2D = GFProjectileLineSpawnPattern2D.new()
	pattern.local_start = Vector2(-10.0, 0.0)
	pattern.local_end = Vector2(10.0, 0.0)
	pattern.point_count = 3
	var transforms: Array[Transform2D] = pattern.get_spawn_transforms(
		emitter,
		GFProjectileLaunchInput2D.new()
	)
	assert_eq(transforms.size(), 3)
	assert_eq(transforms[0].origin, Vector2(-10.0, 0.0))
	assert_eq(transforms[1].origin, Vector2.ZERO)
	assert_eq(transforms[2].origin, Vector2(10.0, 0.0))


func test_projectile_emitter_reports_missing_definition() -> void:
	var emitter: GFProjectileEmitter2D = GFProjectileEmitter2D.new()
	add_child_autofree(emitter)
	watch_signals(emitter)
	var roots: Array[Node] = emitter.emit_projectiles()
	assert_true(roots.is_empty())
	assert_signal_emitted(emitter, "projectile_emit_failed")


func test_projectile_launch_reservation_is_owner_bound_and_single_consume() -> void:
	var root: Node2D = _make_bound_projectile_root_2d()
	add_child_autofree(root)
	var definition: GFProjectileDefinition2D = _make_projectile_definition_2d()
	var binding: GFProjectileBinding2D = definition.bind_instance(root)
	assert_true(binding.is_valid())
	if not binding.is_valid():
		return
	var runtime: GFProjectile2D = _runtime_2d_from(root)
	var input: GFProjectileLaunchInput2D = GFProjectileLaunchInput2D.new()
	var retirement_owner: Node = Node.new()
	var foreign_owner: Node = Node.new()
	add_child_autofree(retirement_owner)
	add_child_autofree(foreign_owner)

	var reservation: GFProjectileLaunchReservation = runtime.reserve_launch_for_framework(
		binding,
		input,
		retirement_owner
	)
	assert_not_null(reservation)
	assert_eq(reservation.get_state_for_framework(), GFProjectileLaunchReservation.State.RESERVED)
	assert_eq(reservation.arm_for_framework(foreign_owner), ERR_UNAUTHORIZED)
	assert_eq(reservation.get_state_for_framework(), GFProjectileLaunchReservation.State.RESERVED)
	assert_eq(reservation.arm_for_framework(retirement_owner), OK)
	assert_eq(reservation.get_state_for_framework(), GFProjectileLaunchReservation.State.ARMED)
	assert_null(reservation.consume_for_framework(foreign_owner))
	assert_eq(reservation.get_state_for_framework(), GFProjectileLaunchReservation.State.ARMED)

	var session: GFProjectileSession = reservation.consume_for_framework(retirement_owner)
	assert_not_null(session)
	assert_true(session.is_active())
	assert_eq(session.get_status(), GFProjectileSession.Status.ACTIVE)
	assert_eq(session.get_dimension(), GFProjectileSession.Dimension.TWO_D)
	assert_gt(session.get_generation(), 0)
	assert_same(session.get_instance_root(), root)
	assert_same(session.get_runtime(), runtime)
	assert_eq(reservation.get_state_for_framework(), GFProjectileLaunchReservation.State.CONSUMED)
	assert_null(reservation.consume_for_framework(retirement_owner), "同一 reservation 只能消费一次。")
	assert_false(
		reservation.abort_for_framework(retirement_owner, &"too_late"),
		"CONSUMED reservation 不得回滚 ACTIVE session。"
	)
	assert_true(session.finish(GFProjectileSession.EndReason.CALLER_FINISHED))
	assert_false(session.finish(GFProjectileSession.EndReason.INTERNAL_FAILURE))
	assert_eq(session.get_status(), GFProjectileSession.Status.FINISHED)
	assert_eq(session.get_end_reason(), GFProjectileSession.EndReason.CALLER_FINISHED)
	assert_true(is_instance_valid(root), "Runtime/session 不得自行释放完整 instance root。")


func test_projectile_launch_reservation_runs_user_preflight_before_consume() -> void:
	var root: Node2D = _make_bound_projectile_root_2d()
	add_child_autofree(root)
	var definition: GFProjectileDefinition2D = _make_projectile_definition_2d()
	var adapter: RecordingPreflightAdapter2D = RecordingPreflightAdapter2D.new()
	var motion: RecordingPreflightMotion = RecordingPreflightMotion.new()
	motion.speed = 1.0
	definition.body_adapter = adapter
	definition.motion = motion
	var binding: GFProjectileBinding2D = definition.bind_instance(root)
	assert_true(binding.is_valid())
	if not binding.is_valid():
		return
	var runtime: GFProjectile2D = _runtime_2d_from(root)
	var retirement_owner: Node = Node.new()
	add_child_autofree(retirement_owner)
	var reservation: GFProjectileLaunchReservation = runtime.reserve_launch_for_framework(
		binding,
		GFProjectileLaunchInput2D.new(),
		retirement_owner
	)
	assert_not_null(reservation)
	assert_eq(adapter.capture_count, 1)
	assert_eq(motion.create_state_count, 1)
	if reservation == null:
		return
	assert_eq(reservation.arm_for_framework(retirement_owner), OK)
	var capture_count_before_consume: int = adapter.capture_count
	var state_count_before_consume: int = motion.create_state_count
	var session: GFProjectileSession = reservation.consume_for_framework(
		retirement_owner
	)
	assert_not_null(session)
	assert_true(session != null and session.is_active())
	assert_eq(
		adapter.capture_count,
		capture_count_before_consume,
		"consume 的原子区不得重新进入可重写 adapter callback。"
	)
	assert_eq(
		motion.create_state_count,
		state_count_before_consume,
		"consume 的原子区不得重新进入可重写 motion callback。"
	)
	if session != null:
		var _finished: bool = session.finish(
			GFProjectileSession.EndReason.CALLER_FINISHED
		)


func test_projectile_launch_reservation_aborts_once_without_activating_runtime() -> void:
	var root: Node2D = _make_bound_projectile_root_2d()
	add_child_autofree(root)
	var definition: GFProjectileDefinition2D = _make_projectile_definition_2d()
	var binding: GFProjectileBinding2D = definition.bind_instance(root)
	assert_true(binding.is_valid())
	if not binding.is_valid():
		return
	var runtime: GFProjectile2D = _runtime_2d_from(root)
	var retirement_owner: Node = Node.new()
	var foreign_owner: Node = Node.new()
	add_child_autofree(retirement_owner)
	add_child_autofree(foreign_owner)
	var reservation: GFProjectileLaunchReservation = runtime.reserve_launch_for_framework(
		binding,
		GFProjectileLaunchInput2D.new(),
		retirement_owner
	)
	assert_false(reservation.abort_for_framework(foreign_owner, &"foreign"))
	assert_eq(reservation.get_state_for_framework(), GFProjectileLaunchReservation.State.RESERVED)
	assert_true(reservation.abort_for_framework(retirement_owner, &"batch_failed"))
	assert_eq(reservation.get_state_for_framework(), GFProjectileLaunchReservation.State.ABORTED)
	assert_false(reservation.abort_for_framework(retirement_owner, &"repeated"))
	assert_ne(reservation.arm_for_framework(retirement_owner), OK)
	assert_null(reservation.consume_for_framework(retirement_owner))
	assert_false(runtime.is_active())


func test_projectile_launch_reservation_invalidates_when_topology_changes() -> void:
	var root: Node2D = _make_bound_projectile_root_2d()
	add_child_autofree(root)
	var definition: GFProjectileDefinition2D = _make_projectile_definition_2d()
	var binding: GFProjectileBinding2D = definition.bind_instance(root)
	assert_true(binding.is_valid())
	if not binding.is_valid():
		return
	var runtime: GFProjectile2D = _runtime_2d_from(root)
	var retirement_owner: Node = Node.new()
	add_child_autofree(retirement_owner)
	var reservation: GFProjectileLaunchReservation = runtime.reserve_launch_for_framework(
		binding,
		GFProjectileLaunchInput2D.new(),
		retirement_owner
	)

	root.remove_child(runtime)
	assert_ne(reservation.arm_for_framework(retirement_owner), OK)
	assert_eq(
		reservation.get_state_for_framework(),
		GFProjectileLaunchReservation.State.INVALIDATED
	)
	assert_null(reservation.consume_for_framework(retirement_owner))
	runtime.free()


func test_projectile_runtime_stops_step_after_capture_callback_finishes_session() -> void:
	var root: Node2D = _make_bound_projectile_root_2d()
	add_child_autofree(root)
	var definition: GFProjectileDefinition2D = _make_projectile_definition_2d()
	var adapter: FinishingCaptureAdapter2D = FinishingCaptureAdapter2D.new()
	definition.body_adapter = adapter
	var binding: GFProjectileBinding2D = definition.bind_instance(root)
	assert_true(binding.is_valid())
	if not binding.is_valid():
		return
	var runtime: GFProjectile2D = binding.get_runtime()
	var session: GFProjectileSession = runtime.launch(binding)
	assert_not_null(session)
	if session == null:
		return
	adapter.active_session = session
	var before_step: Vector2 = root.position
	runtime._physics_process(0.5)
	assert_true(session.is_finished())
	assert_eq(session.get_end_reason(), GFProjectileSession.EndReason.CALLER_FINISHED)
	assert_eq(root.position, before_step, "capture callback 结算后不得继续 compute/apply 旧 generation。")
	assert_eq(adapter.capture_count, 2, "一次 reserve preflight 与一次 physics capture。")
	assert_null(runtime.get_active_session())
	adapter.active_session = null


func test_projectile_session_accumulates_actual_displacement_instead_of_net_offset() -> void:
	var root: Node2D = _make_bound_projectile_root_2d()
	root.position = Vector2.ZERO
	add_child_autofree(root)
	var target: Node2D = Node2D.new()
	target.position = Vector2(3.0, 0.0)
	add_child_autofree(target)
	var definition: GFProjectileDefinition2D = _make_projectile_definition_2d()
	var motion: GFHomingProjectileMotion = GFHomingProjectileMotion.new()
	motion.speed = 3.0
	motion.arrival_distance = 0.0
	motion.track_target = true
	motion.stop_when_reached = true
	definition.motion = motion
	var lifetime: GFProjectileLifetimePolicy = GFProjectileLifetimePolicy.new()
	lifetime.max_distance = 6.5
	definition.lifetime_policy = lifetime
	var binding: GFProjectileBinding2D = definition.bind_instance(root)
	assert_true(binding.is_valid())
	if not binding.is_valid():
		return
	var runtime: GFProjectile2D = _runtime_2d_from(root)
	var input: GFProjectileLaunchInput2D = GFProjectileLaunchInput2D.new()
	input.set_target_node(target)

	var session: GFProjectileSession = runtime.launch(binding, input)
	runtime._physics_process(1.0)
	assert_eq(root.position, Vector2(3.0, 0.0))
	assert_almost_eq(session.get_travelled_distance(), 3.0, 0.0001)
	assert_true(session.is_active())

	target.position = Vector2(-1.0, 0.0)
	motion.speed = 4.0
	runtime._physics_process(1.0)

	assert_eq(root.position, Vector2(-1.0, 0.0), "完整 root 应由 adapter 应用运动。")
	assert_almost_eq(
		session.get_travelled_distance(),
		7.0,
		0.0001,
		"折返路径必须累计两次 BodyResult.actual_world_displacement 的长度。"
	)
	assert_true(session.is_finished())
	assert_eq(
		session.get_end_reason(),
		GFProjectileSession.EndReason.LIFETIME_DISTANCE
	)


func test_projectile_session_finishes_on_elapsed_lifetime() -> void:
	var root: Node2D = _make_bound_projectile_root_2d()
	add_child_autofree(root)
	var definition: GFProjectileDefinition2D = _make_projectile_definition_2d()
	var motion: GFLinearProjectileMotion = GFLinearProjectileMotion.new()
	motion.speed = 1.0
	motion.use_local_direction = false
	motion.direction_2d = Vector2.RIGHT
	definition.motion = motion
	var lifetime: GFProjectileLifetimePolicy = GFProjectileLifetimePolicy.new()
	lifetime.max_seconds = 0.25
	definition.lifetime_policy = lifetime
	var binding: GFProjectileBinding2D = definition.bind_instance(root)
	assert_true(binding.is_valid())
	if not binding.is_valid():
		return
	var runtime: GFProjectile2D = _runtime_2d_from(root)
	var session: GFProjectileSession = runtime.launch(binding)
	runtime._physics_process(0.3)
	assert_true(session.is_finished())
	assert_almost_eq(session.get_elapsed_seconds(), 0.3, 0.0001)
	assert_eq(session.get_end_reason(), GFProjectileSession.EndReason.LIFETIME_SECONDS)


func test_homing_motion_clamps_at_arrival_distance_through_adapter() -> void:
	var root: Node2D = _make_bound_projectile_root_2d()
	add_child_autofree(root)
	var definition: GFProjectileDefinition2D = _make_projectile_definition_2d()
	var motion: GFHomingProjectileMotion = GFHomingProjectileMotion.new()
	motion.speed = 10.0
	motion.arrival_distance = 1.0
	motion.stop_when_reached = true
	definition.motion = motion
	var binding: GFProjectileBinding2D = definition.bind_instance(root)
	assert_true(binding.is_valid())
	if not binding.is_valid():
		return
	var input: GFProjectileLaunchInput2D = GFProjectileLaunchInput2D.new()
	input.set_target_position(Vector2(3.0, 0.0))
	var runtime: GFProjectile2D = _runtime_2d_from(root)
	var session: GFProjectileSession = runtime.launch(binding, input)
	runtime._physics_process(0.5)
	assert_eq(root.position, Vector2(2.0, 0.0))
	assert_almost_eq(session.get_travelled_distance(), 2.0, 0.0001)
	assert_true(session.is_active())
	var _finished: bool = session.finish(GFProjectileSession.EndReason.CALLER_FINISHED)


func test_homing_negative_arrival_distance_disables_clamp_symmetrically() -> void:
	var motion: GFHomingProjectileMotion = GFHomingProjectileMotion.new()
	motion.speed = 10.0
	motion.arrival_distance = -1.0
	motion.stop_when_reached = true

	var input_2d: GFProjectileLaunchInput2D = GFProjectileLaunchInput2D.new()
	input_2d.set_target_position(Vector2(2.0, 0.0))
	var initial_2d: GFProjectileBodyResult2D = GFProjectileBodyResult2D.successful(
		Transform2D.IDENTITY
	)
	var state_2d: GFProjectileMotionState = motion.create_state_2d(input_2d, initial_2d)
	assert_not_null(state_2d)
	if state_2d != null:
		var intent_2d: GFProjectileMotionIntent2D = motion.compute_intent_2d(
			state_2d,
			initial_2d,
			1.0
		)
		assert_eq(intent_2d.get_kind(), GFProjectileMotionIntent2D.Kind.MOVE)
		assert_eq(intent_2d.get_velocity(), Vector2(10.0, 0.0))

	var input_3d: GFProjectileLaunchInput3D = GFProjectileLaunchInput3D.new()
	input_3d.set_target_position(Vector3(2.0, 0.0, 0.0))
	var initial_3d: GFProjectileBodyResult3D = GFProjectileBodyResult3D.successful(
		Transform3D.IDENTITY
	)
	var state_3d: GFProjectileMotionState = motion.create_state_3d(input_3d, initial_3d)
	assert_not_null(state_3d)
	if state_3d != null:
		var intent_3d: GFProjectileMotionIntent3D = motion.compute_intent_3d(
			state_3d,
			initial_3d,
			1.0
		)
		assert_eq(intent_3d.get_kind(), GFProjectileMotionIntent3D.Kind.MOVE)
		assert_eq(intent_3d.get_velocity(), Vector3(10.0, 0.0, 0.0))

	motion.arrival_distance = NAN
	assert_null(motion.create_state_2d(input_2d, initial_2d))
	motion.arrival_distance = INF
	assert_null(motion.create_state_3d(input_3d, initial_3d))


func test_homing_motion_finishes_when_tracked_target_is_lost() -> void:
	var root: Node2D = _make_bound_projectile_root_2d()
	add_child_autofree(root)
	var target: Node2D = Node2D.new()
	target.position = Vector2(10.0, 0.0)
	var definition: GFProjectileDefinition2D = _make_projectile_definition_2d()
	var motion: GFHomingProjectileMotion = GFHomingProjectileMotion.new()
	motion.speed = 10.0
	motion.track_target = true
	definition.motion = motion
	var binding: GFProjectileBinding2D = definition.bind_instance(root)
	assert_true(binding.is_valid())
	if not binding.is_valid():
		target.free()
		return
	var input: GFProjectileLaunchInput2D = GFProjectileLaunchInput2D.new()
	input.set_target_node(target)
	var runtime: GFProjectile2D = _runtime_2d_from(root)
	var session: GFProjectileSession = runtime.launch(binding, input)
	target.free()
	runtime._physics_process(0.5)
	assert_eq(root.position, Vector2.ZERO)
	assert_true(session.is_finished())
	assert_eq(session.get_end_reason(), GFProjectileSession.EndReason.TARGET_LOST)


func test_locked_homing_motion_keeps_private_2d_and_3d_direction_after_target_loss() -> void:
	var root_2d: Node2D = _make_bound_projectile_root_2d()
	add_child_autofree(root_2d)
	var target_2d: Node2D = Node2D.new()
	target_2d.position = Vector2(10.0, 0.0)
	var definition_2d: GFProjectileDefinition2D = _make_projectile_definition_2d()
	var motion_2d: GFHomingProjectileMotion = GFHomingProjectileMotion.new()
	motion_2d.speed = 10.0
	motion_2d.track_target = false
	definition_2d.motion = motion_2d
	var binding_2d: GFProjectileBinding2D = definition_2d.bind_instance(root_2d)
	assert_true(binding_2d.is_valid())
	if not binding_2d.is_valid():
		target_2d.free()
		return
	var input_2d: GFProjectileLaunchInput2D = GFProjectileLaunchInput2D.new()
	input_2d.set_target_node(target_2d)
	var runtime_2d: GFProjectile2D = _runtime_2d_from(root_2d)
	var session_2d: GFProjectileSession = runtime_2d.launch(binding_2d, input_2d)
	target_2d.free()
	runtime_2d._physics_process(0.5)
	assert_eq(root_2d.position, Vector2(5.0, 0.0))
	assert_true(session_2d.is_active())

	var root_3d: Node3D = _make_bound_projectile_root_3d()
	add_child_autofree(root_3d)
	var target_3d: Node3D = Node3D.new()
	target_3d.position = Vector3(0.0, 0.0, -10.0)
	var definition_3d: GFProjectileDefinition3D = _make_projectile_definition_3d()
	var motion_3d: GFHomingProjectileMotion = GFHomingProjectileMotion.new()
	motion_3d.speed = 6.0
	motion_3d.track_target = false
	definition_3d.motion = motion_3d
	var binding_3d: GFProjectileBinding3D = definition_3d.bind_instance(root_3d)
	assert_true(binding_3d.is_valid())
	if not binding_3d.is_valid():
		target_3d.free()
		var _finished_2d_after_invalid_3d: bool = session_2d.finish(
			GFProjectileSession.EndReason.CALLER_FINISHED
		)
		return
	var input_3d: GFProjectileLaunchInput3D = GFProjectileLaunchInput3D.new()
	input_3d.set_target_node(target_3d)
	var runtime_3d: GFProjectile3D = _runtime_3d_from(root_3d)
	var session_3d: GFProjectileSession = runtime_3d.launch(binding_3d, input_3d)
	assert_eq(session_3d.get_dimension(), GFProjectileSession.Dimension.THREE_D)
	target_3d.free()
	runtime_3d._physics_process(0.5)
	assert_eq(root_3d.position, Vector3(0.0, 0.0, -3.0))
	assert_true(session_3d.is_active())
	var _finished_2d: bool = session_2d.finish(GFProjectileSession.EndReason.CALLER_FINISHED)
	var _finished_3d: bool = session_3d.finish(GFProjectileSession.EndReason.CALLER_FINISHED)


func test_projectile_session_tracks_zero_one_and_many_bound_impact_sources() -> void:
	var receiver: HitReceiver2D = HitReceiver2D.new()
	var rejecting_receiver: RejectingHitReceiver2D = RejectingHitReceiver2D.new()
	add_child_autofree(receiver)
	add_child_autofree(rejecting_receiver)

	var zero_root: Node2D = _make_bound_projectile_root_2d()
	add_child_autofree(zero_root)
	var zero_definition: GFProjectileDefinition2D = _make_projectile_definition_2d()
	var zero_binding: GFProjectileBinding2D = zero_definition.bind_instance(zero_root)
	assert_true(zero_binding.is_valid())
	if not zero_binding.is_valid():
		return
	var zero_session: GFProjectileSession = _runtime_2d_from(zero_root).launch(zero_binding)
	assert_true(zero_session.is_active())
	assert_eq(zero_session.get_accepted_impact_count(), 0)

	var one_paths: Array[NodePath] = [NodePath("Impact")]
	var one_root: Node2D = _make_bound_projectile_root_2d([&"Impact"])
	add_child_autofree(one_root)
	var one_definition: GFProjectileDefinition2D = _make_projectile_definition_2d(one_paths)
	var one_lifetime: GFProjectileLifetimePolicy = GFProjectileLifetimePolicy.new()
	one_lifetime.max_impacts = 1
	one_definition.lifetime_policy = one_lifetime
	var one_binding: GFProjectileBinding2D = one_definition.bind_instance(one_root)
	assert_true(one_binding.is_valid())
	if not one_binding.is_valid():
		var _zero_cleanup_after_one_binding: bool = zero_session.finish(
			GFProjectileSession.EndReason.CALLER_FINISHED
		)
		return
	var one_session: GFProjectileSession = _runtime_2d_from(one_root).launch(one_binding)
	var one_source: GFHitBox2D = _hit_box_2d_from(one_root, NodePath("Impact"))
	var _one_report: Dictionary = one_source.send_to(receiver)
	assert_eq(one_session.get_accepted_impact_count(), 1)
	assert_true(one_session.is_finished())
	assert_eq(
		one_session.get_end_reason(),
		GFProjectileSession.EndReason.LIFETIME_IMPACTS
	)

	var many_paths: Array[NodePath] = [NodePath("ImpactA"), NodePath("ImpactB")]
	var many_root: Node2D = _make_bound_projectile_root_2d([&"ImpactA", &"ImpactB"])
	add_child_autofree(many_root)
	var many_definition: GFProjectileDefinition2D = (
		_make_projectile_definition_2d(many_paths)
	)
	var many_lifetime: GFProjectileLifetimePolicy = GFProjectileLifetimePolicy.new()
	many_lifetime.max_impacts = 2
	many_definition.lifetime_policy = many_lifetime
	var many_binding: GFProjectileBinding2D = many_definition.bind_instance(many_root)
	assert_true(many_binding.is_valid())
	if not many_binding.is_valid():
		var _zero_cleanup_after_many_binding: bool = zero_session.finish(
			GFProjectileSession.EndReason.CALLER_FINISHED
		)
		return
	var many_session: GFProjectileSession = _runtime_2d_from(many_root).launch(many_binding)
	var source_a: GFHitBox2D = _hit_box_2d_from(many_root, NodePath("ImpactA"))
	var source_b: GFHitBox2D = _hit_box_2d_from(many_root, NodePath("ImpactB"))
	var _rejected_report: Dictionary = source_a.send_to(rejecting_receiver)
	assert_eq(many_session.get_accepted_impact_count(), 0, "拒绝命中不得累计。")
	assert_true(many_session.is_active())
	var _accepted_a_report: Dictionary = source_a.send_to(receiver)
	assert_eq(many_session.get_accepted_impact_count(), 1)
	assert_true(many_session.is_active())
	var _accepted_b_report: Dictionary = source_b.send_to(receiver)
	assert_eq(many_session.get_accepted_impact_count(), 2)
	assert_true(many_session.is_finished())
	assert_eq(
		many_session.get_end_reason(),
		GFProjectileSession.EndReason.LIFETIME_IMPACTS
	)

	var _zero_finished: bool = zero_session.finish(
		GFProjectileSession.EndReason.CALLER_FINISHED
	)


func test_projectile_generation_ignores_stale_impact_callback() -> void:
	var source_paths: Array[NodePath] = [NodePath("Impact")]
	var root: Node2D = _make_bound_projectile_root_2d([&"Impact"])
	add_child_autofree(root)
	var receiver: HitReceiver2D = HitReceiver2D.new()
	add_child_autofree(receiver)
	var definition: GFProjectileDefinition2D = _make_projectile_definition_2d(source_paths)
	var runtime: GFProjectile2D = _runtime_2d_from(root)
	var source: GFHitBox2D = _hit_box_2d_from(root, NodePath("Impact"))
	var first_binding: GFProjectileBinding2D = definition.bind_instance(root)
	assert_true(first_binding.is_valid())
	if not first_binding.is_valid():
		return
	var first_session: GFProjectileSession = runtime.launch(first_binding)
	var stale_callback: Callable = _first_signal_callable(source, &"hit_accepted")
	assert_true(stale_callback.is_valid(), "launch 应只为当前 generation 连接显式 impact source。")
	assert_true(first_session.finish(GFProjectileSession.EndReason.CALLER_FINISHED))

	var second_binding: GFProjectileBinding2D = definition.bind_instance(root)
	assert_true(second_binding.is_valid())
	if not second_binding.is_valid():
		return
	var second_session: GFProjectileSession = runtime.launch(second_binding)
	assert_gt(second_session.get_generation(), first_session.get_generation())
	var stale_context: GFCombatHitContext = GFCombatHitContext.new()
	var _stale_result: Variant = stale_callback.call(
		stale_context,
		receiver,
		{ "ok": true }
	)
	assert_eq(
		second_session.get_accepted_impact_count(),
		0,
		"上一 generation 的残留 callback 不得污染复用后的 session。"
	)
	assert_true(second_session.is_active())

	var _current_report: Dictionary = source.send_to(receiver)
	assert_eq(second_session.get_accepted_impact_count(), 1, "当前 generation callback 仍应生效。")
	var _second_finished: bool = second_session.finish(
		GFProjectileSession.EndReason.CALLER_FINISHED
	)


func test_projectile_emission_policy_consumes_and_recovers_charges() -> void:
	var policy: GFProjectileEmissionPolicy = GFProjectileEmissionPolicy.new()
	policy.charge_capacity = 2.0
	policy.charge_cost_per_request = 1.0
	policy.charge_cost_per_projectile = 0.5
	policy.charge_recovery_seconds = 1.0
	policy.reset(0)

	var prepare_report: Dictionary = policy.prepare_emission(null, &"arrow", {}, 2, 0)
	var commit_report: Dictionary = policy.commit_emission(null, prepare_report, 2)
	var blocked_report: Dictionary = policy.prepare_emission(null, &"arrow", {}, 1, 0)
	var recovered_report: Dictionary = policy.prepare_emission(null, &"arrow", {}, 1, 2000)

	assert_true(GFVariantData.get_option_bool(prepare_report, "ok"))
	assert_true(GFVariantData.get_option_bool(commit_report, "committed"))
	assert_eq(GFVariantData.get_option_float(commit_report, "available_charges"), 0.0)
	assert_eq(GFVariantData.get_option_int(commit_report, "now_msec"), 0)
	assert_false(GFVariantData.get_option_bool(blocked_report, "ok"))
	assert_eq(
		GFVariantData.get_option_string_name(blocked_report, "reason"),
		&"insufficient_charges"
	)
	assert_true(GFVariantData.get_option_bool(recovered_report, "ok"))


func test_projectile_emission_policy_rejects_stale_overlapping_prepare_report() -> void:
	var policy: GFProjectileEmissionPolicy = GFProjectileEmissionPolicy.new()
	policy.max_emission_count = 1
	var first_prepare: Dictionary = policy.prepare_emission(null, &"arrow", {}, 1, 0)
	var second_prepare: Dictionary = policy.prepare_emission(null, &"arrow", {}, 1, 0)
	var first_commit: Dictionary = policy.commit_emission(null, first_prepare, 1)
	var second_commit: Dictionary = policy.commit_emission(null, second_prepare, 1)

	assert_true(GFVariantData.get_option_bool(first_prepare, "ok"))
	assert_true(GFVariantData.get_option_bool(second_prepare, "ok"))
	assert_true(GFVariantData.get_option_bool(first_commit, "committed"))
	assert_false(GFVariantData.get_option_bool(second_commit, "ok"))
	assert_eq(
		GFVariantData.get_option_string_name(second_commit, "reason"),
		&"stale_prepare_report"
	)
	assert_eq(
		GFVariantData.get_option_int(policy.get_debug_snapshot(0), "emission_count"),
		1
	)


func test_projectile_emission_policy_rejects_foreign_or_oversized_commit() -> void:
	var source_policy: GFProjectileEmissionPolicy = GFProjectileEmissionPolicy.new()
	source_policy.max_projectiles_per_request = 1
	var foreign_policy: GFProjectileEmissionPolicy = GFProjectileEmissionPolicy.new()
	var prepare_report: Dictionary = source_policy.prepare_emission(
		null,
		&"arrow",
		{},
		1,
		0
	)
	var foreign_commit: Dictionary = foreign_policy.commit_emission(
		null,
		prepare_report,
		1
	)
	var oversized_commit: Dictionary = source_policy.commit_emission(
		null,
		prepare_report,
		2
	)

	assert_false(GFVariantData.get_option_bool(foreign_commit, "ok"))
	assert_eq(
		GFVariantData.get_option_string_name(foreign_commit, "reason"),
		&"foreign_prepare_report"
	)
	assert_false(GFVariantData.get_option_bool(oversized_commit, "ok"))
	assert_eq(
		GFVariantData.get_option_string_name(oversized_commit, "reason"),
		&"invalid_emitted_count"
	)


func test_projectile_emission_policy_rejects_non_finite_configuration() -> void:
	var policy: GFProjectileEmissionPolicy = GFProjectileEmissionPolicy.new()
	policy.cooldown_seconds = NAN
	var report: Dictionary = policy.prepare_emission(null, &"arrow", {}, 1, 0)
	assert_false(GFVariantData.get_option_bool(report, "ok"))
	assert_eq(
		GFVariantData.get_option_string_name(report, "reason"),
		&"non_finite_policy_configuration"
	)


func test_projectile_deferred_commit_compensates_charge_and_cooldown_before_active() -> void:
	var emitter_owner: Node = Node.new()
	add_child_autofree(emitter_owner)
	var policy: RecordingEmissionPolicy = RecordingEmissionPolicy.new()
	policy.cooldown_seconds = 5.0
	policy.charge_capacity = 10.0
	policy.charge_cost_per_request = 2.0
	policy.charge_cost_per_projectile = 1.0
	policy.reset(0)
	var task: GFProjectileEmissionTask = GFProjectileEmissionTask.new()
	var _configured_task: GFProjectileEmissionTask = task.configure(
		emitter_owner,
		policy,
		&"arrow",
		{},
		2,
		8,
		0
	)
	var prepare_report: Dictionary = task.prepare()
	assert_true(GFVariantData.get_option_bool(prepare_report, "ok"))

	var receipt: GFProjectileEmissionReceipt = task.commit_deferred_for_framework(2)
	assert_not_null(receipt)
	assert_eq(
		receipt.get_state_for_framework(),
		GFProjectileEmissionReceipt.State.COMMITTED_UNPUBLISHED
	)
	assert_almost_eq(policy.get_available_charges(0), 6.0, 0.0001)
	assert_almost_eq(policy.get_remaining_cooldown_seconds(0), 5.0, 0.0001)
	assert_eq(
		GFVariantData.get_option_int(policy.get_debug_snapshot(0), "emission_count"),
		1
	)
	assert_eq(policy.commit_hook_count, 0, "deferred commit 不得提前执行用户 commit hook。")

	var compensate_report: Dictionary = receipt.compensate_for_framework(&"activation_failed")
	assert_true(GFVariantData.get_option_bool(compensate_report, "ok"))
	assert_true(GFVariantData.get_option_bool(compensate_report, "compensated"))
	assert_eq(
		receipt.get_state_for_framework(),
		GFProjectileEmissionReceipt.State.COMPENSATED
	)
	assert_almost_eq(policy.get_available_charges(0), 10.0, 0.0001)
	assert_almost_eq(policy.get_remaining_cooldown_seconds(0), 0.0, 0.0001)
	assert_eq(
		GFVariantData.get_option_int(policy.get_debug_snapshot(0), "emission_count"),
		0
	)
	assert_eq(policy.commit_hook_count, 0)

	var repeated_report: Dictionary = receipt.compensate_for_framework(&"repeated")
	assert_false(GFVariantData.get_option_bool(repeated_report, "ok"))
	assert_almost_eq(policy.get_available_charges(0), 10.0, 0.0001)
	assert_eq(policy.commit_hook_count, 0)


func test_projectile_deferred_commit_publishes_hook_once_and_cannot_compensate_active() -> void:
	var emitter_owner: Node = Node.new()
	add_child_autofree(emitter_owner)
	var policy: RecordingEmissionPolicy = RecordingEmissionPolicy.new()
	policy.cooldown_seconds = 5.0
	policy.charge_capacity = 5.0
	policy.charge_cost_per_request = 1.0
	policy.charge_cost_per_projectile = 1.0
	policy.reset(0)
	var task: GFProjectileEmissionTask = GFProjectileEmissionTask.new()
	var _configured_task: GFProjectileEmissionTask = task.configure(
		emitter_owner,
		policy,
		&"arrow",
		{},
		1,
		8,
		0
	)
	var prepare_report: Dictionary = task.prepare()
	assert_true(GFVariantData.get_option_bool(prepare_report, "ok"))
	var receipt: GFProjectileEmissionReceipt = task.commit_deferred_for_framework(1)
	assert_not_null(receipt)
	assert_eq(policy.commit_hook_count, 0)

	assert_eq(receipt.mark_activated_for_framework(), OK)
	assert_eq(
		receipt.get_state_for_framework(),
		GFProjectileEmissionReceipt.State.ACTIVATED
	)
	var compensate_report: Dictionary = receipt.compensate_for_framework(&"too_late")
	assert_false(GFVariantData.get_option_bool(compensate_report, "ok"))
	assert_almost_eq(policy.get_available_charges(0), 3.0, 0.0001)
	assert_almost_eq(policy.get_remaining_cooldown_seconds(0), 5.0, 0.0001)
	assert_eq(policy.commit_hook_count, 0)

	var publish_report: Dictionary = receipt.publish_for_framework()
	assert_true(GFVariantData.get_option_bool(publish_report, "ok"))
	assert_eq(
		receipt.get_state_for_framework(),
		GFProjectileEmissionReceipt.State.PUBLISHED
	)
	assert_eq(policy.commit_hook_count, 1, "用户 commit hook 只能在 ACTIVE 后发布一次。")
	var repeated_publish: Dictionary = receipt.publish_for_framework()
	assert_false(GFVariantData.get_option_bool(repeated_publish, "ok"))
	assert_eq(policy.commit_hook_count, 1)


func test_projectile_activated_receipt_stays_published_when_hook_hard_frees_emitter() -> void:
	var parent: Node = Node.new()
	add_child_autofree(parent)
	var emitter_owner: Node = Node.new()
	parent.add_child(emitter_owner)
	var policy: ReleasingCommitPolicy = ReleasingCommitPolicy.new()
	policy.release_mode = ReleasingCommitPolicy.ReleaseMode.FREE
	policy.charge_capacity = 4.0
	policy.charge_cost_per_request = 1.0
	policy.charge_cost_per_projectile = 1.0
	policy.reset(0)
	var task: GFProjectileEmissionTask = GFProjectileEmissionTask.new()
	var _configured_task: GFProjectileEmissionTask = task.configure(
		emitter_owner,
		policy,
		&"arrow",
		{},
		1,
		8,
		0
	)
	assert_true(GFVariantData.get_option_bool(task.prepare(), "ok"))
	var receipt: GFProjectileEmissionReceipt = task.commit_deferred_for_framework(1)
	assert_not_null(receipt)
	if receipt == null:
		return
	assert_eq(receipt.mark_activated_for_framework(), OK)

	var publish_report: Dictionary = receipt.publish_for_framework()
	assert_true(GFVariantData.get_option_bool(publish_report, "ok"))
	assert_false(is_instance_valid(emitter_owner))
	assert_eq(
		receipt.get_state_for_framework(),
		GFProjectileEmissionReceipt.State.PUBLISHED,
		"ACTIVATED receipt 的 hook 销毁 emitter 后仍必须 first-wins PUBLISHED。"
	)
	assert_false(
		GFVariantData.get_option_bool(
			receipt.compensate_for_framework(&"hard_free_after_activation"),
			"ok"
		)
	)
	assert_almost_eq(policy.get_available_charges(0), 2.0, 0.0001)


func test_projectile_receipt_and_policy_reject_reentrant_publication_settlement() -> void:
	var emitter_owner: Node = Node.new()
	add_child_autofree(emitter_owner)
	var policy: ReentrantReceiptPolicy = ReentrantReceiptPolicy.new()
	policy.charge_capacity = 4.0
	policy.charge_cost_per_request = 1.0
	policy.reset(0)
	var task: GFProjectileEmissionTask = GFProjectileEmissionTask.new()
	var _configured_task: GFProjectileEmissionTask = task.configure(
		emitter_owner,
		policy,
		&"arrow",
		{},
		1,
		8,
		0
	)
	assert_true(GFVariantData.get_option_bool(task.prepare(), "ok"))
	var receipt: GFProjectileEmissionReceipt = task.commit_deferred_for_framework(1)
	assert_not_null(receipt)
	if receipt == null:
		return
	policy.receipt = receipt
	assert_eq(receipt.mark_activated_for_framework(), OK)

	var publish_report: Dictionary = receipt.publish_for_framework()
	assert_true(GFVariantData.get_option_bool(publish_report, "ok"))
	assert_eq(receipt.get_state_for_framework(), GFProjectileEmissionReceipt.State.PUBLISHED)
	assert_eq(policy.commit_hook_count, 1)
	assert_false(GFVariantData.get_option_bool(policy.nested_publish_report, "ok"))
	assert_eq(
		GFVariantData.get_option_string_name(policy.nested_publish_report, "reason"),
		&"receipt_not_activated"
	)
	assert_false(GFVariantData.get_option_bool(policy.nested_commit_report, "ok"))
	assert_eq(
		GFVariantData.get_option_string_name(policy.nested_commit_report, "reason"),
		&"emission_commit_reentrant"
	)
	assert_almost_eq(policy.get_available_charges(0), 3.0, 0.0001)
	policy.receipt = null


func test_projectile_emitter_retires_fresh_candidate_once_on_precommit_failure() -> void:
	var parent: Node2D = Node2D.new()
	add_child_autofree(parent)
	var emitter: GFProjectileEmitter2D = GFProjectileEmitter2D.new()
	parent.add_child(emitter)
	var definition: GFProjectileDefinition2D = _make_projectile_definition_2d()
	var malformed_root: Node2D = Node2D.new()
	malformed_root.name = &"MalformedProjectileRoot"
	definition.scene = _pack_projectile_root(malformed_root)
	emitter.projectile_definition = definition
	var policy: GFProjectileEmissionPolicy = GFProjectileEmissionPolicy.new()
	policy.cooldown_seconds = 5.0
	policy.charge_capacity = 4.0
	policy.charge_cost_per_request = 1.0
	policy.charge_cost_per_projectile = 1.0
	policy.reset(0)
	emitter.emission_policy = policy
	var captured_candidates: Array[Node] = []
	var exit_count: Array[int] = [0]
	var capture_callback: Callable = func(captured_candidate: Node) -> void:
		captured_candidates.append(captured_candidate)
		var exit_callback: Callable = func() -> void:
			exit_count[0] += 1
		var _connected: int = captured_candidate.tree_exiting.connect(exit_callback)
	var _capture_connected: int = parent.child_entered_tree.connect(capture_callback)

	var emitted_roots: Array[Node] = emitter.emit_projectiles(
		GFProjectileLaunchInput2D.new(),
		&"",
		1
	)
	parent.child_entered_tree.disconnect(capture_callback)
	assert_true(emitted_roots.is_empty(), "绑定失败不得返回部分生成 root。")
	assert_eq(captured_candidates.size(), 1)
	if captured_candidates.is_empty():
		return
	var candidate: Node = captured_candidates[0]
	var candidate_ref: WeakRef = weakref(candidate)
	var candidate_was_queued: bool = candidate.is_queued_for_deletion()
	assert_true(candidate_was_queued, "fresh pre-commit candidate 必须进入退休。")
	if not candidate_was_queued:
		candidate.queue_free()
	assert_almost_eq(policy.get_available_charges(0), 4.0, 0.0001)
	assert_almost_eq(policy.get_remaining_cooldown_seconds(0), 0.0, 0.0001)
	assert_eq(
		GFVariantData.get_option_int(policy.get_debug_snapshot(0), "emission_count"),
		0
	)

	await get_tree().process_frame
	await get_tree().process_frame
	assert_true(candidate_ref.get_ref() == null)
	assert_eq(exit_count[0], 1, "fresh candidate 必须恰好一次退出并释放。")


func test_projectile_emitter_aborts_whole_pool_batch_and_releases_each_lease_once() -> void:
	var parent: Node2D = Node2D.new()
	add_child_autofree(parent)
	var emitter: GFProjectileEmitter2D = GFProjectileEmitter2D.new()
	parent.add_child(emitter)
	emitter.projectile_definition = _make_projectile_definition_2d()
	emitter.use_object_pool = true
	var pool: RecordingObjectPool = RecordingObjectPool.new()
	pool.invalidate_acquire_index = 1
	emitter.object_pool_utility = pool
	var policy: GFProjectileEmissionPolicy = GFProjectileEmissionPolicy.new()
	policy.cooldown_seconds = 5.0
	policy.charge_capacity = 8.0
	policy.charge_cost_per_request = 2.0
	policy.charge_cost_per_projectile = 1.0
	policy.reset(0)
	emitter.emission_policy = policy

	var emitted_roots: Array[Node] = emitter.emit_projectiles(
		GFProjectileLaunchInput2D.new(),
		&"",
		2
	)
	assert_true(emitted_roots.is_empty(), "任一候选 bind/reserve 失败必须中止整个批次。")
	assert_eq(pool.acquire_count, 2)
	assert_eq(pool.release_count, 2, "已分配的 pool lease 必须各归还恰好一次。")
	assert_eq(pool.released_nodes.size(), 2)
	if pool.released_nodes.size() == 2:
		assert_ne(pool.released_nodes[0], pool.released_nodes[1])
	assert_almost_eq(policy.get_available_charges(0), 8.0, 0.0001)
	assert_almost_eq(policy.get_remaining_cooldown_seconds(0), 0.0, 0.0001)
	assert_eq(
		GFVariantData.get_option_int(policy.get_debug_snapshot(0), "emission_count"),
		0
	)
	for candidate: Node in pool.acquired_nodes:
		if is_instance_valid(candidate):
			candidate.free()


func test_projectile_emitter_releases_unconsumed_pool_claims_after_partial_activation() -> void:
	var parent: Node2D = Node2D.new()
	add_child_autofree(parent)
	var emitter: GFProjectileEmitter2D = GFProjectileEmitter2D.new()
	parent.add_child(emitter)
	var definition: GFProjectileDefinition2D = _make_projectile_definition_2d()
	var custom_root: Node2D = Node2D.new()
	custom_root.name = &"PartialActivationRoot"
	var custom_runtime: RejectingConsumeProjectile2D = RejectingConsumeProjectile2D.new()
	custom_runtime.name = &"ProjectileRuntime"
	custom_root.add_child(custom_runtime)
	definition.scene = _pack_projectile_root(custom_root)
	emitter.projectile_definition = definition
	emitter.use_object_pool = true
	var pool: RecordingObjectPool = RecordingObjectPool.new()
	pool.reuse_released_nodes = true
	emitter.object_pool_utility = pool
	var policy: GFProjectileEmissionPolicy = GFProjectileEmissionPolicy.new()
	policy.charge_capacity = 20.0
	policy.charge_cost_per_request = 2.0
	policy.charge_cost_per_projectile = 1.0
	policy.reset(0)
	emitter.emission_policy = policy
	var allocation_index: Array[int] = [0]
	var configure_candidate: Callable = func(candidate: Node) -> void:
		var runtime_value: Node = candidate.get_node_or_null(
			NodePath("ProjectileRuntime")
		)
		if runtime_value is RejectingConsumeProjectile2D:
			var runtime: RejectingConsumeProjectile2D = runtime_value
			runtime.reject_consume = allocation_index[0] == 1
		allocation_index[0] += 1
	var _candidate_connected: int = parent.child_entered_tree.connect(configure_candidate)

	var first_roots: Array[Node] = emitter.emit_projectiles(
		GFProjectileLaunchInput2D.new(),
		&"",
		3
	)
	assert_true(first_roots.is_empty(), "中途 activation 失败不得返回部分 ACTIVE root。")
	assert_eq(pool.acquire_count, 3)
	assert_eq(pool.release_count, 3, "失败批次的三个 lease 必须各退休恰好一次。")
	assert_almost_eq(policy.get_available_charges(0), 15.0, 0.0001)
	assert_eq(
		GFVariantData.get_option_int(policy.get_debug_snapshot(0), "emission_count"),
		1,
		"已有一个 ACTIVE session 时 charge/cooldown 不得补偿。"
	)
	for candidate: Node in pool.acquired_nodes:
		var runtime: GFProjectile2D = _runtime_2d_from(candidate)
		assert_not_null(runtime)
		if runtime != null:
			assert_false(
				runtime.has_launch_claim_for_framework(),
				"未消费的 ARMED reservation 必须在 pool release 前解除 claim。"
			)

	var sessions: Array[GFProjectileSession] = []
	var capture_session: Callable = func(
		_projectile_root: Node,
		session: GFProjectileSession,
		_launch_input: GFProjectileLaunchInput2D
	) -> void:
		sessions.append(session)
	var _emitted_connected: int = emitter.projectile_emitted.connect(capture_session)
	var second_roots: Array[Node] = emitter.emit_projectiles(
		GFProjectileLaunchInput2D.new(),
		&"",
		3
	)
	assert_eq(second_roots.size(), 3, "同一批 pool roots 必须可在 claim 清理后再次 reserve。")
	assert_eq(sessions.size(), 3)
	assert_eq(pool.acquire_count, 6)
	_finish_projectile_sessions(sessions)
	assert_eq(pool.release_count, 6, "复用后的 ACTIVE leases 也必须各退休恰好一次。")
	for candidate: Node in pool.acquired_nodes:
		if is_instance_valid(candidate):
			candidate.free()


func test_projectile_emitter_keeps_charge_when_consume_finishes_after_activation() -> void:
	var parent: Node2D = Node2D.new()
	add_child_autofree(parent)
	var emitter: GFProjectileEmitter2D = GFProjectileEmitter2D.new()
	parent.add_child(emitter)
	var definition: GFProjectileDefinition2D = _make_projectile_definition_2d()
	var custom_root: Node2D = Node2D.new()
	custom_root.name = &"FinishDuringConsumeRoot"
	var custom_runtime: FinishingConsumeProjectile2D = FinishingConsumeProjectile2D.new()
	custom_runtime.name = &"ProjectileRuntime"
	custom_root.add_child(custom_runtime)
	definition.scene = _pack_projectile_root(custom_root)
	emitter.projectile_definition = definition
	emitter.use_object_pool = true
	var pool: RecordingObjectPool = RecordingObjectPool.new()
	emitter.object_pool_utility = pool
	var policy: GFProjectileEmissionPolicy = GFProjectileEmissionPolicy.new()
	policy.charge_capacity = 4.0
	policy.charge_cost_per_request = 1.0
	policy.charge_cost_per_projectile = 1.0
	policy.reset(0)
	emitter.emission_policy = policy

	var roots: Array[Node] = emitter.emit_projectiles(
		GFProjectileLaunchInput2D.new(),
		&"",
		1
	)
	assert_true(roots.is_empty(), "consume 返回前结束的 session 不得作为成功批次发布。")
	assert_eq(pool.acquire_count, 1)
	assert_eq(pool.release_count, 1, "曾经 ACTIVE 的 pool lease 仍必须恰好一次退休。")
	assert_eq(
		GFVariantData.get_option_int(policy.get_debug_snapshot(0), "emission_count"),
		1,
		"session 一旦离开 UNCONFIGURED，receipt 就不得再补偿。"
	)
	assert_almost_eq(policy.get_available_charges(0), 2.0, 0.0001)
	for candidate: Node in pool.acquired_nodes:
		if is_instance_valid(candidate):
			candidate.free()


func test_projectile_emitter_snapshots_input_per_candidate_and_retires_fresh_roots() -> void:
	var parent: Node2D = Node2D.new()
	add_child_autofree(parent)
	var emitter: GFProjectileEmitter2D = GFProjectileEmitter2D.new()
	parent.add_child(emitter)
	emitter.projectile_definition = _make_projectile_definition_2d()
	var policy: GFProjectileEmissionPolicy = GFProjectileEmissionPolicy.new()
	policy.cooldown_seconds = 5.0
	policy.charge_capacity = 8.0
	policy.charge_cost_per_request = 2.0
	policy.charge_cost_per_projectile = 1.0
	policy.reset(0)
	emitter.emission_policy = policy
	var sessions: Array[GFProjectileSession] = []
	var emitted_inputs: Array[GFProjectileLaunchInput2D] = []
	var on_emitted: Callable = func(
		_projectile_root: Node,
		emitted_session: GFProjectileSession,
		launch_input: GFProjectileLaunchInput2D
	) -> void:
		sessions.append(emitted_session)
		emitted_inputs.append(launch_input)
	var _emitted_connected: int = emitter.projectile_emitted.connect(on_emitted)
	var source_metadata: Dictionary = {
		"nested": {
			"value": 7,
		},
	}
	var input: GFProjectileLaunchInput2D = GFProjectileLaunchInput2D.new()
	input.set_metadata(source_metadata)

	var emitted_roots: Array[Node] = emitter.emit_projectiles(input, &"", 2)
	assert_eq(emitted_roots.size(), 2)
	assert_eq(sessions.size(), 2)
	assert_eq(emitted_inputs.size(), 2)
	if emitted_roots.size() != 2 or sessions.size() != 2 or emitted_inputs.size() != 2:
		for candidate_session: GFProjectileSession in sessions:
			if candidate_session != null and candidate_session.is_active():
				var _cleanup_finished: bool = candidate_session.finish(
					GFProjectileSession.EndReason.CALLER_FINISHED
				)
		for emitted_root: Node in emitted_roots:
			if is_instance_valid(emitted_root) and not emitted_root.is_queued_for_deletion():
				emitted_root.queue_free()
		return
	assert_ne(emitted_inputs[0], input)
	assert_ne(emitted_inputs[1], input)
	assert_ne(emitted_inputs[0], emitted_inputs[1], "每个 candidate 必须持有独立 input snapshot。")
	var mutable_source_nested: Dictionary = GFVariantData.get_option_dictionary(
		source_metadata,
		"nested"
	)
	mutable_source_nested["value"] = 99
	input.set_metadata({ "nested": { "value": 100 } })
	assert_eq(
		GFVariantData.get_option_int(
			GFVariantData.get_option_dictionary(emitted_inputs[0].get_metadata(), "nested"),
			"value"
		),
		7
	)
	assert_eq(
		GFVariantData.get_option_int(
			GFVariantData.get_option_dictionary(sessions[1].get_metadata(), "nested"),
			"value"
		),
		7
	)
	emitted_inputs[0].set_metadata({ "nested": { "value": -1 } })
	assert_eq(
		GFVariantData.get_option_int(
			GFVariantData.get_option_dictionary(emitted_inputs[1].get_metadata(), "nested"),
			"value"
		),
		7,
		"一个 candidate 的 snapshot 变化不得污染另一个 candidate。"
	)

	var exit_count: Array[int] = [0]
	var root_refs: Array[WeakRef] = []
	for emitted_root: Node in emitted_roots:
		root_refs.append(weakref(emitted_root))
		var on_root_exit: Callable = func() -> void:
			exit_count[0] += 1
		var _exit_connected: int = emitted_root.tree_exiting.connect(on_root_exit)
	for candidate_session: GFProjectileSession in sessions:
		assert_true(candidate_session.finish(GFProjectileSession.EndReason.CALLER_FINISHED))
		assert_false(candidate_session.finish(GFProjectileSession.EndReason.INTERNAL_FAILURE))
	assert_almost_eq(policy.get_available_charges(0), 4.0, 0.0001)
	assert_almost_eq(policy.get_remaining_cooldown_seconds(0), 5.0, 0.0001)
	assert_eq(
		GFVariantData.get_option_int(policy.get_debug_snapshot(0), "emission_count"),
		1,
		"ACTIVE 后的正常结束不得补偿 charge/cooldown。"
	)

	await get_tree().process_frame
	await get_tree().process_frame
	for root_ref: WeakRef in root_refs:
		assert_true(root_ref.get_ref() == null)
	assert_eq(exit_count[0], 2, "两个 fresh root 必须各退休恰好一次。")


func test_projectile_emitter_retirement_handoff_blocks_late_finished_relaunch() -> void:
	var parent: Node2D = Node2D.new()
	add_child_autofree(parent)
	var emitter: GFProjectileEmitter2D = GFProjectileEmitter2D.new()
	parent.add_child(emitter)
	var definition: GFProjectileDefinition2D = _make_projectile_definition_2d()
	emitter.projectile_definition = definition
	var sessions: Array[GFProjectileSession] = []
	var late_binding_reason: Array[GFProjectileBinding.FailureReason] = [
		GFProjectileBinding.FailureReason.NONE,
	]
	var late_relaunch: Array[GFProjectileSession] = [null]
	var on_emitted: Callable = func(
		projectile_root: Node,
		session: GFProjectileSession,
		_launch_input: GFProjectileLaunchInput2D
	) -> void:
		sessions.append(session)
		var on_late_finished: Callable = func(
			_finished_session: GFProjectileSession,
			_reason: int
		) -> void:
			var reentry_binding: GFProjectileBinding2D = definition.bind_instance(
				projectile_root
			)
			late_binding_reason[0] = reentry_binding.get_failure_reason()
			if reentry_binding.is_valid():
				var runtime: GFProjectile2D = reentry_binding.get_runtime()
				late_relaunch[0] = runtime.launch(reentry_binding)
		var _late_finished_connected: int = session.finished.connect(on_late_finished)
	var _emitted_connected: int = emitter.projectile_emitted.connect(on_emitted)

	var roots: Array[Node] = emitter.emit_projectiles(
		GFProjectileLaunchInput2D.new(),
		&"",
		1
	)
	assert_eq(roots.size(), 1)
	assert_eq(sessions.size(), 1)
	if roots.is_empty() or sessions.is_empty():
		return
	var root_ref: WeakRef = weakref(roots[0])
	assert_true(sessions[0].finish(GFProjectileSession.EndReason.CALLER_FINISHED))
	assert_true(roots[0].is_queued_for_deletion())
	assert_eq(
		late_binding_reason[0],
		GFProjectileBinding.FailureReason.INVALID_ROOT,
		"emitter retirement 必须先封住 queued root，再进入外部 late finished listener。"
	)
	assert_null(late_relaunch[0])
	await get_tree().process_frame
	await get_tree().process_frame
	assert_true(root_ref.get_ref() == null)


func test_projectile_emitter_releases_active_pool_lease_once_and_keeps_charge() -> void:
	var parent: Node2D = Node2D.new()
	add_child_autofree(parent)
	var emitter: GFProjectileEmitter2D = GFProjectileEmitter2D.new()
	parent.add_child(emitter)
	emitter.projectile_definition = _make_projectile_definition_2d()
	emitter.use_object_pool = true
	var pool: RecordingObjectPool = RecordingObjectPool.new()
	emitter.object_pool_utility = pool
	var policy: GFProjectileEmissionPolicy = GFProjectileEmissionPolicy.new()
	policy.cooldown_seconds = 5.0
	policy.charge_capacity = 4.0
	policy.charge_cost_per_request = 1.0
	policy.charge_cost_per_projectile = 1.0
	policy.reset(0)
	emitter.emission_policy = policy
	var sessions: Array[GFProjectileSession] = []
	var on_emitted: Callable = func(
		_projectile_root: Node,
		session: GFProjectileSession,
		_launch_input: GFProjectileLaunchInput2D
	) -> void:
		sessions.append(session)
	var _emitted_connected: int = emitter.projectile_emitted.connect(on_emitted)

	var emitted_roots: Array[Node] = emitter.emit_projectiles(
		GFProjectileLaunchInput2D.new(),
		&"",
		1
	)
	assert_eq(emitted_roots.size(), 1)
	assert_eq(sessions.size(), 1)
	if emitted_roots.is_empty() or sessions.is_empty():
		for candidate: Node in pool.acquired_nodes:
			if is_instance_valid(candidate):
				candidate.free()
		return
	assert_eq(pool.acquire_count, 1)
	assert_eq(pool.release_count, 0)
	assert_true(sessions[0].finish(GFProjectileSession.EndReason.CALLER_FINISHED))
	assert_false(sessions[0].finish(GFProjectileSession.EndReason.INTERNAL_FAILURE))
	assert_eq(pool.release_count, 1, "terminal callback 必须恰好一次归还 pool lease。")
	assert_same(pool.released_nodes[0], emitted_roots[0])
	assert_almost_eq(policy.get_available_charges(0), 2.0, 0.0001)
	assert_almost_eq(policy.get_remaining_cooldown_seconds(0), 5.0, 0.0001)
	assert_eq(
		GFVariantData.get_option_int(policy.get_debug_snapshot(0), "emission_count"),
		1
	)
	for candidate: Node in pool.acquired_nodes:
		if is_instance_valid(candidate):
			candidate.free()


func test_projectile_emitter_exit_finishes_sessions_and_releases_pool_leases_once() -> void:
	var parent: Node2D = Node2D.new()
	add_child_autofree(parent)
	var emitter: GFProjectileEmitter2D = GFProjectileEmitter2D.new()
	parent.add_child(emitter)
	emitter.projectile_definition = _make_projectile_definition_2d()
	emitter.use_object_pool = true
	var pool: RecordingObjectPool = RecordingObjectPool.new()
	emitter.object_pool_utility = pool
	var policy: GFProjectileEmissionPolicy = GFProjectileEmissionPolicy.new()
	policy.charge_capacity = 8.0
	policy.charge_cost_per_request = 2.0
	policy.charge_cost_per_projectile = 1.0
	policy.reset(0)
	emitter.emission_policy = policy
	var sessions: Array[GFProjectileSession] = []
	var capture_session: Callable = func(
		_projectile_root: Node,
		session: GFProjectileSession,
		_launch_input: GFProjectileLaunchInput2D
	) -> void:
		sessions.append(session)
	var _emitted_connected: int = emitter.projectile_emitted.connect(capture_session)

	var roots: Array[Node] = emitter.emit_projectiles(
		GFProjectileLaunchInput2D.new(),
		&"",
		2
	)
	assert_eq(roots.size(), 2)
	assert_eq(sessions.size(), 2)
	assert_eq(pool.release_count, 0)
	var runtimes: Array[GFProjectile2D] = []
	for root: Node in roots:
		var runtime: GFProjectile2D = _runtime_2d_from(root)
		assert_not_null(runtime)
		if runtime != null:
			runtimes.append(runtime)
	parent.remove_child(emitter)
	assert_eq(
		pool.release_count,
		0,
		"Emitter exit 必须先结算 session，并将 allocator handoff 延迟到 tree lock 之后。"
	)
	for session: GFProjectileSession in sessions:
		assert_true(session.is_finished())
		assert_eq(
			session.get_end_reason(),
			GFProjectileSession.EndReason.EMITTER_RELEASED
		)
		assert_false(session.finish(GFProjectileSession.EndReason.INTERNAL_FAILURE))
	for runtime: GFProjectile2D in runtimes:
		assert_true(
			runtime.has_launch_claim_for_framework(),
			"allocator handoff 前必须保留 terminal claim，阻止 finished 回调复用 root。"
		)
	await get_tree().process_frame
	assert_eq(pool.release_count, 2, "离开 tree lock 后必须恰好一次归还全部 leases。")
	for runtime: GFProjectile2D in runtimes:
		assert_false(
			runtime.has_launch_claim_for_framework(),
			"allocator handoff 完成后必须释放 terminal claim。"
		)
	assert_almost_eq(policy.get_available_charges(0), 4.0, 0.0001)
	assert_eq(
		GFVariantData.get_option_int(policy.get_debug_snapshot(0), "emission_count"),
		1,
		"ACTIVE 后 emitter exit 不得补偿已提交 charge/cooldown。"
	)
	parent.add_child(emitter)
	var reused_roots: Array[Node] = emitter.emit_projectiles(
		GFProjectileLaunchInput2D.new(),
		&"",
		1
	)
	assert_false(reused_roots.is_empty(), "重新入树后 emitter 必须可开始新的独立批次。")
	if sessions.size() == 3:
		var _reused_finished: bool = sessions[2].finish(
			GFProjectileSession.EndReason.CALLER_FINISHED
		)
	for candidate: Node in pool.acquired_nodes:
		if is_instance_valid(candidate):
			candidate.free()


func test_projectile_definition_uses_explicit_hit_box_hit_scan_union() -> void:
	var root_2d: Node2D = _make_bound_projectile_root_2d([&"HitBox"])
	var scan_2d: GFHitScan2D = GFHitScan2D.new()
	scan_2d.name = &"HitScan"
	root_2d.add_child(scan_2d)
	add_child_autofree(root_2d)
	var paths: Array[NodePath] = [NodePath("HitBox"), NodePath("HitScan")]
	var definition_2d: GFProjectileDefinition2D = _make_projectile_definition_2d(paths)
	var binding_2d: GFProjectileBinding2D = definition_2d.bind_instance(root_2d)
	assert_true(binding_2d.is_valid(), "2D Definition 应显式接受 HitBox/HitScan union。")
	assert_true(binding_2d.get_impact_sources()[0] is GFHitBox2D)
	assert_true(binding_2d.get_impact_sources()[1] is GFHitScan2D)
	var session_2d: GFProjectileSession = _runtime_2d_from(root_2d).launch(binding_2d)
	var context_2d: GFCombatHitContext = GFCombatHitContext.new()
	var receiver_2d: HitReceiver2D = HitReceiver2D.new()
	add_child_autofree(receiver_2d)
	var hit_box_2d: GFHitBox2D = _hit_box_2d_from(root_2d, NodePath("HitBox"))
	hit_box_2d.hit_accepted.emit(context_2d, receiver_2d, { "ok": true })
	scan_2d.hit_accepted.emit(context_2d, receiver_2d, { "ok": true })
	assert_eq(session_2d.get_accepted_impact_count(), 2)

	var root_3d: Node3D = _make_bound_projectile_root_3d([&"HitBox"])
	var scan_3d: GFHitScan3D = GFHitScan3D.new()
	scan_3d.name = &"HitScan"
	root_3d.add_child(scan_3d)
	add_child_autofree(root_3d)
	var definition_3d: GFProjectileDefinition3D = _make_projectile_definition_3d(paths)
	var binding_3d: GFProjectileBinding3D = definition_3d.bind_instance(root_3d)
	assert_true(binding_3d.is_valid(), "3D Definition 应与 2D 对称接受 typed union。")
	assert_true(binding_3d.get_impact_sources()[0] is GFHitBox3D)
	assert_true(binding_3d.get_impact_sources()[1] is GFHitScan3D)
	var session_3d: GFProjectileSession = _runtime_3d_from(root_3d).launch(binding_3d)
	var context_3d: GFCombatHitContext = GFCombatHitContext.new()
	var receiver_3d: Node3D = Node3D.new()
	add_child_autofree(receiver_3d)
	var hit_box_3d: GFHitBox3D = _hit_box_3d_from(root_3d, NodePath("HitBox"))
	hit_box_3d.hit_accepted.emit(context_3d, receiver_3d, { "ok": true })
	scan_3d.hit_accepted.emit(context_3d, receiver_3d, { "ok": true })
	assert_eq(session_3d.get_accepted_impact_count(), 2)

	var duck_root: Node2D = _make_bound_projectile_root_2d()
	var duck_source: DuckImpactSource2D = DuckImpactSource2D.new()
	duck_source.name = &"DuckImpact"
	duck_root.add_child(duck_source)
	add_child_autofree(duck_root)
	duck_source.emit_hit_for_test(GFCombatHitContext.new(), duck_root, { "ok": true })
	var duck_definition: GFProjectileDefinition2D = _make_projectile_definition_2d(
		[NodePath("DuckImpact")]
	)
	var duck_binding: GFProjectileBinding2D = duck_definition.bind_instance(duck_root)
	assert_false(duck_binding.is_valid(), "同名 signal 的 duck source 不得绕过 typed union。")
	assert_eq(
		duck_binding.get_failure_reason(),
		GFProjectileBinding.FailureReason.INVALID_IMPACT_SOURCE
	)
	var _finished_2d: bool = session_2d.finish(GFProjectileSession.EndReason.CALLER_FINISHED)
	var _finished_3d: bool = session_3d.finish(GFProjectileSession.EndReason.CALLER_FINISHED)


func test_projectile_definition_rejects_hidden_opposite_dimension_runtime() -> void:
	var root_2d: Node2D = _make_bound_projectile_root_2d()
	var nested_2d: Node = Node.new()
	nested_2d.name = &"Nested"
	root_2d.add_child(nested_2d)
	var hidden_3d: GFProjectile3D = GFProjectile3D.new()
	hidden_3d.name = &"Hidden3D"
	nested_2d.add_child(hidden_3d)
	add_child_autofree(root_2d)
	var binding_2d: GFProjectileBinding2D = (
		_make_projectile_definition_2d().bind_instance(root_2d)
	)
	assert_false(binding_2d.is_valid())
	assert_eq(
		binding_2d.get_failure_reason(),
		GFProjectileBinding.FailureReason.AMBIGUOUS_RUNTIME
	)

	var root_3d: Node3D = _make_bound_projectile_root_3d()
	var nested_3d: Node = Node.new()
	nested_3d.name = &"Nested"
	root_3d.add_child(nested_3d)
	var hidden_2d: GFProjectile2D = GFProjectile2D.new()
	hidden_2d.name = &"Hidden2D"
	nested_3d.add_child(hidden_2d)
	add_child_autofree(root_3d)
	var binding_3d: GFProjectileBinding3D = (
		_make_projectile_definition_3d().bind_instance(root_3d)
	)
	assert_false(binding_3d.is_valid())
	assert_eq(
		binding_3d.get_failure_reason(),
		GFProjectileBinding.FailureReason.AMBIGUOUS_RUNTIME
	)


func test_projectile_binding_freezes_declaration_and_active_session_snapshot() -> void:
	var stale_root: Node2D = _make_bound_projectile_root_2d()
	add_child_autofree(stale_root)
	var stale_definition: GFProjectileDefinition2D = _make_projectile_definition_2d()
	var stale_binding: GFProjectileBinding2D = stale_definition.bind_instance(stale_root)
	assert_true(stale_binding.is_valid())
	stale_definition.runtime_path = NodePath("ChangedRuntime")
	assert_false(stale_binding.is_current())
	assert_eq(
		stale_binding.get_failure_reason(),
		GFProjectileBinding.FailureReason.STALE_BINDING
	)
	assert_null(_runtime_2d_from(stale_root).launch(stale_binding))

	var active_root: Node2D = _make_bound_projectile_root_2d()
	add_child_autofree(active_root)
	var active_definition: GFProjectileDefinition2D = _make_projectile_definition_2d()
	var frozen_motion: GFLinearProjectileMotion = GFLinearProjectileMotion.new()
	frozen_motion.speed = 4.0
	frozen_motion.use_local_direction = false
	frozen_motion.direction_2d = Vector2.RIGHT
	active_definition.motion = frozen_motion
	var active_binding: GFProjectileBinding2D = active_definition.bind_instance(active_root)
	var runtime: GFProjectile2D = _runtime_2d_from(active_root)
	var session: GFProjectileSession = runtime.launch(active_binding)
	assert_not_null(session)
	active_definition.scene = _make_projectile_definition_2d().scene
	active_definition.runtime_path = NodePath("ChangedRuntime")
	active_definition.impact_source_paths = [NodePath("ChangedImpact")]
	active_definition.motion = GFLinearProjectileMotion.new()
	active_definition.lifetime_policy = GFProjectileLifetimePolicy.new()
	active_definition.body_adapter = GFProjectileTransformBodyAdapter2D.new()
	runtime._physics_process(0.5)
	assert_eq(active_root.position, Vector2(2.0, 0.0))
	assert_true(session.is_active(), "ACTIVE session 必须继续使用 bind/launch 时冻结的策略。")
	var _active_finished: bool = session.finish(
		GFProjectileSession.EndReason.CALLER_FINISHED
	)


func test_projectile_motion_state_and_reservation_failures_have_real_producers() -> void:
	var state_root: Node2D = _make_bound_projectile_root_2d()
	add_child_autofree(state_root)
	var state_definition: GFProjectileDefinition2D = _make_projectile_definition_2d()
	state_definition.motion = InvalidStateMotion.new()
	var state_binding: GFProjectileBinding2D = state_definition.bind_instance(state_root)
	assert_true(state_binding.is_valid())
	assert_null(_runtime_2d_from(state_root).launch(state_binding))
	assert_eq(
		state_binding.get_failure_reason(),
		GFProjectileBinding.FailureReason.MOTION_STATE_CREATION_FAILED
	)

	var reservation_root: Node2D = _make_bound_projectile_root_2d()
	add_child_autofree(reservation_root)
	var reservation_definition: GFProjectileDefinition2D = _make_projectile_definition_2d()
	var reservation_binding: GFProjectileBinding2D = (
		reservation_definition.bind_instance(reservation_root)
	)
	var retirement_owner: Node = Node.new()
	add_child_autofree(retirement_owner)
	var reservation_runtime: GFProjectile2D = _runtime_2d_from(reservation_root)
	var reservation: GFProjectileLaunchReservation = (
		reservation_runtime.reserve_launch_for_framework(
			reservation_binding,
			GFProjectileLaunchInput2D.new(),
			retirement_owner
		)
	)
	reservation_root.remove_child(reservation_runtime)
	assert_ne(reservation.arm_for_framework(retirement_owner), OK)
	assert_eq(
		reservation_binding.get_failure_reason(),
		GFProjectileBinding.FailureReason.RESERVATION_INVALIDATED
	)
	reservation_runtime.free()


func test_projectile_runtime_owns_motion_state_for_exactly_one_generation() -> void:
	var root_2d: Node2D = _make_bound_projectile_root_2d()
	add_child_autofree(root_2d)
	var definition_2d: GFProjectileDefinition2D = _make_projectile_definition_2d()
	var motion_2d: TrackingMotionStateLifecycle = TrackingMotionStateLifecycle.new()
	definition_2d.motion = motion_2d
	var binding_2d: GFProjectileBinding2D = definition_2d.bind_instance(root_2d)
	var runtime_2d: GFProjectile2D = _runtime_2d_from(root_2d)
	var first_session: GFProjectileSession = runtime_2d.launch(binding_2d)
	assert_not_null(first_session)
	assert_eq(motion_2d.state_refs.size(), 1)
	if first_session == null or motion_2d.state_refs.size() != 1:
		return
	var first_ref: WeakRef = motion_2d.state_refs[0]
	assert_true(
		_weakref_points_to_live_motion_state(first_ref),
		"ACTIVE 2D runtime 必须强持有当前 generation 的 MotionState。"
	)
	var first_state_value: Variant = first_ref.get_ref()
	assert_true(first_state_value is GFProjectileMotionState)
	if not first_state_value is GFProjectileMotionState:
		return
	var external_state: GFProjectileMotionState = first_state_value
	var first_state_id: int = external_state.get_instance_id()
	first_state_value = null
	runtime_2d._physics_process(0.1)
	assert_eq(motion_2d.computed_state_ids, [first_state_id])
	var _first_finished: bool = first_session.finish(
		GFProjectileSession.EndReason.CALLER_FINISHED
	)
	assert_null(runtime_2d.get_active_session())
	assert_true(
		_weakref_points_to_live_motion_state(first_ref),
		"外部 RefCounted 引用可以保留对象，但不得保留 runtime generation。"
	)

	var second_binding: GFProjectileBinding2D = definition_2d.bind_instance(root_2d)
	var second_session: GFProjectileSession = runtime_2d.launch(second_binding)
	assert_not_null(second_session)
	assert_eq(motion_2d.state_refs.size(), 2)
	if second_session == null or motion_2d.state_refs.size() != 2:
		return
	var second_ref: WeakRef = motion_2d.state_refs[1]
	var second_state_value: Variant = second_ref.get_ref()
	assert_true(second_state_value is GFProjectileMotionState)
	if not second_state_value is GFProjectileMotionState:
		return
	var second_state: GFProjectileMotionState = second_state_value
	var second_state_id: int = second_state.get_instance_id()
	second_state_value = null
	second_state = null
	assert_ne(second_state_id, first_state_id, "新 generation 必须创建独立 MotionState。")
	runtime_2d._physics_process(0.1)
	assert_false(motion_2d.computed_state_ids.is_empty())
	if not motion_2d.computed_state_ids.is_empty():
		var last_state_id: int = motion_2d.computed_state_ids[
			motion_2d.computed_state_ids.size() - 1
		]
		assert_eq(last_state_id, second_state_id)
	var _second_finished: bool = second_session.finish(
		GFProjectileSession.EndReason.CALLER_FINISHED
	)
	assert_eq(typeof(second_ref.get_ref()), TYPE_NIL)
	external_state = null
	assert_eq(typeof(first_ref.get_ref()), TYPE_NIL)

	var root_3d: Node3D = _make_bound_projectile_root_3d()
	add_child_autofree(root_3d)
	var definition_3d: GFProjectileDefinition3D = _make_projectile_definition_3d()
	var motion_3d: TrackingMotionStateLifecycle = TrackingMotionStateLifecycle.new()
	definition_3d.motion = motion_3d
	var binding_3d: GFProjectileBinding3D = definition_3d.bind_instance(root_3d)
	var runtime_3d: GFProjectile3D = _runtime_3d_from(root_3d)
	var session_3d: GFProjectileSession = runtime_3d.launch(binding_3d)
	assert_not_null(session_3d)
	assert_eq(motion_3d.state_refs.size(), 1)
	if session_3d == null or motion_3d.state_refs.size() != 1:
		return
	var state_ref_3d: WeakRef = motion_3d.state_refs[0]
	assert_true(_weakref_points_to_live_motion_state(state_ref_3d))
	runtime_3d._physics_process(0.1)
	var _finished_3d: bool = session_3d.finish(
		GFProjectileSession.EndReason.CALLER_FINISHED
	)
	assert_eq(typeof(state_ref_3d.get_ref()), TYPE_NIL)


func test_projectile_runtime_releases_motion_state_after_prepare_failure() -> void:
	var root_2d: Node2D = _make_bound_projectile_root_2d()
	add_child_autofree(root_2d)
	var definition_2d: GFProjectileDefinition2D = _make_projectile_definition_2d()
	var motion_2d: TrackingMotionStateLifecycle = TrackingMotionStateLifecycle.new()
	motion_2d.invalidate_definition_2d = definition_2d
	definition_2d.motion = motion_2d
	var binding_2d: GFProjectileBinding2D = definition_2d.bind_instance(root_2d)
	var failed_session_2d: GFProjectileSession = _runtime_2d_from(root_2d).launch(binding_2d)
	motion_2d.invalidate_definition_2d = null
	assert_null(failed_session_2d)
	assert_eq(motion_2d.state_refs.size(), 1)
	if motion_2d.state_refs.size() == 1:
		assert_eq(
			typeof(motion_2d.state_refs[0].get_ref()),
			TYPE_NIL,
			"2D prepare 失败后 runtime 必须释放未激活 MotionState。"
		)

	var root_3d: Node3D = _make_bound_projectile_root_3d()
	add_child_autofree(root_3d)
	var definition_3d: GFProjectileDefinition3D = _make_projectile_definition_3d()
	var motion_3d: TrackingMotionStateLifecycle = TrackingMotionStateLifecycle.new()
	motion_3d.invalidate_definition_3d = definition_3d
	definition_3d.motion = motion_3d
	var binding_3d: GFProjectileBinding3D = definition_3d.bind_instance(root_3d)
	var failed_session_3d: GFProjectileSession = _runtime_3d_from(root_3d).launch(binding_3d)
	motion_3d.invalidate_definition_3d = null
	assert_null(failed_session_3d)
	assert_eq(motion_3d.state_refs.size(), 1)
	if motion_3d.state_refs.size() == 1:
		assert_eq(
			typeof(motion_3d.state_refs[0].get_ref()),
			TYPE_NIL,
			"3D prepare 失败后 runtime 必须释放未激活 MotionState。"
		)


func test_projectile_body_results_reject_non_finite_values_symmetrically() -> void:
	var invalid_transform_2d: Transform2D = Transform2D.IDENTITY
	invalid_transform_2d.origin.x = NAN
	var result_2d: GFProjectileBodyResult2D = GFProjectileBodyResult2D.successful(
		invalid_transform_2d,
		Vector2.ZERO
	)
	assert_false(result_2d.is_successful())
	assert_eq(result_2d.get_failure_reason(), &"non_finite_body_result")
	assert_false(
		GFProjectileBodyResult2D.successful(
			Transform2D.IDENTITY,
			Vector2(INF, 0.0)
		).is_successful()
	)
	var invalid_transform_3d: Transform3D = Transform3D.IDENTITY
	invalid_transform_3d.origin.z = -INF
	var result_3d: GFProjectileBodyResult3D = GFProjectileBodyResult3D.successful(
		invalid_transform_3d,
		Vector3.ZERO
	)
	assert_false(result_3d.is_successful())
	assert_eq(result_3d.get_failure_reason(), &"non_finite_body_result")
	assert_false(
		GFProjectileBodyResult3D.successful(
			Transform3D.IDENTITY,
			Vector3(0.0, NAN, 0.0)
		).is_successful()
	)


func test_projectile_apply_finish_counts_last_displacement_once_in_both_dimensions() -> void:
	var root_2d: Node2D = _make_bound_projectile_root_2d()
	add_child_autofree(root_2d)
	var definition_2d: GFProjectileDefinition2D = _make_projectile_definition_2d()
	var adapter_2d: FinishingApplyAdapter2D = FinishingApplyAdapter2D.new()
	definition_2d.body_adapter = adapter_2d
	var binding_2d: GFProjectileBinding2D = definition_2d.bind_instance(root_2d)
	var runtime_2d: GFProjectile2D = _runtime_2d_from(root_2d)
	var session_2d: GFProjectileSession = runtime_2d.launch(binding_2d)
	adapter_2d.active_session = session_2d
	runtime_2d._physics_process(0.25)
	assert_true(session_2d.is_finished())
	assert_almost_eq(session_2d.get_elapsed_seconds(), 0.25, 0.0001)
	assert_almost_eq(session_2d.get_travelled_distance(), 5.0, 0.0001)
	runtime_2d._physics_process(0.25)
	assert_eq(adapter_2d.apply_count, 1)
	assert_almost_eq(session_2d.get_travelled_distance(), 5.0, 0.0001)
	adapter_2d.active_session = null

	var root_3d: Node3D = _make_bound_projectile_root_3d()
	add_child_autofree(root_3d)
	var definition_3d: GFProjectileDefinition3D = _make_projectile_definition_3d()
	var adapter_3d: FinishingApplyAdapter3D = FinishingApplyAdapter3D.new()
	definition_3d.body_adapter = adapter_3d
	var binding_3d: GFProjectileBinding3D = definition_3d.bind_instance(root_3d)
	var runtime_3d: GFProjectile3D = _runtime_3d_from(root_3d)
	var session_3d: GFProjectileSession = runtime_3d.launch(binding_3d)
	adapter_3d.active_session = session_3d
	runtime_3d._physics_process(0.5)
	assert_true(session_3d.is_finished())
	assert_almost_eq(session_3d.get_elapsed_seconds(), 0.5, 0.0001)
	assert_almost_eq(session_3d.get_travelled_distance(), 7.0, 0.0001)
	runtime_3d._physics_process(0.5)
	assert_eq(adapter_3d.apply_count, 1)
	assert_almost_eq(session_3d.get_travelled_distance(), 7.0, 0.0001)
	adapter_3d.active_session = null


func test_projectile_finish_intent_maps_to_motion_finished_symmetrically() -> void:
	assert_eq(GFProjectileMotionIntent2D.Kind.FINISH, 3)
	assert_eq(GFProjectileMotionIntent3D.Kind.FINISH, 3)
	assert_eq(GFProjectileMotionIntent2D.finish().get_kind(), 3)
	assert_eq(GFProjectileMotionIntent3D.finish().get_kind(), 3)
	var root_2d: Node2D = _make_bound_projectile_root_2d()
	add_child_autofree(root_2d)
	var definition_2d: GFProjectileDefinition2D = _make_projectile_definition_2d()
	definition_2d.motion = FinishingMotion.new()
	var binding_2d: GFProjectileBinding2D = definition_2d.bind_instance(root_2d)
	var session_2d: GFProjectileSession = _runtime_2d_from(root_2d).launch(binding_2d)
	_runtime_2d_from(root_2d)._physics_process(0.5)
	assert_true(session_2d.is_finished())
	assert_eq(session_2d.get_end_reason(), GFProjectileSession.EndReason.MOTION_FINISHED)
	assert_eq(root_2d.position, Vector2.ZERO)

	var root_3d: Node3D = _make_bound_projectile_root_3d()
	add_child_autofree(root_3d)
	var definition_3d: GFProjectileDefinition3D = _make_projectile_definition_3d()
	definition_3d.motion = FinishingMotion.new()
	var binding_3d: GFProjectileBinding3D = definition_3d.bind_instance(root_3d)
	var session_3d: GFProjectileSession = _runtime_3d_from(root_3d).launch(binding_3d)
	_runtime_3d_from(root_3d)._physics_process(0.5)
	assert_true(session_3d.is_finished())
	assert_eq(session_3d.get_end_reason(), GFProjectileSession.EndReason.MOTION_FINISHED)
	assert_eq(root_3d.position, Vector3.ZERO)


func test_projectile_active_lifetime_keeps_and_releases_strong_launch_snapshot() -> void:
	var source_paths: Array[NodePath] = [NodePath("Impact")]
	var root: Node2D = _make_bound_projectile_root_2d([&"Impact"])
	add_child_autofree(root)
	var definition: GFProjectileDefinition2D = _make_projectile_definition_2d(source_paths)
	var lifetime: GFProjectileLifetimePolicy = GFProjectileLifetimePolicy.new()
	lifetime.max_impacts = 1
	definition.lifetime_policy = lifetime
	var binding: GFProjectileBinding2D = definition.bind_instance(root)
	var session: GFProjectileSession = _runtime_2d_from(root).launch(binding)
	var lifetime_ref: WeakRef = weakref(lifetime)
	var replacement: GFProjectileLifetimePolicy = GFProjectileLifetimePolicy.new()
	replacement.max_impacts = 99
	definition.lifetime_policy = replacement
	definition.lifetime_policy = null
	binding = null
	lifetime = null
	assert_true(
		_weakref_points_to_live_lifetime(lifetime_ref),
		"ACTIVE runtime 必须强持有 launch-time lifetime snapshot。"
	)
	var source: GFHitBox2D = _hit_box_2d_from(root, NodePath("Impact"))
	var receiver: HitReceiver2D = HitReceiver2D.new()
	add_child_autofree(receiver)
	source.hit_accepted.emit(GFCombatHitContext.new(), receiver, { "ok": true })
	assert_true(session.is_finished(), "Impact 必须使用 launch 时冻结的 lifetime。")
	assert_eq(session.get_end_reason(), GFProjectileSession.EndReason.LIFETIME_IMPACTS)
	assert_eq(
		typeof(lifetime_ref.get_ref()),
		TYPE_NIL,
		"session 终态清理后 runtime 不得继续保留 lifetime snapshot。"
	)


func test_projectile_motion_rejects_non_finite_configuration_and_locked_target_keeps_flying() -> void:
	var initial_2d: GFProjectileBodyResult2D = GFProjectileBodyResult2D.successful(
		Transform2D.IDENTITY
	)
	var input_2d: GFProjectileLaunchInput2D = GFProjectileLaunchInput2D.new()
	input_2d.set_target_position(Vector2(10.0, 0.0))
	var linear: GFLinearProjectileMotion = GFLinearProjectileMotion.new()
	linear.speed = NAN
	assert_null(linear.create_state_2d(input_2d, initial_2d))
	linear.speed = 1.0
	linear.direction_2d = Vector2(INF, 0.0)
	assert_null(linear.create_state_2d(input_2d, initial_2d))
	var homing: GFHomingProjectileMotion = GFHomingProjectileMotion.new()
	homing.speed = 1.0
	homing.arrival_distance = INF
	assert_null(homing.create_state_2d(input_2d, initial_2d))

	var root: Node2D = _make_bound_projectile_root_2d()
	add_child_autofree(root)
	var target: Node2D = Node2D.new()
	target.position = Vector2(10.0, 0.0)
	var definition: GFProjectileDefinition2D = _make_projectile_definition_2d()
	var locked_motion: GFHomingProjectileMotion = GFHomingProjectileMotion.new()
	locked_motion.speed = 10.0
	locked_motion.track_target = false
	locked_motion.stop_when_reached = true
	definition.motion = locked_motion
	var binding: GFProjectileBinding2D = definition.bind_instance(root)
	var launch_input: GFProjectileLaunchInput2D = GFProjectileLaunchInput2D.new()
	launch_input.set_target_node(target)
	var runtime: GFProjectile2D = _runtime_2d_from(root)
	var session: GFProjectileSession = runtime.launch(binding, launch_input)
	target.free()
	runtime._physics_process(1.0)
	runtime._physics_process(0.5)
	assert_eq(root.position, Vector2(15.0, 0.0), "目标丢失后不得再按旧位置 clamp。")
	assert_true(session.is_active())
	var _finished: bool = session.finish(GFProjectileSession.EndReason.CALLER_FINISHED)


func test_projectile_catalog_prune_keeps_first_valid_definition() -> void:
	var catalog: GFProjectileCatalog = GFProjectileCatalog.new()
	var first_entry: GFProjectileCatalogEntry = GFProjectileCatalogEntry.new()
	first_entry.projectile_id = &"shared"
	first_entry.definition = _make_projectile_definition_2d()
	var duplicate_entry: GFProjectileCatalogEntry = GFProjectileCatalogEntry.new()
	duplicate_entry.projectile_id = &"shared"
	duplicate_entry.definition = _make_projectile_definition_3d()
	catalog.entries = [first_entry, duplicate_entry]
	assert_eq(catalog.prune_invalid_entries(), 1)
	assert_eq(catalog.entries.size(), 1)
	assert_same(catalog.entries[0], first_entry)
	assert_same(catalog.get_definition(&"shared"), first_entry.definition)


func test_projectile_publication_fences_receipt_started_and_emitted_callbacks() -> void:
	var receipt_parent: Node2D = Node2D.new()
	add_child_autofree(receipt_parent)
	var receipt_emitter: GFProjectileEmitter2D = GFProjectileEmitter2D.new()
	receipt_parent.add_child(receipt_emitter)
	receipt_emitter.projectile_definition = _make_projectile_definition_2d(
		[NodePath("Impact")]
	)
	receipt_emitter.emission_policy = InvalidatingCommitPolicy.new()
	var receipt_roots: Array[Node] = receipt_emitter.emit_projectiles(
		GFProjectileLaunchInput2D.new(),
		&"",
		1
	)
	assert_true(receipt_roots.is_empty(), "receipt hook 破坏 source 后必须 fail-close。")

	var started_parent: Node2D = Node2D.new()
	add_child_autofree(started_parent)
	var started_emitter: GFProjectileEmitter2D = GFProjectileEmitter2D.new()
	started_parent.add_child(started_emitter)
	started_emitter.projectile_definition = _make_projectile_definition_2d(
		[NodePath("Impact")]
	)
	var connect_started: Callable = func(candidate: Node) -> void:
		var runtime: GFProjectile2D = _runtime_2d_from(candidate)
		if runtime == null:
			return
		var invalidate_source: Callable = func(_session: GFProjectileSession) -> void:
			var source: Node = candidate.get_node_or_null(NodePath("Impact"))
			if source != null:
				candidate.remove_child(source)
				source.free()
		var _connected: int = runtime.projectile_started.connect(invalidate_source)
	var _child_connected: int = started_parent.child_entered_tree.connect(connect_started)
	var started_roots: Array[Node] = started_emitter.emit_projectiles(
		GFProjectileLaunchInput2D.new(),
		&"",
		1
	)
	started_parent.child_entered_tree.disconnect(connect_started)
	assert_true(started_roots.is_empty(), "started callback 后必须复核 frozen topology。")

	var emitted_parent: Node3D = Node3D.new()
	add_child_autofree(emitted_parent)
	var emitted_emitter: GFProjectileEmitter3D = GFProjectileEmitter3D.new()
	emitted_parent.add_child(emitted_emitter)
	emitted_emitter.projectile_definition = _make_projectile_definition_3d(
		[NodePath("Impact")]
	)
	var invalidate_emitted: Callable = func(
		projectile_root: Node,
		_session: GFProjectileSession,
		_launch_input: GFProjectileLaunchInput3D
	) -> void:
		var source: Node = projectile_root.get_node_or_null(NodePath("Impact"))
		if source != null:
			projectile_root.remove_child(source)
			source.free()
	var _emitted_connected: int = emitted_emitter.projectile_emitted.connect(
		invalidate_emitted
	)
	var emitted_roots: Array[Node] = emitted_emitter.emit_projectiles(
		GFProjectileLaunchInput3D.new(),
		&"",
		1
	)
	assert_true(emitted_roots.is_empty(), "emitted callback 后必须复核 3D source ownership。")


func test_projectile_retirement_survives_emitter_and_root_tree_exit() -> void:
	var parent_2d: Node2D = Node2D.new()
	add_child_autofree(parent_2d)
	var emitter_2d: GFProjectileEmitter2D = GFProjectileEmitter2D.new()
	parent_2d.add_child(emitter_2d)
	emitter_2d.projectile_definition = _make_projectile_definition_2d()
	emitter_2d.use_object_pool = true
	var pool_2d: RecordingObjectPool = RecordingObjectPool.new()
	emitter_2d.object_pool_utility = pool_2d
	var sessions_2d: Array[GFProjectileSession] = []
	var capture_2d: Callable = func(
		_projectile_root: Node,
		session: GFProjectileSession,
		_launch_input: GFProjectileLaunchInput2D
	) -> void:
		sessions_2d.append(session)
	var _capture_2d_connected: int = emitter_2d.projectile_emitted.connect(capture_2d)
	var roots_2d: Array[Node] = emitter_2d.emit_projectiles(
		GFProjectileLaunchInput2D.new(),
		&"",
		1
	)
	assert_eq(roots_2d.size(), 1)
	assert_eq(sessions_2d.size(), 1)
	if roots_2d.is_empty() or sessions_2d.is_empty():
		return
	var runtime_2d: GFProjectile2D = _runtime_2d_from(roots_2d[0])
	parent_2d.remove_child(roots_2d[0])
	assert_true(sessions_2d[0].is_finished())
	assert_eq(sessions_2d[0].get_end_reason(), GFProjectileSession.EndReason.ROOT_LOST)
	assert_true(runtime_2d.has_launch_claim_for_framework())
	await get_tree().process_frame
	assert_eq(pool_2d.release_count, 1)
	assert_false(runtime_2d.has_launch_claim_for_framework())

	var parent_3d: Node3D = Node3D.new()
	add_child_autofree(parent_3d)
	var emitter_3d: GFProjectileEmitter3D = GFProjectileEmitter3D.new()
	parent_3d.add_child(emitter_3d)
	emitter_3d.projectile_definition = _make_projectile_definition_3d()
	emitter_3d.use_object_pool = true
	var pool_3d: RecordingObjectPool = RecordingObjectPool.new()
	emitter_3d.object_pool_utility = pool_3d
	var sessions_3d: Array[GFProjectileSession] = []
	var capture_3d: Callable = func(
		_projectile_root: Node,
		session: GFProjectileSession,
		_launch_input: GFProjectileLaunchInput3D
	) -> void:
		sessions_3d.append(session)
	var _capture_3d_connected: int = emitter_3d.projectile_emitted.connect(capture_3d)
	var roots_3d: Array[Node] = emitter_3d.emit_projectiles(
		GFProjectileLaunchInput3D.new(),
		&"",
		1
	)
	assert_eq(roots_3d.size(), 1)
	assert_eq(sessions_3d.size(), 1)
	if roots_3d.is_empty() or sessions_3d.is_empty():
		return
	var runtime_3d: GFProjectile3D = _runtime_3d_from(roots_3d[0])
	parent_3d.remove_child(emitter_3d)
	assert_true(sessions_3d[0].is_finished())
	assert_eq(
		sessions_3d[0].get_end_reason(),
		GFProjectileSession.EndReason.EMITTER_RELEASED
	)
	assert_true(runtime_3d.has_launch_claim_for_framework())
	emitter_3d.free()
	await get_tree().process_frame
	assert_eq(pool_3d.release_count, 1)
	assert_false(runtime_3d.has_launch_claim_for_framework())
	for candidate: Node in pool_2d.acquired_nodes:
		if is_instance_valid(candidate):
			candidate.free()
	for candidate: Node in pool_3d.acquired_nodes:
		if is_instance_valid(candidate):
			candidate.free()


func test_projectile_external_root_free_retires_fresh_and_pool_roots_in_both_dimensions() -> void:
	var parent_2d: Node2D = Node2D.new()
	add_child_autofree(parent_2d)
	var fresh_emitter_2d: GFProjectileEmitter2D = GFProjectileEmitter2D.new()
	parent_2d.add_child(fresh_emitter_2d)
	fresh_emitter_2d.projectile_definition = _make_projectile_definition_2d()
	var fresh_root_2d: Node = fresh_emitter_2d.emit_projectile()
	var fresh_session_2d: GFProjectileSession = _runtime_2d_from(
		fresh_root_2d
	).get_active_session()
	fresh_root_2d.free()
	assert_true(fresh_session_2d.is_finished())
	assert_eq(fresh_session_2d.get_end_reason(), GFProjectileSession.EndReason.ROOT_LOST)

	var parent_3d: Node3D = Node3D.new()
	add_child_autofree(parent_3d)
	var fresh_emitter_3d: GFProjectileEmitter3D = GFProjectileEmitter3D.new()
	parent_3d.add_child(fresh_emitter_3d)
	fresh_emitter_3d.projectile_definition = _make_projectile_definition_3d()
	var fresh_root_3d: Node = fresh_emitter_3d.emit_projectile()
	var fresh_session_3d: GFProjectileSession = _runtime_3d_from(
		fresh_root_3d
	).get_active_session()
	fresh_root_3d.free()
	assert_true(fresh_session_3d.is_finished())
	assert_eq(fresh_session_3d.get_end_reason(), GFProjectileSession.EndReason.ROOT_LOST)

	var pool_2d: LostLeaseRecordingPool = LostLeaseRecordingPool.new()
	pool_2d.init()
	var pooled_emitter_2d: GFProjectileEmitter2D = GFProjectileEmitter2D.new()
	parent_2d.add_child(pooled_emitter_2d)
	var pooled_definition_2d: GFProjectileDefinition2D = _make_projectile_definition_2d()
	pooled_emitter_2d.projectile_definition = pooled_definition_2d
	pooled_emitter_2d.use_object_pool = true
	pooled_emitter_2d.object_pool_utility = pool_2d
	var pooled_root_2d: Node = pooled_emitter_2d.emit_projectile()
	var pooled_session_2d: GFProjectileSession = _runtime_2d_from(
		pooled_root_2d
	).get_active_session()
	var pooled_id_2d: int = pooled_root_2d.get_instance_id()
	pooled_root_2d.free()
	assert_true(pooled_session_2d.is_finished())

	var pool_3d: LostLeaseRecordingPool = LostLeaseRecordingPool.new()
	pool_3d.init()
	var pooled_emitter_3d: GFProjectileEmitter3D = GFProjectileEmitter3D.new()
	parent_3d.add_child(pooled_emitter_3d)
	var pooled_definition_3d: GFProjectileDefinition3D = _make_projectile_definition_3d()
	pooled_emitter_3d.projectile_definition = pooled_definition_3d
	pooled_emitter_3d.use_object_pool = true
	pooled_emitter_3d.object_pool_utility = pool_3d
	var pooled_root_3d: Node = pooled_emitter_3d.emit_projectile()
	var pooled_session_3d: GFProjectileSession = _runtime_3d_from(
		pooled_root_3d
	).get_active_session()
	var pooled_id_3d: int = pooled_root_3d.get_instance_id()
	pooled_root_3d.free()
	assert_true(pooled_session_3d.is_finished())

	await get_tree().process_frame
	await get_tree().process_frame
	assert_eq(pool_2d.lost_retirement_count, 1)
	assert_eq(pool_2d.lost_retirement_ids, [pooled_id_2d])
	assert_false(
		pool_2d.retire_lost_lease_for_framework(
			pooled_definition_2d.scene,
			pooled_id_2d
		)
	)
	assert_eq(pool_3d.lost_retirement_count, 1)
	assert_eq(pool_3d.lost_retirement_ids, [pooled_id_3d])
	assert_false(
		pool_3d.retire_lost_lease_for_framework(
			pooled_definition_3d.scene,
			pooled_id_3d
		)
	)
	assert_eq(
		_count_retirement_records_in_tree(&"GFProjectileRetirementRecord2D"),
		0,
		"fresh/pool 2D record 必须独立结算且不泄漏到 SceneTree root。"
	)
	assert_eq(
		_count_retirement_records_in_tree(&"GFProjectileRetirementRecord3D"),
		0,
		"fresh/pool 3D record 必须独立结算且不泄漏到 SceneTree root。"
	)
	pool_2d.dispose()
	pool_3d.dispose()


func test_projectile_external_ancestor_free_retires_pool_2d_and_fresh_3d() -> void:
	var ancestor_2d: Node2D = Node2D.new()
	add_child_autofree(ancestor_2d)
	var emitter_2d: GFProjectileEmitter2D = GFProjectileEmitter2D.new()
	ancestor_2d.add_child(emitter_2d)
	var definition_2d: GFProjectileDefinition2D = _make_projectile_definition_2d()
	emitter_2d.projectile_definition = definition_2d
	emitter_2d.use_object_pool = true
	var pool_2d: LostLeaseRecordingPool = LostLeaseRecordingPool.new()
	pool_2d.init()
	emitter_2d.object_pool_utility = pool_2d
	var root_2d: Node = emitter_2d.emit_projectile()
	assert_not_null(root_2d)
	if root_2d == null:
		pool_2d.dispose()
		return
	var session_2d: GFProjectileSession = _runtime_2d_from(
		root_2d
	).get_active_session()
	var root_id_2d: int = root_2d.get_instance_id()
	ancestor_2d.free()
	assert_false(is_instance_valid(ancestor_2d))
	assert_false(is_instance_valid(emitter_2d))
	assert_false(is_instance_valid(root_2d))
	assert_true(session_2d.is_finished())
	assert_eq(
		session_2d.get_end_reason(),
		GFProjectileSession.EndReason.ROOT_LOST,
		"ancestor 同步销毁必须让 root tree-exit 在延迟 runtime loss 前 first-wins。"
	)
	await get_tree().process_frame
	await get_tree().process_frame
	assert_eq(pool_2d.lost_retirement_count, 1)
	assert_eq(pool_2d.lost_retirement_ids, [root_id_2d])
	assert_eq(pool_2d.get_active_count(definition_2d.scene), 0)
	assert_eq(
		_count_retirement_records_in_tree(&"GFProjectileRetirementRecord2D"),
		0
	)
	pool_2d.dispose()

	var ancestor_3d: Node3D = Node3D.new()
	add_child_autofree(ancestor_3d)
	var emitter_3d: GFProjectileEmitter3D = GFProjectileEmitter3D.new()
	ancestor_3d.add_child(emitter_3d)
	emitter_3d.projectile_definition = _make_projectile_definition_3d()
	var root_3d: Node = emitter_3d.emit_projectile()
	assert_not_null(root_3d)
	if root_3d == null:
		return
	var session_3d: GFProjectileSession = _runtime_3d_from(
		root_3d
	).get_active_session()
	ancestor_3d.free()
	assert_false(is_instance_valid(ancestor_3d))
	assert_false(is_instance_valid(emitter_3d))
	assert_false(is_instance_valid(root_3d))
	assert_true(session_3d.is_finished())
	assert_eq(
		session_3d.get_end_reason(),
		GFProjectileSession.EndReason.ROOT_LOST,
		"fresh 3D ancestor 销毁必须让 root tree-exit first-wins。"
	)
	await get_tree().process_frame
	await get_tree().process_frame
	assert_eq(
		_count_retirement_records_in_tree(&"GFProjectileRetirementRecord3D"),
		0
	)


func test_projectile_direct_runtime_removal_finishes_runtime_lost_after_tree_exit() -> void:
	var root_2d: Node2D = _make_bound_projectile_root_2d()
	add_child_autofree(root_2d)
	var definition_2d: GFProjectileDefinition2D = _make_projectile_definition_2d()
	var binding_2d: GFProjectileBinding2D = definition_2d.bind_instance(root_2d)
	var runtime_2d: GFProjectile2D = _runtime_2d_from(root_2d)
	var session_2d: GFProjectileSession = runtime_2d.launch(binding_2d)
	root_2d.remove_child(runtime_2d)
	assert_true(session_2d.is_active(), "child exit 回调栈内不得抢先覆盖潜在 ROOT_LOST。")
	await get_tree().process_frame
	assert_true(session_2d.is_finished())
	assert_eq(session_2d.get_end_reason(), GFProjectileSession.EndReason.RUNTIME_LOST)
	runtime_2d.free()

	var root_3d: Node3D = _make_bound_projectile_root_3d()
	add_child_autofree(root_3d)
	var definition_3d: GFProjectileDefinition3D = _make_projectile_definition_3d()
	var binding_3d: GFProjectileBinding3D = definition_3d.bind_instance(root_3d)
	var runtime_3d: GFProjectile3D = _runtime_3d_from(root_3d)
	var session_3d: GFProjectileSession = runtime_3d.launch(binding_3d)
	root_3d.remove_child(runtime_3d)
	assert_true(session_3d.is_active(), "3D child exit 使用同一延迟判别。")
	await get_tree().process_frame
	assert_true(session_3d.is_finished())
	assert_eq(session_3d.get_end_reason(), GFProjectileSession.EndReason.RUNTIME_LOST)
	runtime_3d.free()
