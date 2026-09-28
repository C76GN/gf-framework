# 扩展消息发送节点共享实现。
#
# 该脚本供命中、交互等场景桥接节点复用，不直接作为用户继承入口。
extends RefCounted


# --- 常量 ---

## 向父节点查找消息接收者时允许检查的最大链深。
## [br]
## @api private
const _MAX_PARENT_RECEIVER_DEPTH: int = 128


# --- 框架内部方法 ---

## 供命中与交互节点同步分发消息；先检查启用状态、接收者和方法，再按原顺序调用参数。只接受非空字典返回；失败时构造带原因的报告，成功时浅复制接收者报告并补齐 receiver。normalize_output 启用时还转换 receiver 和字典 metadata。
## [br]
## @api framework_internal
## [br]
## @layer standard/common
## [br]
## @param enabled: 是否允许调用接收者；关闭时返回 disabled 报告。
## [br]
## @param metadata: 构造失败报告时浅复制保存的附加数据。
## [br]
## @param receiver: 消息接收对象；null 返回 missing_receiver，缺少方法返回 invalid_receiver。
## [br]
## @param receiver_method: 同步调用的接收方法名。
## [br]
## @param call_args: 原样传给接收方法的有序参数数组。
## [br]
## @param id_key: 失败报告中的动态消息标识键，由调用方避开固定报告字段。
## [br]
## @param id_value: 失败报告中的消息标识值。
## [br]
## @param disabled_message: 未启用时的错误说明。
## [br]
## @param missing_receiver_message: 未提供接收者时的错误说明。
## [br]
## @param invalid_receiver_message: 接收者缺少方法时的错误说明。
## [br]
## @param invalid_report_message: 接收方法返回空字典或非字典时的错误说明。
## [br]
## @param normalize_output: 是否把 receiver 和字典 metadata 转为报告值，并使用 basename 路径脱敏。
## [br]
## @return: 接收者报告的浅复制，或本入口生成的失败报告；不会直接返回原字典容器。
## [br]
## @schema metadata: 调用方定义的附加数据字典；失败报告保留浅副本，启用规范化时再交给 GFReportValueCodec 转换。
## [br]
## @schema call_args: 由 receiver_method 契约决定的参数顺序与值，不在此处校验或复制。
## [br]
## @schema return: 接收者返回的非空字典仅补齐 receiver，并按选项转换 receiver/metadata，不补齐其他业务键；入口失败报告含 ok=false、动态 id_key、receiver=null、reason、message 和 metadata。
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
	invalid_report_message: String,
	normalize_output: bool = true
) -> Dictionary:
	if not enabled:
		return _make_report(false, id_key, id_value, "disabled", disabled_message, metadata, normalize_output)
	if receiver == null:
		return _make_report(false, id_key, id_value, "missing_receiver", missing_receiver_message, metadata, normalize_output)
	if not receiver.has_method(receiver_method):
		return _make_report(false, id_key, id_value, "invalid_receiver", invalid_receiver_message, metadata, normalize_output)

	var value: Variant = receiver.callv(receiver_method, call_args)
	if value is Dictionary:
		var report: Dictionary = GFVariantData.as_dictionary(value)
		if not report.is_empty():
			return _normalize_report(report, receiver) if normalize_output else _prepare_raw_report(report, receiver)
	return _make_report(
		false,
		id_key,
		id_value,
		"invalid_report",
		invalid_report_message,
		metadata,
		normalize_output
	)


## 供碰撞桥接节点按候选顺序查找并去重接收者，逐个同步调用宿主 send_to。max_count 限制收集的字典报告数；已尝试的接收者即使未返回字典也不再重试。报告追加后才调用可选结果回调；开启规范化时仅在回调有效的分支再次规范化，关闭时保留对象引用并补齐 receiver。
## [br]
## @api framework_internal
## [br]
## @layer standard/common
## [br]
## @param dispatch_host: 提供 send_to(receiver, payload_override, id_override) 方法的有效宿主。
## [br]
## @param candidates: 按遍历顺序尝试的 Object 候选数组，可含 null。
## [br]
## @param max_count: 正数限制报告数量；零或负数表示不限制。
## [br]
## @param payload_override: 原样传给宿主与结果回调的消息载荷覆盖值。
## [br]
## @param id_override: 原样传给宿主与结果回调的消息标识覆盖值。
## [br]
## @param receiver_method: 沿候选自身及 Node 父链识别接收者的方法名。
## [br]
## @param send_result_callback: 有效时以 receiver、payload_override、id_override、report 为参数同步调用。
## [br]
## @param normalize_reports: 是否在有效回调前规范化报告；为 false 时浅复制报告并补齐原始 receiver。
## [br]
## @return: 按发送顺序收集的字典报告数组；非字典返回值忽略，空字典仍可计入。
## [br]
## @schema candidates: Object 元素构成的数组；接收者按实例 ID 去重，候选自身无目标方法时仅 Node 可继续沿父链查找。
## [br]
## @schema payload_override: 由宿主 send_to 契约解释，入口不校验、不复制。
## [br]
## @schema return: 各项字段由宿主 send_to 定义；按 normalize_reports 与回调有效性保留原报告或处理 receiver/metadata，回调收到的字典与数组中的该项共享。
static func _send_to_collision_candidates(
	dispatch_host: Object,
	candidates: Array,
	max_count: int,
	payload_override: Variant,
	id_override: StringName,
	receiver_method: StringName,
	send_result_callback: Callable = Callable(),
	normalize_reports: bool = true
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
			if normalize_reports:
				if send_result_callback.is_valid():
					report = _normalize_report(report, receiver)
			else:
				report = _prepare_raw_report(report, receiver)
			reports.append(report)
			if send_result_callback.is_valid():
				send_result_callback.call(receiver, payload_override, id_override, report)
	return reports


## 供消息桥接节点解析接收者；优先返回自身具备目标方法的候选，否则对 Node 沿父链查找最近匹配项。父链扫描最多检查 128 层，并用实例 ID 检测重复；不转移对象所有权。
## [br]
## @api framework_internal
## [br]
## @layer standard/common
## [br]
## @param candidate: 可空候选对象；调用方负责保证非空引用仍有效。
## [br]
## @param receiver_method: 接收者必须提供的方法名。
## [br]
## @return: 候选自身或最近匹配的 Node 引用；候选为空、无法沿父链查找、达到深度上限、检测到重复或没有匹配时返回 null。
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


# --- 私有/辅助方法 ---

## 创建带 ok、动态 ID 键、receiver、reason、message 和 metadata 的报告。
## [br]
## @api private
static func _make_report(
	ok: bool,
	id_key: String,
	id_value: StringName,
	reason: String,
	message: String,
	metadata: Dictionary,
	normalize_output: bool = true
) -> Dictionary:
	var report: Dictionary = {
		"ok": ok,
		id_key: id_value,
		"receiver": null,
		"reason": reason,
		"message": message,
		"metadata": metadata.duplicate(false),
	}
	return _normalize_report(report, null) if normalize_output else report


## 仅当 Variant 值是 Node 时返回其类型化引用。
## [br]
## @api private
static func _variant_to_node(value: Variant) -> Node:
	if value is Node:
		var node: Node = value
		return node
	return null


## 补齐 receiver 并将 receiver 与 Dictionary metadata 转换为报告可用值。
## [br]
## @api private
static func _normalize_report(report: Dictionary, default_receiver: Object) -> Dictionary:
	var result: Dictionary = _prepare_raw_report(report, default_receiver)
	var receiver_value: Variant = GFVariantData.get_option_value(result, "receiver", default_receiver)
	if receiver_value == null or receiver_value is Object:
		result["receiver"] = _object_to_report_value(receiver_value)
	if result.has("metadata") and result["metadata"] is Dictionary:
		result["metadata"] = _dictionary_to_report_value(GFVariantData.as_dictionary(result["metadata"]))
	return result


## 以浅复制保留报告字段，并仅在 receiver 缺失时填入默认接收者。
## [br]
## @api private
static func _prepare_raw_report(report: Dictionary, default_receiver: Object) -> Dictionary:
	var result: Dictionary = report.duplicate(false)
	if not result.has("receiver"):
		result["receiver"] = default_receiver
	return result


## 使用 basename 路径脱敏选项转换报告中的对象值。
## [br]
## @api private
static func _object_to_report_value(value: Variant) -> Variant:
	return GFReportValueCodec.to_json_compatible(value, {
		"path_redaction": "basename",
	})


## 使用 basename 路径脱敏选项转换报告中的 metadata 字典。
## [br]
## @api private
static func _dictionary_to_report_value(value: Dictionary) -> Dictionary:
	return GFReportValueCodec.to_report_dictionary(value, {
		"path_redaction": "basename",
	})
