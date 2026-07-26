# 扩展消息接收节点共享实现。
#
# 该脚本供命中、交互等通用接收节点复用，不直接作为用户继承入口。
extends RefCounted


# --- 常量 ---

const _REPORT_SCHEMA_PROJECTION = preload(
	"res://addons/gf/kernel/core/gf_report_schema_projection.gd"
)


# --- 私有/辅助方法 ---

static func _can_receive(
	enabled: bool,
	accepted_ids: Array[StringName],
	rejected_ids: Array[StringName],
	id_value: StringName = &""
) -> bool:
	if not enabled:
		return false
	if rejected_ids.has(id_value):
		return false
	if accepted_ids.is_empty():
		return true
	return accepted_ids.has(id_value)


static func _receive(
	signal_owner: Object,
	context: Object,
	id_key: String,
	id_value: StringName,
	enabled: bool,
	accepted_ids: Array[StringName],
	rejected_ids: Array[StringName],
	metadata: Dictionary,
	validation_callback: Callable,
	validating_emitter: Callable,
	received_emitter: Callable,
	rejected_emitter: Callable,
	invalid_context_message: String,
	disabled_message: String,
	rejected_id_message: String,
	unaccepted_id_message: String
) -> Dictionary:
	return _receive_with_delegate(
		signal_owner,
		context,
		id_key,
		id_value,
		enabled,
		accepted_ids,
		rejected_ids,
		metadata,
		validation_callback,
		validating_emitter,
		received_emitter,
		rejected_emitter,
		invalid_context_message,
		disabled_message,
		rejected_id_message,
		unaccepted_id_message,
		false,
		null,
		&"",
		[],
		"",
		""
	)


static func _receive_with_delegate(
	signal_owner: Object,
	context: Object,
	id_key: String,
	id_value: StringName,
	enabled: bool,
	accepted_ids: Array[StringName],
	rejected_ids: Array[StringName],
	metadata: Dictionary,
	validation_callback: Callable,
	validating_emitter: Callable,
	received_emitter: Callable,
	rejected_emitter: Callable,
	invalid_context_message: String,
	disabled_message: String,
	rejected_id_message: String,
	unaccepted_id_message: String,
	delegate_enabled: bool,
	delegate_receiver: Object,
	delegate_method: StringName,
	delegate_args: Array,
	missing_delegate_message: String,
	invalid_delegate_report_message: String,
	target_property: StringName = &"target",
	normalize_output: bool = true
) -> Dictionary:
	if context == null:
		var invalid_context_report: Dictionary = _make_report(
			signal_owner,
			false,
			id_key,
			id_value,
			"invalid_context",
			invalid_context_message,
			metadata
		)
		return _emit_and_return_report(
			context,
			invalid_context_report,
			signal_owner,
			rejected_emitter,
			normalize_output
		)

	if not enabled:
		var disabled_report: Dictionary = _make_report(
			signal_owner,
			false,
			id_key,
			id_value,
			"disabled",
			disabled_message,
			metadata
		)
		return _emit_and_return_report(
			context,
			disabled_report,
			signal_owner,
			rejected_emitter,
			normalize_output
		)

	if rejected_ids.has(id_value):
		var rejected_report: Dictionary = _make_report(
			signal_owner,
			false,
			id_key,
			id_value,
			"rejected_id",
			rejected_id_message,
			metadata
		)
		return _emit_and_return_report(
			context,
			rejected_report,
			signal_owner,
			rejected_emitter,
			normalize_output
		)

	if not accepted_ids.is_empty() and not accepted_ids.has(id_value):
		var blocked_report: Dictionary = _make_report(
			signal_owner,
			false,
			id_key,
			id_value,
			"unaccepted_id",
			unaccepted_id_message,
			metadata
		)
		return _emit_and_return_report(
			context,
			blocked_report,
			signal_owner,
			rejected_emitter,
			normalize_output
		)

	if delegate_enabled and delegate_receiver == null:
		var missing_delegate_report: Dictionary = _make_report(null, false, id_key, id_value, "missing_receiver", missing_delegate_message, metadata)
		return _emit_and_return_report(
			context,
			missing_delegate_report,
			null,
			rejected_emitter,
			normalize_output
		)

	var effective_receiver: Object = delegate_receiver if delegate_enabled else signal_owner
	var target_key: String = String(target_property)
	var target_value: Variant = _get_object_property(context, target_key)
	if target_value == null or target_value == signal_owner:
		context.set(target_key, effective_receiver)

	var report: Dictionary = _make_report(
		effective_receiver,
		true,
		id_key,
		id_value,
		"accepted",
		"",
		metadata
	)
	validating_emitter.call(
		context,
		_normalize_report(report, effective_receiver).duplicate(true)
	)
	if validation_callback.is_valid():
		report = _apply_validation_result(report, validation_callback.call(context, report.duplicate(false)))

	if _report_is_ok(report) and delegate_enabled and delegate_receiver.has_method(delegate_method):
		var delegated_value: Variant = delegate_receiver.callv(delegate_method, delegate_args)
		if delegated_value is Dictionary:
			report = GFVariantData.as_dictionary(delegated_value).duplicate(false)
		elif delegated_value is bool:
			report = _apply_validation_result(report, delegated_value)
		elif delegated_value == null:
			pass
		else:
			report = _make_report(
				delegate_receiver,
				false,
				id_key,
				id_value,
				"invalid_report",
				invalid_delegate_report_message,
				metadata
			)
	var report_receiver: Object = delegate_receiver if delegate_enabled else effective_receiver
	var result_emitter: Callable = received_emitter if _report_is_ok(report) else rejected_emitter
	return _emit_and_return_report(
		context,
		report,
		report_receiver,
		result_emitter,
		normalize_output
	)


static func _make_report(
	receiver: Object,
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
		"receiver": receiver,
		"reason": reason,
		"message": message,
		"metadata": metadata.duplicate(false),
	}


static func _apply_validation_result(report: Dictionary, validation_result: Variant) -> Dictionary:
	if validation_result is bool:
		report["ok"] = GFVariantData.to_bool(validation_result)
		if not GFVariantData.to_bool(validation_result) and GFVariantData.get_option_string(report, "reason").is_empty():
			report["reason"] = "validation_failed"
		return report

	if not validation_result is Dictionary:
		return report

	var result: Dictionary = GFVariantData.as_dictionary(validation_result)
	for key: Variant in result.keys():
		if key == "metadata" and result[key] is Dictionary:
			var merged_metadata: Dictionary = GFVariantData.as_dictionary(GFVariantData.get_option_value(report, "metadata", {})).duplicate(false)
			var result_metadata: Dictionary = GFVariantData.as_dictionary(result[key])
			for metadata_key: Variant in result_metadata.keys():
				merged_metadata[metadata_key] = result_metadata[metadata_key]
			report["metadata"] = merged_metadata
		else:
			report[key] = result[key]
	return report


static func _report_is_ok(report: Dictionary) -> bool:
	return GFVariantData.get_option_bool(report, "ok", false)


static func _get_object_property(target: Object, property_name: String) -> Variant:
	if target == null or property_name.is_empty():
		return null
	return target.get_indexed(NodePath(property_name))


static func _normalize_report(report: Dictionary, default_receiver: Object) -> Dictionary:
	return _REPORT_SCHEMA_PROJECTION.to_report_dictionary(
		_prepare_raw_report(report, default_receiver),
		{
			"path_redaction": "basename",
		}
	)


static func _prepare_raw_report(report: Dictionary, default_receiver: Object) -> Dictionary:
	var result: Dictionary = report.duplicate(false)
	result["receiver"] = default_receiver
	return result


static func _emit_and_return_report(
	context: Object,
	raw_report: Dictionary,
	default_receiver: Object,
	emitter: Callable,
	normalize_output: bool
) -> Dictionary:
	var prepared_report: Dictionary = _prepare_raw_report(raw_report, default_receiver)
	var normalized_report: Dictionary = _normalize_report(prepared_report, default_receiver)
	emitter.call(context, normalized_report.duplicate(true))
	return normalized_report if normalize_output else prepared_report
