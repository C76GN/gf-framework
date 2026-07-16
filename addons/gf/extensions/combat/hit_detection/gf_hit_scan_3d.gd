## GFHitScan3D: 3D 通用射线命中发送器。
##
## 基于 RayCast3D 构建 GFCombatHitContext 并发送给具备 receive_hit() 的接收对象。
## 它不规定伤害、穿透、命中特效或任何业务规则。
## [br]
## @api public
## [br]
## @category runtime_handle
## [br]
## @since 3.17.0
class_name GFHitScan3D
extends RayCast3D


# --- 信号 ---

## 扫描命中对象后发出。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @param context: 命中上下文。
## [br]
## @param receiver: 接收对象。
## [br]
## @param report: 结果报告。
## [br]
## @schema report: Dictionary，统一扫描命中结果，包含 ok、hit_id、receiver(JSON-safe 摘要)、reason、message 和 metadata。
signal scan_hit(context: GFCombatHitContext, receiver: Object, report: Dictionary)

## 扫描没有命中可发送对象时发出。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @param report: 结果报告。
## [br]
## @schema report: Dictionary，扫描未命中报告，包含 ok、reason 和 metadata。
signal scan_missed(report: Dictionary)

## 命中被接收对象接受。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @param context: 命中上下文。
## [br]
## @param receiver: 接收对象。
## [br]
## @param report: 结果报告。
## [br]
## @schema report: Dictionary，统一扫描命中结果，包含 ok、hit_id、receiver(JSON-safe 摘要)、reason、message 和 metadata。
signal hit_accepted(context: GFCombatHitContext, receiver: Object, report: Dictionary)

## 命中被接收对象拒绝或发送失败。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @param context: 命中上下文。
## [br]
## @param receiver: 接收对象。
## [br]
## @param report: 结果报告。
## [br]
## @schema report: Dictionary，统一扫描命中结果，包含 ok、hit_id、receiver(JSON-safe 摘要)、reason、message 和 metadata。
signal hit_rejected(context: GFCombatHitContext, receiver: Object, report: Dictionary)


# --- 常量 ---

const _MESSAGE_DISPATCH_SUPPORT = preload("res://addons/gf/standard/common/gf_message_dispatch_support.gd")


# --- 导出变量 ---

## 是否允许发送命中。
## [br]
## @api public
## [br]
## @since 3.17.0
@export var hit_enabled: bool = true

## 扫描前是否强制刷新射线。
## [br]
## @api public
## [br]
## @since 3.17.0
@export var force_update_before_scan: bool = true

## 默认命中 ID。
## [br]
## @api public
## [br]
## @since 3.17.0
@export var hit_id: StringName = &""

## 默认 payload；发送时会深拷贝。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @schema payload: Dictionary，默认命中载荷；框架只复制并透传。
@export var payload: Dictionary = {}

## 通用强度值。框架不解释该字段。
## [br]
## @api public
## [br]
## @since 3.17.0
@export var magnitude: float = 0.0

## 命中标签。框架不解释该字段。
## [br]
## @api public
## [br]
## @since 3.17.0
@export var tags: Array[StringName] = []

## 发送器自定义元数据。框架不解释该字段。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @schema metadata: Dictionary，发送器自定义扫描命中元数据；会进入命中上下文和结果报告。
@export var metadata: Dictionary = {}

## 可选发送者路径；为空时使用当前节点。
## [br]
## @api public
## [br]
## @since 3.17.0
@export_node_path("Node") var sender_path: NodePath = NodePath("")


# --- 公共方法 ---

## 构建命中上下文。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @param target: 命中目标。
## [br]
## @param payload_override: 覆盖 payload；为 null 时使用节点默认 payload。
## [br]
## @param hit_id_override: 覆盖命中 ID；为空时使用节点默认命中 ID。
## [br]
## @return 命中上下文。
## [br]
## @schema payload_override: Variant，可为 null、Dictionary 或项目自定义命中载荷；为 null 时使用节点默认 payload。
func build_hit_context(
	target: Object = null,
	payload_override: Variant = null,
	hit_id_override: StringName = &""
) -> GFCombatHitContext:
	var context_payload: Variant = payload.duplicate(true) if payload_override == null else GFVariantData.duplicate_variant(payload_override)
	var effective_hit_id: StringName = hit_id_override if hit_id_override != &"" else hit_id
	var context: GFCombatHitContext = GFCombatHitContext.new(_resolve_sender(), target, context_payload, effective_hit_id)
	context.magnitude = magnitude
	context.tags = tags.duplicate()
	context.position_3d = get_collision_point() if is_colliding() else global_position
	context.normal_3d = get_collision_normal() if is_colliding() else Vector3.ZERO
	context.metadata = metadata.duplicate(true)
	return context


## 执行一次射线扫描并尝试发送命中。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @param payload_override: 覆盖 payload；为 null 时使用节点默认 payload。
## [br]
## @param hit_id_override: 覆盖命中 ID；为空时使用节点默认命中 ID。
## [br]
## @return 统一结果报告。
## [br]
## @schema payload_override: Variant，可为 null、Dictionary 或项目自定义命中载荷；为 null 时使用节点默认 payload。
## [br]
## @schema return: Dictionary，统一扫描命中或未命中结果，包含 ok、reason、metadata，并在命中时包含 hit_id、receiver(JSON-safe 摘要) 和 message。
func scan(payload_override: Variant = null, hit_id_override: StringName = &"") -> Dictionary:
	if force_update_before_scan:
		force_raycast_update()
	if not hit_enabled:
		return _emit_missed(&"disabled")
	if not is_colliding():
		return _emit_missed(&"no_collision")

	var receiver: Object = _resolve_hit_receiver(get_collider())
	var context: GFCombatHitContext = build_hit_context(receiver, payload_override, hit_id_override)
	var report_value: Variant = _MESSAGE_DISPATCH_SUPPORT._dispatch_to_receiver(
		hit_enabled,
		metadata,
		receiver,
		&"receive_hit",
		[context],
		"hit_id",
		context.hit_id,
		"Hit scan is disabled.",
		"Hit scan receiver is null.",
		"Receiver does not expose receive_hit().",
		"Receiver returned an invalid hit report."
	)
	var report: Dictionary = GFVariantData.as_dictionary(report_value)
	_emit_scan_result(context, receiver, report)
	return report


# --- 私有/辅助方法 ---

func _emit_missed(reason: StringName) -> Dictionary:
	var report: Dictionary = {
		"ok": false,
		"reason": reason,
		"metadata": metadata.duplicate(true),
	}
	scan_missed.emit(report)
	return report


func _emit_scan_result(context: GFCombatHitContext, receiver: Object, report: Dictionary) -> void:
	scan_hit.emit(context, receiver, report)
	if GFVariantData.get_option_bool(report, "ok", false):
		hit_accepted.emit(context, receiver, report)
	else:
		hit_rejected.emit(context, receiver, report)


func _resolve_sender() -> Object:
	if sender_path != NodePath(""):
		var sender: Node = get_node_or_null(sender_path)
		if sender != null:
			return sender
	return self


func _resolve_hit_receiver(candidate: Object) -> Object:
	return _MESSAGE_DISPATCH_SUPPORT._resolve_receiver(candidate, &"receive_hit")
