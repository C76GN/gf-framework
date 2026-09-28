# 扩展消息接收节点共享实现。
#
# 该脚本供命中、交互等通用接收节点复用，不直接作为用户继承入口。
extends RefCounted


# --- 常量 ---

## 将接收报告投影为共享 schema 并处理路径脱敏的辅助脚本。
## [br]
## @api private
const _REPORT_SCHEMA_PROJECTION = preload(
	"res://addons/gf/kernel/core/gf_report_schema_projection.gd"
)


# --- 框架内部方法 ---

## 按启用状态、拒绝列表和可选接受列表判断是否可接收指定 ID。
## [br]
## @api framework_internal
## [br]
## @param enabled: 接收节点当前是否启用。
## [br]
## @param accepted_ids: 非空时仅接受列表中的 ID；空列表不限制。
## [br]
## @param rejected_ids: 优先拒绝的 ID 列表。
## [br]
## @param id_value: 本次消息 ID，允许为空。
## [br]
## @return 同时通过启用和两类 ID 过滤时返回 true。
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


## 命中与交互接收节点的同步共享流程：先过滤，再验证，再按配置调用委托，最后发送接收或拒绝报告。
## 仅当 context 的目标为空或仍为 signal_owner 时替换目标；保留调用方预先指定的其他目标。
## 验证与结果 emitter 会同步执行用户代码；报告容器复制不等于其中 Object 的所有权转移。
## [br]
## @api framework_internal
## [br]
## @param signal_owner: 承载接收信号的节点，也是无委托时的默认 receiver。
## [br]
## @param context: 传给验证和结果通知的消息上下文；null 立即生成拒绝报告。
## [br]
## @param id_key: 报告中保存消息 ID 的动态字段名。
## [br]
## @param id_value: 用于过滤和报告的消息 ID。
## [br]
## @param enabled: 接收功能开关。
## [br]
## @param accepted_ids: 非空时限制可接收 ID。
## [br]
## @param rejected_ids: 优先拒绝的 ID。
## [br]
## @param metadata: 构造接收报告时复制的附加信息。
## [br]
## @param validation_callback: 可选同步验证器，接收 context 和报告副本；返回 bool 或字段补丁字典。
## [br]
## @param validating_emitter: 必须有效的验证前通知委托，接收 context 和规范化报告副本。
## [br]
## @param received_emitter: 必须有效的成功通知委托，接收 context 和规范化报告副本。
## [br]
## @param rejected_emitter: 必须有效的拒绝通知委托，接收 context 和规范化报告副本。
## [br]
## @param invalid_context_message: context 为空时的诊断文本。
## [br]
## @param disabled_message: 未启用接收时的诊断文本。
## [br]
## @param rejected_id_message: 命中拒绝列表时的诊断文本。
## [br]
## @param unaccepted_id_message: 未命中非空接受列表时的诊断文本。
## [br]
## @param delegate_enabled: 是否把接收动作转交 delegate_receiver。
## [br]
## @param delegate_receiver: 委托目标；启用委托但为空时拒绝。
## [br]
## @param delegate_method: 目标实现该方法时才调用；不存在时保留验证报告。
## [br]
## @param delegate_args: 按原顺序交给 callv 的实参，不在本入口复制。
## [br]
## @param missing_delegate_message: 委托目标为空时的诊断文本。
## [br]
## @param invalid_delegate_report_message: 委托返回非 Dictionary/bool/null 时的诊断文本。
## [br]
## @param target_property: context 中用于补齐有效接收目标的属性名。
## [br]
## @param normalize_output: true 返回规范化报告；false 保留原字段并补齐 receiver。
## [br]
## @return 本次同步接收报告；通知始终使用规范化副本，返回形态由 normalize_output 决定。
## [br]
## @schema metadata: Dictionary，调用方提供的附加字段；结构复制，Object 值保留身份。
## [br]
## @schema delegate_args: Array，delegate_method 的有序实参，可含同一 context 引用。
## [br]
## @schema return: Dictionary，基础字段为 ok、动态 id_key、receiver、reason、message、metadata；委托可替换报告，规范化输出遵循共享 report schema。
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
		report = _apply_validation_result(
			report,
			validation_callback.call(context, _duplicate_dictionary_structure(report))
		)
	elif not validation_callback.is_null():
		report = _apply_validation_result(report, {
			"ok": false,
			"reason": "invalid_validator",
			"message": "Configured validator became invalid before validation.",
		})

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


# --- 私有/辅助方法 ---

## 使用默认 target 属性和未启用委托的参数调用共享接收流程。
## [br]
## @api private
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


## 创建包含接收结果、动态 ID 键、接收者和元数据的报告字典。
## [br]
## @api private
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
		"metadata": _duplicate_dictionary_structure(metadata),
	}


## 将 bool 或 Dictionary 验证结果应用到报告字段和 metadata。
## [br]
## @api private
static func _apply_validation_result(report: Dictionary, validation_result: Variant) -> Dictionary:
	if validation_result is bool:
		report["ok"] = GFVariantData.to_bool(validation_result)
		if not GFVariantData.to_bool(validation_result) and GFVariantData.get_option_string(report, "reason").is_empty():
			report["reason"] = "validation_failed"
		return report

	if not validation_result is Dictionary:
		return report

	var result: Dictionary = _duplicate_dictionary_structure(
		GFVariantData.as_dictionary(validation_result)
	)
	for key: Variant in result.keys():
		if key == "metadata" and result[key] is Dictionary:
			var merged_metadata: Dictionary = _duplicate_dictionary_structure(
				GFVariantData.as_dictionary(
					GFVariantData.get_option_value(report, "metadata", {})
				)
			)
			var result_metadata: Dictionary = GFVariantData.as_dictionary(result[key])
			for metadata_key: Variant in result_metadata.keys():
				merged_metadata[metadata_key] = result_metadata[metadata_key]
			report["metadata"] = merged_metadata
		else:
			report[key] = result[key]
	return report


## 读取报告的 ok 标记，缺少该字段时按 false 处理。
## [br]
## @api private
static func _report_is_ok(report: Dictionary) -> bool:
	return GFVariantData.get_option_bool(report, "ok", false)


## 使用 GFVariantData.duplicate_variant() 处理字典结构并返回 Dictionary。
## [br]
## @api private
static func _duplicate_dictionary_structure(value: Dictionary) -> Dictionary:
	return GFVariantData.as_dictionary(
		GFVariantData.duplicate_variant(value, true, false)
	)


## 通过 NodePath 读取对象属性；对象为空或属性名为空时返回 null。
## [br]
## @api private
static func _get_object_property(target: Object, property_name: String) -> Variant:
	if target == null or property_name.is_empty():
		return null
	return target.get_indexed(NodePath(property_name))


## 准备默认 receiver 后通过共享 schema projection 规范化报告。
## [br]
## @api private
static func _normalize_report(report: Dictionary, default_receiver: Object) -> Dictionary:
	return _REPORT_SCHEMA_PROJECTION.to_report_dictionary(
		_prepare_raw_report(report, default_receiver),
		{
			"path_redaction": "basename",
		}
	)


## 以浅复制保留报告字段，并将 receiver 设置为指定默认对象。
## [br]
## @api private
static func _prepare_raw_report(report: Dictionary, default_receiver: Object) -> Dictionary:
	var result: Dictionary = report.duplicate(false)
	result["receiver"] = default_receiver
	return result


## 规范化报告并发出 emitter，按 normalize_output 选择返回规范化或准备后的字典。
## [br]
## @api private
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
