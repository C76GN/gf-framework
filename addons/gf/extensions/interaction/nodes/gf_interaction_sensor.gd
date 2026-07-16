## GFInteractionSensor: 通用交互发送节点。
##
## 负责构建 GFInteractionContext，并把交互请求发送给具备 receive_interaction()
## 方法的接收对象。发送者、目标、payload 和分组均保持通用，不绑定具体玩法。
## [br]
## @api public
## [br]
## @category runtime_handle
## [br]
## @since 3.17.0
class_name GFInteractionSensor
extends Node


# --- 信号 ---

## 交互已发送。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @param context: 交互上下文。
## [br]
## @param receiver: 接收对象。
## [br]
## @param report: 结果报告。
## [br]
## @schema report: 交互结果报告 Dictionary，包含 ok、interaction_id、receiver(JSON-safe 摘要)、reason、message 和 metadata 等字段。
signal interaction_sent(context: GFInteractionContext, receiver: Object, report: Dictionary)

## 交互被接收对象接受。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @param context: 交互上下文。
## [br]
## @param receiver: 接收对象。
## [br]
## @param report: 结果报告。
## [br]
## @schema report: 交互结果报告 Dictionary，包含 ok、interaction_id、receiver(JSON-safe 摘要)、reason、message 和 metadata 等字段。
signal interaction_accepted(context: GFInteractionContext, receiver: Object, report: Dictionary)

## 交互被接收对象拒绝或发送失败。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @param context: 交互上下文。
## [br]
## @param receiver: 接收对象。
## [br]
## @param report: 结果报告。
## [br]
## @schema report: 交互结果报告 Dictionary，包含 ok、interaction_id、receiver(JSON-safe 摘要)、reason、message 和 metadata 等字段。
signal interaction_rejected(context: GFInteractionContext, receiver: Object, report: Dictionary)


# --- 常量 ---

const _MESSAGE_DISPATCH_SUPPORT = preload("res://addons/gf/standard/common/gf_message_dispatch_support.gd")


# --- 导出变量 ---

## 是否允许发送交互。
## [br]
## @api public
## [br]
## @since 3.17.0
@export var enabled: bool = true

## 默认交互 ID。
## [br]
## @api public
## [br]
## @since 3.17.0
@export var interaction_id: StringName = &""

## 默认交互分组。
## [br]
## @api public
## [br]
## @since 3.17.0
@export var group_name: StringName = &""

## 默认 payload；发送时会深拷贝。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @schema payload: 默认交互载荷 Dictionary；发送时会复制，项目可定义其中键值。
@export var payload: Dictionary = {}

## 发送器自定义元数据。框架不解释该字段。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @schema metadata: 发送器自定义元数据 Dictionary；框架会复制到结果报告，但不解释其中键值。
@export var metadata: Dictionary = {}

## 可选发送者路径；为空时使用当前节点。
## [br]
## @api public
## [br]
## @since 3.17.0
@export_node_path("Node") var sender_path: NodePath = NodePath("")


# --- 公共方法 ---

## 构建交互上下文。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @param target: 交互目标。
## [br]
## @param payload_override: 覆盖 payload；为 null 时使用节点默认 payload。
## [br]
## @schema payload_override: 覆盖默认 payload 的任意项目载荷；为 null 时复制节点默认 payload。
## [br]
## @param group_override: 覆盖分组；为空时使用节点默认分组。
## [br]
## @return: 交互上下文。
func build_context(
	target: Object = null,
	payload_override: Variant = null,
	group_override: StringName = &""
) -> GFInteractionContext:
	var context_payload: Variant = payload.duplicate(true) if payload_override == null else GFVariantData.duplicate_variant(payload_override)
	var context_group: StringName = group_override if group_override != &"" else group_name
	var context: GFInteractionContext = GFInteractionContext.new(_resolve_sender(), target, context_payload, context_group)
	return context


## 向指定接收对象发送交互。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @param receiver: 接收对象。
## [br]
## @param payload_override: 覆盖 payload；为 null 时使用节点默认 payload。
## [br]
## @schema payload_override: 覆盖默认 payload 的任意项目载荷；为 null 时复制节点默认 payload。
## [br]
## @param interaction_id_override: 覆盖交互 ID；为空时使用节点默认交互 ID。
## [br]
## @return: 统一结果报告。
## [br]
## @schema return: 交互结果报告 Dictionary，包含 ok、interaction_id、receiver(JSON-safe 摘要)、reason、message 和 metadata 等字段。
func send_to(
	receiver: Object,
	payload_override: Variant = null,
	interaction_id_override: StringName = &""
) -> Dictionary:
	var effective_interaction_id: StringName = interaction_id_override if interaction_id_override != &"" else interaction_id
	var context: GFInteractionContext = build_context(receiver, payload_override)
	var report: Dictionary = _MESSAGE_DISPATCH_SUPPORT._dispatch_to_receiver(
		enabled,
		metadata,
		receiver,
		&"receive_interaction",
		[context, effective_interaction_id],
		"interaction_id",
		effective_interaction_id,
		"Interaction sensor is disabled.",
		"Interaction receiver is null.",
		"Receiver does not expose receive_interaction().",
		"Receiver returned an invalid interaction report."
	)
	report = _normalize_report(report, receiver)
	_emit_send_result(context, receiver, report)
	return report


## 向指定节点路径发送交互。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @param receiver_path: 接收节点路径。
## [br]
## @param payload_override: 覆盖 payload；为 null 时使用节点默认 payload。
## [br]
## @schema payload_override: 覆盖默认 payload 的任意项目载荷；为 null 时复制节点默认 payload。
## [br]
## @param interaction_id_override: 覆盖交互 ID；为空时使用节点默认交互 ID。
## [br]
## @return: 统一结果报告。
## [br]
## @schema return: 交互结果报告 Dictionary，包含 ok、interaction_id、receiver(JSON-safe 摘要)、reason、message 和 metadata 等字段。
func send_to_path(
	receiver_path: NodePath,
	payload_override: Variant = null,
	interaction_id_override: StringName = &""
) -> Dictionary:
	var receiver: Node = get_node_or_null(receiver_path)
	return send_to(receiver, payload_override, interaction_id_override)


## 向场景树分组中的接收对象广播交互。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @param target_group_name: 目标分组；为空时使用节点默认分组。
## [br]
## @param max_count: 最多发送数量；小于等于 0 表示不限制。
## [br]
## @return: 结果报告列表。
## [br]
## @schema return: 交互结果报告字典数组；每项包含 ok、interaction_id、receiver(JSON-safe 摘要)、reason、message 和 metadata 等字段。
func broadcast_to_group(target_group_name: StringName = &"", max_count: int = 0) -> Array[Dictionary]:
	var effective_group: StringName = target_group_name if target_group_name != &"" else group_name
	var reports: Array[Dictionary] = []
	if effective_group == &"" or get_tree() == null:
		return reports

	var receivers: Array[Node] = get_tree().get_nodes_in_group(String(effective_group))
	var dispatch_host: Object = _resolve_collision_dispatch_host()
	var accepted_count: int = 0
	for receiver: Node in receivers:
		if max_count > 0 and accepted_count >= max_count:
			break
		var report: Dictionary = _get_report_value(_send_to_with_dispatch_host(dispatch_host, receiver, null, &""))
		if not report.is_empty():
			reports.append(report)
			if GFVariantData.get_option_bool(report, "ok"):
				accepted_count += 1
	return reports


## 向候选 provider 返回的最佳接收对象发送交互。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param candidate_provider: 暴露 get_candidate_objects(options) 的候选 provider。
## [br]
## @param options: 候选查询选项；未设置 method_name 时默认筛选 receive_interaction。
## [br]
## @schema options: Dictionary passed to candidate_provider.get_candidate_objects(); method_name defaults to receive_interaction.
## [br]
## @param payload_override: 覆盖 payload；为 null 时使用节点默认 payload。
## [br]
## @schema payload_override: 覆盖默认 payload 的任意项目载荷；为 null 时复制节点默认 payload。
## [br]
## @param interaction_id_override: 覆盖交互 ID；为空时使用节点默认交互 ID。
## [br]
## @return: 统一结果报告。
## [br]
## @schema return: 交互结果报告 Dictionary，包含 ok、interaction_id、receiver(JSON-safe 摘要)、reason、message 和 metadata 等字段。
func send_to_best_candidate(
	candidate_provider: Object,
	options: Dictionary = {},
	payload_override: Variant = null,
	interaction_id_override: StringName = &""
) -> Dictionary:
	var candidates: Array[Object] = _get_candidate_provider_objects(candidate_provider, options)
	if candidates.is_empty():
		return _make_report(false, interaction_id_override if interaction_id_override != &"" else interaction_id, "missing_receiver", "Candidate provider returned no receiver.")
	return send_to(candidates[0], payload_override, interaction_id_override)


## 向候选 provider 返回的接收对象广播交互。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param candidate_provider: 暴露 get_candidate_objects(options) 的候选 provider。
## [br]
## @param options: 候选查询选项；未设置 method_name 时默认筛选 receive_interaction。
## [br]
## @schema options: Dictionary passed to candidate_provider.get_candidate_objects(); method_name defaults to receive_interaction.
## [br]
## @param max_count: 最多发送数量；小于等于 0 表示不限制。
## [br]
## @param payload_override: 覆盖 payload；为 null 时使用节点默认 payload。
## [br]
## @schema payload_override: 覆盖默认 payload 的任意项目载荷；为 null 时复制节点默认 payload。
## [br]
## @param interaction_id_override: 覆盖交互 ID；为空时使用节点默认交互 ID。
## [br]
## @return: 结果报告列表。
## [br]
## @schema return: 交互结果报告字典数组；每项包含 ok、interaction_id、receiver(JSON-safe 摘要)、reason、message 和 metadata 等字段。
func broadcast_to_candidates(
	candidate_provider: Object,
	options: Dictionary = {},
	max_count: int = 0,
	payload_override: Variant = null,
	interaction_id_override: StringName = &""
) -> Array[Dictionary]:
	var reports: Array[Dictionary] = []
	var candidates: Array[Object] = _get_candidate_provider_objects(candidate_provider, options)
	var dispatch_host: Object = _resolve_collision_dispatch_host()
	var accepted_count: int = 0
	for receiver: Object in candidates:
		if max_count > 0 and accepted_count >= max_count:
			break
		var report: Dictionary = _get_report_value(_send_to_with_dispatch_host(
			dispatch_host,
			receiver,
			payload_override,
			interaction_id_override
		))
		if not report.is_empty():
			reports.append(report)
			if GFVariantData.get_option_bool(report, "ok"):
				accepted_count += 1
	return reports


## 向 RayCast2D 当前命中的接收对象发送交互。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @param raycast: RayCast2D 节点。
## [br]
## @param payload_override: 覆盖 payload；为 null 时使用节点默认 payload。
## [br]
## @schema payload_override: 覆盖默认 payload 的任意项目载荷；为 null 时复制节点默认 payload。
## [br]
## @param interaction_id_override: 覆盖交互 ID；为空时使用节点默认交互 ID。
## [br]
## @return: 统一结果报告。
## [br]
## @schema return: 交互结果报告 Dictionary，包含 ok、interaction_id、receiver(JSON-safe 摘要)、reason、message 和 metadata 等字段。
func send_to_raycast_2d(
	raycast: RayCast2D,
	payload_override: Variant = null,
	interaction_id_override: StringName = &""
) -> Dictionary:
	if raycast == null or not raycast.is_colliding():
		return _make_report(false, interaction_id_override if interaction_id_override != &"" else interaction_id, "missing_receiver", "RayCast2D is not colliding.")
	return send_to(
		_MESSAGE_DISPATCH_SUPPORT._resolve_receiver(raycast.get_collider(), &"receive_interaction"),
		payload_override,
		interaction_id_override
	)


## 向 RayCast3D 当前命中的接收对象发送交互。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @param raycast: RayCast3D 节点。
## [br]
## @param payload_override: 覆盖 payload；为 null 时使用节点默认 payload。
## [br]
## @schema payload_override: 覆盖默认 payload 的任意项目载荷；为 null 时复制节点默认 payload。
## [br]
## @param interaction_id_override: 覆盖交互 ID；为空时使用节点默认交互 ID。
## [br]
## @return: 统一结果报告。
## [br]
## @schema return: 交互结果报告 Dictionary，包含 ok、interaction_id、receiver(JSON-safe 摘要)、reason、message 和 metadata 等字段。
func send_to_raycast_3d(
	raycast: RayCast3D,
	payload_override: Variant = null,
	interaction_id_override: StringName = &""
) -> Dictionary:
	if raycast == null or not raycast.is_colliding():
		return _make_report(false, interaction_id_override if interaction_id_override != &"" else interaction_id, "missing_receiver", "RayCast3D is not colliding.")
	return send_to(
		_MESSAGE_DISPATCH_SUPPORT._resolve_receiver(raycast.get_collider(), &"receive_interaction"),
		payload_override,
		interaction_id_override
	)


## 向 Area2D 当前重叠的接收对象批量发送交互。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @param area: Area2D 节点。
## [br]
## @param max_count: 最多发送数量；小于等于 0 表示不限制。
## [br]
## @param payload_override: 覆盖 payload；为 null 时使用节点默认 payload。
## [br]
## @schema payload_override: 覆盖默认 payload 的任意项目载荷；为 null 时复制节点默认 payload。
## [br]
## @param interaction_id_override: 覆盖交互 ID；为空时使用节点默认交互 ID。
## [br]
## @return: 结果报告列表。
## [br]
## @schema return: 交互结果报告字典数组；每项包含 ok、interaction_id、receiver(JSON-safe 摘要)、reason、message 和 metadata 等字段。
func broadcast_to_area_2d(
	area: Area2D,
	max_count: int = 0,
	payload_override: Variant = null,
	interaction_id_override: StringName = &""
) -> Array[Dictionary]:
	if area == null:
		return []
	var candidates: Array = []
	candidates.append_array(area.get_overlapping_areas())
	candidates.append_array(area.get_overlapping_bodies())
	var dispatch_host: Object = _resolve_collision_dispatch_host()
	var reports: Array[Dictionary] = []
	reports.assign(_MESSAGE_DISPATCH_SUPPORT._send_to_collision_candidates(
		dispatch_host,
		candidates,
		max_count,
		payload_override,
		interaction_id_override,
		&"receive_interaction",
		Callable(self, "_emit_collision_dispatch_result") if dispatch_host != self else Callable()
	))
	return reports


## 向 Area3D 当前重叠的接收对象批量发送交互。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @param area: Area3D 节点。
## [br]
## @param max_count: 最多发送数量；小于等于 0 表示不限制。
## [br]
## @param payload_override: 覆盖 payload；为 null 时使用节点默认 payload。
## [br]
## @schema payload_override: 覆盖默认 payload 的任意项目载荷；为 null 时复制节点默认 payload。
## [br]
## @param interaction_id_override: 覆盖交互 ID；为空时使用节点默认交互 ID。
## [br]
## @return: 结果报告列表。
## [br]
## @schema return: 交互结果报告字典数组；每项包含 ok、interaction_id、receiver(JSON-safe 摘要)、reason、message 和 metadata 等字段。
func broadcast_to_area_3d(
	area: Area3D,
	max_count: int = 0,
	payload_override: Variant = null,
	interaction_id_override: StringName = &""
) -> Array[Dictionary]:
	if area == null:
		return []
	var candidates: Array = []
	candidates.append_array(area.get_overlapping_areas())
	candidates.append_array(area.get_overlapping_bodies())
	var dispatch_host: Object = _resolve_collision_dispatch_host()
	var reports: Array[Dictionary] = []
	reports.assign(_MESSAGE_DISPATCH_SUPPORT._send_to_collision_candidates(
		dispatch_host,
		candidates,
		max_count,
		payload_override,
		interaction_id_override,
		&"receive_interaction",
		Callable(self, "_emit_collision_dispatch_result") if dispatch_host != self else Callable()
	))
	return reports


# --- 私有/辅助方法 ---

func _emit_send_result(context: GFInteractionContext, receiver: Object, report: Dictionary) -> void:
	interaction_sent.emit(context, receiver, report)
	if GFVariantData.get_option_bool(report, "ok"):
		interaction_accepted.emit(context, receiver, report)
	else:
		interaction_rejected.emit(context, receiver, report)


func _emit_collision_dispatch_result(
	receiver: Object,
	payload_override: Variant,
	_interaction_id_override: StringName,
	report: Dictionary
) -> void:
	_emit_send_result(build_context(receiver, payload_override), receiver, report)


func _get_candidate_provider_objects(candidate_provider: Object, options: Dictionary) -> Array[Object]:
	var objects: Array[Object] = []
	if candidate_provider == null or not candidate_provider.has_method("get_candidate_objects"):
		return objects

	var query_options: Dictionary = options.duplicate(true)
	if not query_options.has("method_name"):
		query_options["method_name"] = &"receive_interaction"
	var value: Variant = candidate_provider.call("get_candidate_objects", query_options)
	if not (value is Array):
		return objects

	for candidate_value: Variant in GFVariantData.as_array(value):
		if not (candidate_value is Object):
			continue
		var candidate: Object = candidate_value
		var receiver: Object = _MESSAGE_DISPATCH_SUPPORT._resolve_receiver(candidate, &"receive_interaction")
		if receiver == null or objects.has(receiver):
			continue
		objects.append(receiver)
	return objects


func _make_report(ok: bool, effective_interaction_id: StringName, reason: String, message: String) -> Dictionary:
	return _normalize_report({
		"ok": ok,
		"interaction_id": effective_interaction_id,
		"receiver": null,
		"reason": reason,
		"message": message,
		"metadata": metadata,
	}, null)


func _resolve_sender() -> Object:
	if sender_path != NodePath(""):
		var sender: Node = get_node_or_null(sender_path)
		if sender != null:
			return sender
	return self


func _resolve_collision_dispatch_host() -> Object:
	var sender: Object = _resolve_sender()
	if sender != self and _can_use_send_to_override(sender):
		return sender
	return self


func _send_to_with_dispatch_host(
	dispatch_host: Object,
	receiver: Object,
	payload_override: Variant,
	interaction_id_override: StringName
) -> Variant:
	if dispatch_host == null or not dispatch_host.has_method(&"send_to"):
		return null
	var report_value: Variant = dispatch_host.call("send_to", receiver, payload_override, interaction_id_override)
	if not report_value is Dictionary:
		var invalid_report: Dictionary = _make_report(false, interaction_id_override if interaction_id_override != &"" else interaction_id, "invalid_report", "Dispatch host returned a non-Dictionary interaction report.")
		if dispatch_host != self:
			_emit_collision_dispatch_result(receiver, payload_override, interaction_id_override, invalid_report)
		return invalid_report
	var report: Dictionary = GFVariantData.as_dictionary(report_value)
	if report.is_empty():
		report = _make_report(false, interaction_id_override if interaction_id_override != &"" else interaction_id, "invalid_report", "Dispatch host returned an empty interaction report.")
	report = _normalize_report(report, receiver)
	if dispatch_host != self:
		_emit_collision_dispatch_result(receiver, payload_override, interaction_id_override, report)
	return report


func _get_report_value(value: Variant) -> Dictionary:
	return _normalize_report(GFVariantData.as_dictionary(value), null)


func _can_use_send_to_override(candidate: Object) -> bool:
	if candidate == null or not candidate.has_method(&"send_to"):
		return false
	for method_value: Dictionary in candidate.get_method_list():
		var method_name: StringName = GFVariantData.to_string_name(GFVariantData.get_option_value(method_value, "name", &""))
		if method_name != &"send_to":
			continue
		return _method_accepts_argument_count(method_value, 3)
	return false


func _normalize_report(report: Dictionary, default_receiver: Object) -> Dictionary:
	if report.is_empty():
		return {}
	var raw_report: Dictionary = report.duplicate(false)
	if not raw_report.has("receiver") and default_receiver != null:
		raw_report["receiver"] = default_receiver
	return GFReportValueCodec.to_report_dictionary(raw_report, {
		"path_redaction": "basename",
	})


func _method_accepts_argument_count(method_info: Dictionary, argument_count: int) -> bool:
	var arguments: Array = GFVariantData.get_option_array(method_info, "args")
	var default_arguments: Array = GFVariantData.get_option_array(method_info, "default_args")
	var required_count: int = maxi(arguments.size() - default_arguments.size(), 0)
	var method_flags: int = GFVariantData.get_option_int(method_info, "flags", 0)
	var accepts_varargs: bool = (method_flags & METHOD_FLAG_VARARG) != 0
	return required_count <= argument_count and (argument_count <= arguments.size() or accepts_varargs)
