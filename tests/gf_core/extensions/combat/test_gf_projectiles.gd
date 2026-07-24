## 测试 Combat 扩展的通用发射体节点与策略资源。
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


class HitReceiver3D:
	extends Node3D

	func receive_hit(_context: GFCombatHitContext) -> Dictionary:
		return { "ok": true }


class RecordingProjectileSender2D:
	extends Node2D

	var received_receiver: Object = null
	var received_payload: Variant = null
	var received_hit_id: StringName = &""

	func send_to(receiver: Object, payload_override: Variant = null, hit_id_override: StringName = &"") -> Dictionary:
		received_receiver = receiver
		received_payload = payload_override
		received_hit_id = hit_id_override
		return {
			"ok": true,
			"hit_id": hit_id_override,
			"receiver": receiver,
			"metadata": {},
		}


class RecordingProjectileSender3D:
	extends Node3D

	var received_receiver: Object = null
	var received_payload: Variant = null
	var received_hit_id: StringName = &""

	func send_to(receiver: Object, payload_override: Variant = null, hit_id_override: StringName = &"") -> Dictionary:
		received_receiver = receiver
		received_payload = payload_override
		received_hit_id = hit_id_override
		return {
			"ok": true,
			"hit_id": hit_id_override,
			"receiver": receiver,
			"metadata": {},
		}


class CountingProjectileMotion:
	extends GFProjectileMotion

	var setup_count: int = 0
	var last_context: Dictionary = {}

	func _setup(_projectile: Node, projectile_context: Dictionary = {}) -> void:
		setup_count += 1
		last_context = projectile_context.duplicate(true)


class RecordingSpawnPattern2D extends GFProjectileSpawnPattern2D:
	var received_count: int = 0
	var default_count: int = 1

	func _get_default_spawn_count() -> int:
		return default_count

	func _get_spawn_transforms(
		emitter: Node2D,
		_projectile_context: Dictionary = {},
		emit_count: int = -1
	) -> Array[Transform2D]:
		received_count = emit_count
		var result: Array[Transform2D] = []
		for _index: int in range(maxi(emit_count, 0)):
			result.append(emitter.global_transform)
		return result


class RecordingSpawnPattern3D extends GFProjectileSpawnPattern3D:
	var received_count: int = 0

	func _get_spawn_transforms(
		emitter: Node3D,
		_projectile_context: Dictionary = {},
		emit_count: int = -1
	) -> Array[Transform3D]:
		received_count = emit_count
		var result: Array[Transform3D] = []
		for _index: int in range(maxi(emit_count, 0)):
			result.append(emitter.global_transform)
		return result


# --- 私有/辅助方法 ---

func _make_projectile_2d_scene() -> PackedScene:
	var projectile: GFProjectile2D = GFProjectile2D.new()
	projectile.auto_launch_on_ready = false
	projectile.queue_free_on_finish = false
	var scene: PackedScene = PackedScene.new()
	var _pack_result_83: Variant = scene.pack(projectile)
	projectile.free()
	return scene


func _make_auto_launch_projectile_2d_scene() -> PackedScene:
	var projectile: GFProjectile2D = GFProjectile2D.new()
	projectile.auto_launch_on_ready = true
	projectile.queue_free_on_finish = false
	projectile.motion = CountingProjectileMotion.new()
	var scene: PackedScene = PackedScene.new()
	var _pack_result: Variant = scene.pack(projectile)
	projectile.free()
	return scene


func _make_projectile_3d_scene() -> PackedScene:
	var projectile: GFProjectile3D = GFProjectile3D.new()
	projectile.auto_launch_on_ready = false
	projectile.queue_free_on_finish = false
	var scene: PackedScene = PackedScene.new()
	var _pack_result: Error = scene.pack(projectile)
	projectile.free()
	return scene


func _projectile_2d_at(projectiles: Array[Node], index: int) -> GFProjectile2D:
	var projectile: Node = projectiles[index]
	if projectile is GFProjectile2D:
		return projectile
	return null


func _counting_projectile_motion(value: Variant) -> CountingProjectileMotion:
	if value is GFProjectile2D:
		var projectile: GFProjectile2D = value
		if projectile.motion is CountingProjectileMotion:
			var motion: CountingProjectileMotion = projectile.motion
			return motion
	return null


# --- 测试 ---

func test_projectile_2d_moves_with_linear_motion() -> void:
	var projectile: GFProjectile2D = GFProjectile2D.new()
	projectile.auto_launch_on_ready = false
	projectile.queue_free_on_finish = false
	var motion: GFLinearProjectileMotion = GFLinearProjectileMotion.new()
	motion.speed = 10.0
	motion.use_local_direction = false
	motion.direction_2d = Vector2.RIGHT
	projectile.motion = motion

	projectile.launch()
	projectile._physics_process(0.5)

	assert_eq(projectile.position, Vector2(5.0, 0.0), "直线移动策略应推进 2D 发射体。")

	projectile.free()


func test_projectile_lifetime_policy_finishes_after_elapsed_time() -> void:
	var projectile: GFProjectile2D = GFProjectile2D.new()
	projectile.auto_launch_on_ready = false
	projectile.queue_free_on_finish = false
	var lifetime: GFProjectileLifetimePolicy = GFProjectileLifetimePolicy.new()
	lifetime.max_seconds = 0.25
	projectile.lifetime_policy = lifetime

	projectile.launch()
	projectile._physics_process(0.3)

	assert_false(projectile.is_projectile_active(), "超过生命周期后应结束。")

	projectile.free()


func test_projectile_lifetime_policy_finishes_after_accepted_impacts() -> void:
	var projectile: GFProjectile2D = GFProjectile2D.new()
	projectile.auto_launch_on_ready = false
	projectile.finish_on_impact = false
	projectile.queue_free_on_finish = false
	var lifetime: GFProjectileLifetimePolicy = GFProjectileLifetimePolicy.new()
	lifetime.max_impacts = 2
	projectile.lifetime_policy = lifetime
	var receiver: HitReceiver2D = HitReceiver2D.new()

	projectile.launch()
	projectile.send_impact_to(receiver)
	var first_context: Dictionary = projectile.get_projectile_context()
	projectile.send_impact_to(receiver)

	assert_eq(GFVariantData.get_option_int(first_context, "impact_count"), 1, "第一次成功命中后应记录命中次数。")
	assert_false(projectile.is_projectile_active(), "达到最大命中次数后应结束。")

	projectile.free()
	receiver.free()


func test_projectile_impact_sends_combat_hit_context() -> void:
	var projectile: GFProjectile2D = GFProjectile2D.new()
	projectile.auto_launch_on_ready = false
	projectile.queue_free_on_finish = false
	projectile.finish_on_impact = true
	projectile.hit_id = &"projectile_hit"
	projectile.payload = { "kind": "test" }
	var receiver: HitReceiver2D = HitReceiver2D.new()

	projectile.launch()
	projectile.send_impact_to(receiver)

	assert_not_null(receiver.received_context, "命中接收器应收到 GFCombatHitContext。")
	assert_eq(receiver.received_context.hit_id, &"projectile_hit", "命中 ID 应来自发射体节点。")
	assert_eq(GFVariantData.get_option_string(GFVariantData.as_dictionary(receiver.received_context.payload), "kind"), "test", "payload 应随命中上下文传递。")
	assert_false(projectile.is_projectile_active(), "finish_on_impact 开启时命中后应结束。")

	projectile.free()
	receiver.free()


func test_projectile_2d_impact_uses_sender_send_to_override() -> void:
	var root: Node2D = Node2D.new()
	var projectile: GFProjectile2D = GFProjectile2D.new()
	var sender: RecordingProjectileSender2D = RecordingProjectileSender2D.new()
	var receiver: HitReceiver2D = HitReceiver2D.new()
	add_child_autofree(root)
	root.add_child(projectile)
	root.add_child(sender)
	root.add_child(receiver)
	sender.name = "Sender"
	projectile.auto_launch_on_ready = false
	projectile.queue_free_on_finish = false
	projectile.finish_on_impact = false
	projectile.sender_path = NodePath("../Sender")
	watch_signals(projectile)

	projectile.launch()
	projectile.send_impact_to(receiver)
	var context: Dictionary = projectile.get_projectile_context()

	assert_same(sender.received_receiver, receiver, "2D 发射体自动命中应交给 sender_path 指向的业务发送者。")
	assert_true(sender.received_payload == null, "未覆盖 payload 时应透传 null，让业务发送者使用自身默认值。")
	assert_eq(sender.received_hit_id, &"", "未覆盖命中 ID 时应透传空值，让业务发送者使用自身默认值。")
	assert_eq(GFVariantData.get_option_int(context, "impact_count"), 1, "业务发送者接受后仍应记录发射体命中次数。")
	assert_signal_emitted(projectile, "hit_sent", "业务发送者接管 2D 发射体命中时 Projectile 仍应发出 hit_sent。")
	assert_signal_emitted(projectile, "hit_accepted", "业务发送者返回成功报告时 Projectile 仍应发出 hit_accepted。")


func test_projectile_3d_impact_uses_sender_send_to_override() -> void:
	var root: Node3D = Node3D.new()
	var projectile: GFProjectile3D = GFProjectile3D.new()
	var sender: RecordingProjectileSender3D = RecordingProjectileSender3D.new()
	var receiver: HitReceiver3D = HitReceiver3D.new()
	add_child_autofree(root)
	root.add_child(projectile)
	root.add_child(sender)
	root.add_child(receiver)
	sender.name = "Sender"
	projectile.auto_launch_on_ready = false
	projectile.queue_free_on_finish = false
	projectile.finish_on_impact = false
	projectile.sender_path = NodePath("../Sender")
	watch_signals(projectile)

	projectile.launch()
	projectile.send_impact_to(receiver)
	var context: Dictionary = projectile.get_projectile_context()

	assert_same(sender.received_receiver, receiver, "3D 发射体自动命中应交给 sender_path 指向的业务发送者。")
	assert_eq(GFVariantData.get_option_int(context, "impact_count"), 1, "3D 业务发送者接受后仍应记录发射体命中次数。")
	assert_signal_emitted(projectile, "hit_sent", "业务发送者接管 3D 发射体命中时 Projectile 仍应发出 hit_sent。")


func test_projectile_finish_on_impact_waits_for_accepted_hit() -> void:
	var projectile: GFProjectile2D = GFProjectile2D.new()
	projectile.auto_launch_on_ready = false
	projectile.queue_free_on_finish = false
	projectile.finish_on_impact = true
	var receiver: RejectingHitReceiver2D = RejectingHitReceiver2D.new()

	projectile.launch()
	projectile.send_impact_to(receiver)
	var context: Dictionary = projectile.get_projectile_context()

	assert_true(projectile.is_projectile_active(), "被接收器拒绝的命中不应结束发射体。")
	assert_eq(GFVariantData.get_option_int(context, "impact_attempt_count"), 1, "拒绝命中仍应记录尝试次数。")
	assert_eq(GFVariantData.get_option_int(context, "impact_count"), 0, "拒绝命中不应累计成功命中次数。")

	projectile.free()
	receiver.free()


func test_projectile_emitter_2d_spawns_contextual_burst() -> void:
	var parent: Node2D = Node2D.new()
	add_child_autofree(parent)
	var emitter: GFProjectileEmitter2D = GFProjectileEmitter2D.new()
	parent.add_child(emitter)
	emitter.projectile_scene = _make_projectile_2d_scene()
	emitter.default_context = { "team": "player" }
	var pattern: GFProjectileBurstPattern2D = GFProjectileBurstPattern2D.new()
	pattern.projectile_count = 3
	pattern.spread_degrees = 60.0
	pattern.radius = 10.0
	emitter.spawn_pattern = pattern

	var projectiles: Array[Node] = emitter.emit_projectiles({ "skill_id": "fan" })

	assert_eq(projectiles.size(), 3, "发射器应按 burst pattern 生成多个发射体。")
	for index: int in range(projectiles.size()):
		var projectile: GFProjectile2D = _projectile_2d_at(projectiles, index)
		assert_not_null(projectile, "生成节点应为 2D 发射体。")
		assert_true(projectile.is_projectile_active(), "生成后应调用 launch(context)。")
		var context: Dictionary = projectile.get_projectile_context()
		assert_eq(GFVariantData.get_option_string(context, "team"), "player", "默认上下文应合并到发射上下文。")
		assert_eq(GFVariantData.get_option_string(context, "skill_id"), "fan", "调用方上下文应合并到发射上下文。")
		assert_eq(GFVariantData.get_option_int(context, "spawn_index"), index, "上下文应记录发射序号。")
		assert_eq(GFVariantData.get_option_int(context, "spawn_count"), 3, "上下文应记录本次发射数量。")


func test_projectile_emission_policy_caps_spawn_count() -> void:
	var parent: Node2D = Node2D.new()
	add_child_autofree(parent)
	var emitter: GFProjectileEmitter2D = GFProjectileEmitter2D.new()
	parent.add_child(emitter)
	emitter.projectile_scene = _make_projectile_2d_scene()
	var pattern: GFProjectileBurstPattern2D = GFProjectileBurstPattern2D.new()
	pattern.projectile_count = 4
	emitter.spawn_pattern = pattern
	var policy: GFProjectileEmissionPolicy = GFProjectileEmissionPolicy.new()
	policy.max_projectiles_per_request = 2
	emitter.emission_policy = policy

	var projectiles: Array[Node] = emitter.emit_projectiles()

	assert_eq(projectiles.size(), 2, "发射策略应能裁剪本次生成数量。")
	for index: int in range(projectiles.size()):
		var projectile: GFProjectile2D = _projectile_2d_at(projectiles, index)
		assert_not_null(projectile, "裁剪后仍应生成有效 2D 发射体。")
		if projectile == null:
			continue
		var context: Dictionary = projectile.get_projectile_context()
		assert_eq(GFVariantData.get_option_int(context, "spawn_count"), 2, "裁剪后的上下文应反映实际生成数量。")
	assert_eq(GFVariantData.get_option_int(policy.get_debug_snapshot(), "emission_count"), 1, "成功生成后策略应提交一次发射。")


func test_projectile_emission_policy_caps_before_2d_pattern_generation() -> void:
	var parent: Node2D = Node2D.new()
	add_child_autofree(parent)
	var emitter: GFProjectileEmitter2D = GFProjectileEmitter2D.new()
	parent.add_child(emitter)
	emitter.projectile_scene = _make_projectile_2d_scene()
	var pattern: RecordingSpawnPattern2D = RecordingSpawnPattern2D.new()
	emitter.spawn_pattern = pattern
	var policy: GFProjectileEmissionPolicy = GFProjectileEmissionPolicy.new()
	policy.max_projectiles_per_request = 2
	emitter.emission_policy = policy

	var projectiles: Array[Node] = emitter.emit_projectiles({}, &"", 1_000_000)

	assert_eq(pattern.received_count, 2, "策略预算必须在模式分配 transform 前生效。")
	assert_eq(projectiles.size(), 2)


func test_projectile_emitter_3d_hard_limit_caps_before_pattern_generation() -> void:
	var parent: Node3D = Node3D.new()
	add_child_autofree(parent)
	var emitter: GFProjectileEmitter3D = GFProjectileEmitter3D.new()
	parent.add_child(emitter)
	emitter.projectile_scene = _make_projectile_3d_scene()
	emitter.hard_projectile_limit_per_request = 3
	var pattern: RecordingSpawnPattern3D = RecordingSpawnPattern3D.new()
	emitter.spawn_pattern = pattern

	var projectiles: Array[Node] = emitter.emit_projectiles({}, &"", 1_000_000)

	assert_eq(pattern.received_count, 3, "3D 模式也必须服从分配前硬预算。")
	assert_eq(projectiles.size(), 3)


func test_projectile_emission_policy_blocks_cooldown() -> void:
	var parent: Node2D = Node2D.new()
	add_child_autofree(parent)
	var emitter: GFProjectileEmitter2D = GFProjectileEmitter2D.new()
	parent.add_child(emitter)
	emitter.projectile_scene = _make_projectile_2d_scene()
	var policy: GFProjectileEmissionPolicy = GFProjectileEmissionPolicy.new()
	policy.cooldown_seconds = 60.0
	emitter.emission_policy = policy
	watch_signals(emitter)

	var first_projectile: Node = emitter.emit_projectile()
	var blocked_projectiles: Array[Node] = emitter.emit_projectiles()

	assert_not_null(first_projectile, "第一次发射应通过策略。")
	assert_true(blocked_projectiles.is_empty(), "冷却中第二次发射应被阻断。")
	assert_signal_emitted(emitter, "projectile_emit_failed", "策略阻断时发射器应发出失败信号。")


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

	assert_true(GFVariantData.get_option_bool(prepare_report, "ok"), "初始 charge 足够时应允许发射。")
	assert_true(GFVariantData.get_option_bool(commit_report, "committed"), "实际生成后应提交 charge 消耗。")
	assert_eq(GFVariantData.get_option_float(commit_report, "available_charges"), 0.0, "提交报告必须使用 prepare 的时间快照。")
	assert_eq(GFVariantData.get_option_int(commit_report, "now_msec"), 0, "提交报告应保留同一事务时间。")
	assert_false(GFVariantData.get_option_bool(blocked_report, "ok"), "charge 不足时应阻断发射。")
	assert_eq(GFVariantData.get_option_string_name(blocked_report, "reason"), &"insufficient_charges", "charge 不足应给出稳定原因。")
	assert_true(GFVariantData.get_option_bool(recovered_report, "ok"), "经过恢复时间后应重新允许发射。")


func test_projectile_emission_policy_rejects_non_finite_configuration() -> void:
	var policy: GFProjectileEmissionPolicy = GFProjectileEmissionPolicy.new()
	policy.cooldown_seconds = NAN

	var report: Dictionary = policy.prepare_emission(null, &"arrow", {}, 1, 0)

	assert_false(GFVariantData.get_option_bool(report, "ok"))
	assert_eq(GFVariantData.get_option_string_name(report, "reason"), &"non_finite_policy_configuration")


func test_projectile_emitter_2d_resolves_catalog_scene() -> void:
	var parent: Node2D = Node2D.new()
	add_child_autofree(parent)
	var emitter: GFProjectileEmitter2D = GFProjectileEmitter2D.new()
	parent.add_child(emitter)
	var catalog: GFProjectileCatalog = GFProjectileCatalog.new()
	catalog.set_scene(&"arrow", _make_projectile_2d_scene())
	emitter.projectile_catalog = catalog
	emitter.default_projectile_id = &"arrow"

	var projectile: Node = emitter.emit_projectile()

	assert_not_null(projectile, "发射器应能从目录 ID 解析场景。")
	assert_true(projectile is GFProjectile2D, "目录场景应被实例化为发射体。")


func test_projectile_emitter_2d_uses_explicit_object_pool() -> void:
	var parent: Node2D = Node2D.new()
	add_child_autofree(parent)
	var emitter: GFProjectileEmitter2D = GFProjectileEmitter2D.new()
	parent.add_child(emitter)
	var scene: PackedScene = _make_projectile_2d_scene()
	var pool: GFObjectPoolUtility = GFObjectPoolUtility.new()
	pool.init()
	emitter.projectile_scene = scene
	emitter.use_object_pool = true
	emitter.object_pool_utility = pool

	var projectile: Node = emitter.emit_projectile()

	assert_not_null(projectile, "显式对象池可用时发射器应生成发射体。")
	assert_eq(pool.get_active_count(scene), 1, "发射器应通过显式对象池获取节点。")

	pool.dispose()
	await get_tree().process_frame


func test_projectile_emitter_2d_disables_pooled_auto_launch_before_add() -> void:
	var parent: Node2D = Node2D.new()
	add_child_autofree(parent)
	var emitter: GFProjectileEmitter2D = GFProjectileEmitter2D.new()
	parent.add_child(emitter)
	var scene: PackedScene = _make_auto_launch_projectile_2d_scene()
	var pool: GFObjectPoolUtility = GFObjectPoolUtility.new()
	pool.init()
	emitter.projectile_scene = scene
	emitter.default_context = { "team": "player" }
	emitter.use_object_pool = true
	emitter.object_pool_utility = pool

	var projectile_node: Node = emitter.emit_projectile({ "skill_id": "pool_test" })
	var motion: CountingProjectileMotion = _counting_projectile_motion(projectile_node)

	assert_not_null(motion, "池化发射体应保持测试用 motion。")
	if motion == null:
		pool.dispose()
		await get_tree().process_frame
		return

	assert_eq(motion.setup_count, 1, "对象池新建节点不应在 emitter 准备上下文前 auto launch。")
	var context: Dictionary = motion.last_context
	assert_eq(GFVariantData.get_option_string(context, "team"), "player", "唯一 launch 应使用 emitter 默认上下文。")
	assert_eq(GFVariantData.get_option_string(context, "skill_id"), "pool_test", "唯一 launch 应使用调用方上下文。")

	pool.dispose()
	await get_tree().process_frame


func test_projectile_emitter_2d_uses_injected_architecture_pool() -> void:
	var parent: Node2D = Node2D.new()
	add_child_autofree(parent)
	var emitter: GFProjectileEmitter2D = GFProjectileEmitter2D.new()
	parent.add_child(emitter)
	var scene: PackedScene = _make_projectile_2d_scene()
	var architecture: GFArchitecture = GFArchitecture.new()
	var pool: GFObjectPoolUtility = GFObjectPoolUtility.new()
	await architecture.register_utility_instance(pool)
	await architecture.init()
	emitter.projectile_scene = scene
	emitter.use_object_pool = true
	emitter.inject_dependencies(architecture)

	var projectile: Node = emitter.emit_projectile()

	assert_not_null(projectile, "注入架构提供对象池时发射器应生成发射体。")
	assert_eq(pool.get_active_count(scene), 1, "发射器应通过注入架构查询对象池。")

	architecture.dispose()
	await get_tree().process_frame


func test_projectile_line_spawn_pattern_2d_distributes_points() -> void:
	var emitter: Node2D = Node2D.new()
	add_child_autofree(emitter)
	var pattern: GFProjectileLineSpawnPattern2D = GFProjectileLineSpawnPattern2D.new()
	pattern.local_start = Vector2(-10.0, 0.0)
	pattern.local_end = Vector2(10.0, 0.0)
	pattern.point_count = 3

	var transforms: Array[Transform2D] = pattern.get_spawn_transforms(emitter)

	assert_eq(transforms.size(), 3, "线段模式应按数量生成点。")
	assert_eq(transforms[0].origin, Vector2(-10.0, 0.0), "第一个点应位于线段起点。")
	assert_eq(transforms[1].origin, Vector2.ZERO, "中间点应位于线段中心。")
	assert_eq(transforms[2].origin, Vector2(10.0, 0.0), "最后一个点应位于线段终点。")


func test_projectile_emitter_reports_missing_scene() -> void:
	var emitter: GFProjectileEmitter2D = GFProjectileEmitter2D.new()
	add_child_autofree(emitter)
	watch_signals(emitter)

	var projectiles: Array[Node] = emitter.emit_projectiles()

	assert_true(projectiles.is_empty(), "缺少场景时不应生成发射体。")
	assert_signal_emitted(emitter, "projectile_emit_failed", "缺少场景时应发出失败信号。")


func test_projectile_emitter_assigns_new_emission_token_per_prepare() -> void:
	var emitter: GFProjectileEmitter2D = GFProjectileEmitter2D.new()
	var projectile: GFProjectile2D = GFProjectile2D.new()
	var scene: PackedScene = PackedScene.new()

	emitter._prepare_projectile_runtime(projectile, scene)
	var first_token: int = GFVariantData.to_int(projectile.get_meta(&"gf_emission_token", -1))
	emitter._prepare_projectile_runtime(projectile, scene)
	var second_token: int = GFVariantData.to_int(projectile.get_meta(&"gf_emission_token", -1))

	assert_gt(first_token, 0, "发射器应写入本次发射 token。")
	assert_gt(second_token, first_token, "复用同一 projectile 时 token 应递增，避免旧回调释放新一轮发射。")

	projectile.free()
	emitter.free()


func test_homing_motion_moves_toward_context_target_position() -> void:
	var projectile: GFProjectile2D = GFProjectile2D.new()
	projectile.auto_launch_on_ready = false
	projectile.queue_free_on_finish = false
	var motion: GFHomingProjectileMotion = GFHomingProjectileMotion.new()
	motion.speed = 10.0
	projectile.motion = motion

	projectile.launch({ "target_position_2d": Vector2(10.0, 0.0) })
	projectile._physics_process(0.5)

	assert_eq(projectile.position, Vector2(5.0, 0.0), "追踪移动策略应朝 2D 目标位置推进。")

	projectile.free()


func test_homing_motion_clamps_to_arrival_distance() -> void:
	var projectile: GFProjectile2D = GFProjectile2D.new()
	projectile.auto_launch_on_ready = false
	projectile.queue_free_on_finish = false
	var motion: GFHomingProjectileMotion = GFHomingProjectileMotion.new()
	motion.speed = 10.0
	motion.arrival_distance = 1.0
	motion.stop_when_reached = true
	projectile.motion = motion

	projectile.launch({ "target_position_2d": Vector2(3.0, 0.0) })
	projectile._physics_process(0.5)
	var context: Dictionary = projectile.get_projectile_context()

	assert_eq(projectile.position, Vector2(2.0, 0.0), "开启到达夹取时不应越过 arrival_distance。")
	assert_true(GFVariantData.get_option_bool(context, "target_reached"), "到达目标范围时应在上下文中标记。")

	projectile.free()


func test_homing_motion_ignores_freed_context_target() -> void:
	var projectile: GFProjectile2D = GFProjectile2D.new()
	projectile.auto_launch_on_ready = false
	projectile.queue_free_on_finish = false
	var motion: GFHomingProjectileMotion = GFHomingProjectileMotion.new()
	motion.speed = 10.0
	projectile.motion = motion
	var target: Node2D = Node2D.new()

	projectile.launch({ "target": target })
	target.free()
	projectile._physics_process(0.5)

	assert_eq(projectile.position, Vector2.ZERO, "目标已释放时追踪移动不应把无效对象当作位置读取。")

	projectile.free()


func test_linear_motion_supports_3d_projectiles() -> void:
	var projectile: GFProjectile3D = GFProjectile3D.new()
	projectile.auto_launch_on_ready = false
	projectile.queue_free_on_finish = false
	var motion: GFLinearProjectileMotion = GFLinearProjectileMotion.new()
	motion.speed = 4.0
	motion.use_local_direction = false
	motion.direction_3d = Vector3.FORWARD
	projectile.motion = motion

	projectile.launch()
	projectile._physics_process(0.5)

	assert_eq(projectile.position, Vector3(0.0, 0.0, -2.0), "直线移动策略应推进 3D 发射体。")

	projectile.free()


func test_linear_motion_rejects_non_finite_speed_without_moving() -> void:
	var projectile: GFProjectile2D = GFProjectile2D.new()
	projectile.auto_launch_on_ready = false
	projectile.queue_free_on_finish = false
	var motion: GFLinearProjectileMotion = GFLinearProjectileMotion.new()
	motion.speed = NAN
	motion.use_local_direction = false
	projectile.motion = motion

	projectile.launch()
	projectile._physics_process(0.5)
	var context: Dictionary = projectile.get_projectile_context()

	assert_eq(projectile.position, Vector2.ZERO)
	assert_eq(GFVariantData.get_option_string_name(context, "motion_rejected_reason"), &"non_finite_motion_configuration")
	projectile.free()


func test_homing_motion_rejects_non_finite_target_position() -> void:
	var projectile: GFProjectile2D = GFProjectile2D.new()
	projectile.auto_launch_on_ready = false
	projectile.queue_free_on_finish = false
	var motion: GFHomingProjectileMotion = GFHomingProjectileMotion.new()
	motion.speed = 10.0
	projectile.motion = motion

	projectile.launch({ "target_position_2d": Vector2(INF, 0.0) })
	projectile._physics_process(0.5)
	var context: Dictionary = projectile.get_projectile_context()

	assert_eq(projectile.position, Vector2.ZERO)
	assert_true(GFVariantData.get_option_bool(context, "target_missing"), "非法目标位置应按不可用目标处理。")
	projectile.free()
