# 扩展消息发送节点共享实现。
#
# 该脚本供命中、交互等场景桥接节点复用，不直接作为用户继承入口。
extends RefCounted


# --- 常量 ---

const _MAX_PARENT_RECEIVER_DEPTH: int = 128


# --- 私有/辅助方法 ---

static func _dispatch_to_receiver(
	enabled: bool,
	metadata: Dictionary,
	receiver: Object,
	receiver_method: StringName,
	call_args: Array,
	id_key: String,
	id_value: StringName,
	disabled_message: String,
	missing_receiver_message: String,
	invalid_receiver_message: String,
	invalid_report_message: String
) -> Dictionary:
	if not enabled:
		return _make_report(false, id_key, id_value, "disabled", disabled_message, metadata)
	if receiver == null:
		return _make_report(false, id_key, id_value, "missing_receiver", missing_receiver_message, metadata)
	if not receiver.has_method(receiver_method):
		return _make_report(false, id_key, id_value, "invalid_receiver", invalid_receiver_message, metadata)

	var value: Variant = receiver.callv(receiver_method, call_args)
	if value is Dictionary:
		var report: Dictionary = GFVariantData.as_dictionary(value)
		if not report.is_empty():
			return _normalize_report(report, receiver)
	return _make_report(
		false,
		id_key,
		id_value,
		"invalid_report",
		invalid_report_message,
		metadata
	)


static func _send_to_collision_candidates(
	dispatch_host: Object,
	candidates: Array,
	max_count: int,
	payload_override: Variant,
	id_override: StringName,
	receiver_method: StringName,
	send_result_callback: Callable = Callable()
) -> Array[Dictionary]:
	var reports: Array[Dictionary] = []
	var visited_receivers: Dictionary = {}
	for candidate: Object in candidates:
		if max_count > 0 and reports.size() >= max_count:
			break

		var receiver: Object = _resolve_receiver(candidate, receiver_method)
		if receiver == null:
			continue
		var receiver_id: int = receiver.get_instance_id()
		if visited_receivers.has(receiver_id):
			continue
		visited_receivers[receiver_id] = true

		var report_value: Variant = dispatch_host.call("send_to", receiver, payload_override, id_override)
		if report_value is Dictionary:
			var report: Dictionary = GFVariantData.as_dictionary(report_value)
			report = _normalize_report(report, receiver)
			reports.append(report)
			if send_result_callback.is_valid():
				send_result_callback.call(receiver, payload_override, id_override, report)
	return reports


static func _resolve_receiver(candidate: Object, receiver_method: StringName) -> Object:
	if candidate == null:
		return null
	if candidate.has_method(receiver_method):
		return candidate

	var node: Node = _variant_to_node(candidate)
	var visited: Dictionary = {}
	var depth: int = 0
	while node != null and depth < _MAX_PARENT_RECEIVER_DEPTH:
		var instance_id: int = node.get_instance_id()
		if visited.has(instance_id):
			return null
		visited[instance_id] = true
		if node.has_method(receiver_method):
			return node
		node = node.get_parent()
		depth += 1
	return null


static func _make_report(
	ok: bool,
	id_key: String,
	id_value: StringName,
	reason: String,
	message: String,
	metadata: Dictionary
) -> Dictionary:
	return {
		"ok": ok,
		id_key: id_value,
		"receiver": _object_to_report_value(null),
		"reason": reason,
		"message": message,
		"metadata": _dictionary_to_report_value(metadata),
	}


static func _variant_to_node(value: Variant) -> Node:
	if value is Node:
		var node: Node = value
		return node
	return null


static func _normalize_report(report: Dictionary, default_receiver: Object) -> Dictionary:
	var result: Dictionary = report.duplicate(true)
	var receiver_value: Variant = GFVariantData.get_option_value(result, "receiver", default_receiver)
	if receiver_value is Object:
		result["receiver"] = _object_to_report_value(receiver_value)
	elif not result.has("receiver"):
		result["receiver"] = _object_to_report_value(default_receiver)
	if result.has("metadata") and result["metadata"] is Dictionary:
		result["metadata"] = _dictionary_to_report_value(GFVariantData.as_dictionary(result["metadata"]))
	return result


static func _object_to_report_value(value: Variant) -> Variant:
	return GFReportValueCodec.to_json_compatible(value, {
		"path_redaction": "basename",
	})


static func _dictionary_to_report_value(value: Dictionary) -> Dictionary:
	return GFReportValueCodec.to_report_dictionary(value, {
		"path_redaction": "basename",
	})
