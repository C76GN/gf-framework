## GFSignalBridge: 声明式信号到 Callable 的桥接资源。
##
## 桥接只描述信号来源、目标方法、参数重排和常量参数。它不修改场景结构、
## 不解释信号业务含义，也不要求调用方使用特定 UI 或状态机。
## [br]
## @api public
## [br]
## @category resource_definition
## [br]
## @since 3.17.0
class_name GFSignalBridge
extends Resource


# --- 导出变量 ---

## 桥接 ID，便于调试和项目侧索引。
## [br]
## @api public
@export var bridge_id: StringName = &""

## 是否启用该桥接。
## [br]
## @api public
@export var enabled: bool = true

## 信号来源引用。
## [br]
## @api public
@export var source: GFSignalSourceRef = GFSignalSourceRef.new()

## 调用目标引用。
## [br]
## @api public
@export var target: GFCallableTargetRef = GFCallableTargetRef.new()

## 要从原始信号参数中抽取的索引。为空时透传全部信号参数。
## [br]
## @api public
@export var argument_indices: PackedInt32Array = PackedInt32Array()

## 追加到桥接参数末尾的常量参数。
## [br]
## @api public
## [br]
## @schema constant_args: Array，追加在选中信号参数后的固定参数。
@export var constant_args: Array = []

## 是否把桥接上下文字典追加到参数末尾。
## [br]
## @api public
@export var append_context: bool = false

## 是否只触发一次。
## [br]
## @api public
@export var one_shot: bool = false

## Godot 信号连接标记。
## [br]
## @api public
@export var connect_flags: int = 0

## 项目自定义元数据。框架不解释该字段。
## [br]
## @api public
## [br]
## @schema metadata: Dictionary，关联到信号桥的项目侧元数据。
@export var metadata: Dictionary = {}


# --- 公共方法 ---

## 连接桥接。
## [br]
## @api public
## [br]
## @param root: 路径解析根节点。
## [br]
## @param owner: 可选连接拥有者。
## [br]
## @param signal_utility: 可选 GFSignalUtility；为空时创建独立连接。
## [br]
## @return 运行中的桥接绑定；失败时返回 null。
func connect_bridge(
	root: Node,
	owner: Object = null,
	signal_utility: GFSignalUtility = null
) -> GFSignalBridgeBinding:
	if not enabled:
		return null
	if source == null or target == null:
		return null

	var source_signal: Signal = source.get_signal(root)
	if source_signal.is_null() or not target.is_valid_for(root):
		return null

	var binding: GFSignalBridgeBinding = GFSignalBridgeBinding.new()
	var callback: Callable = Callable(binding, "_invoke_from_signal")
	var connection: GFSignalConnection = null
	if signal_utility != null:
		connection = signal_utility.connect_signal(source_signal, callback, owner, [], connect_flags)
	else:
		connection = GFSignalConnection.new(source_signal, callback, owner, [], connect_flags)
		var _started: GFSignalConnection = connection.start()

	if connection == null or not connection.is_active():
		return null
	if one_shot:
		var _once_result_111: Variant = connection.once()

	binding.setup(self, root, connection)
	return binding


## 直接执行桥接调用。
## [br]
## @api public
## [br]
## @param root: 路径解析根节点。
## [br]
## @param signal_args: 原始信号参数。
## [br]
## @return 结构化调用结果。
## [br]
## @schema signal_args: Array，来源信号发出的原始参数。
## [br]
## @schema return: Dictionary，包含 ok、reason、value、bridge_id 和 args。
func invoke(root: Node, signal_args: Array = []) -> Dictionary:
	if not enabled:
		return _make_result(false, &"disabled", null)
	if target == null:
		return _make_result(false, &"missing_target", null)

	var args: Array = build_callable_args(signal_args)
	var call_result: Dictionary = target.call_with_args(root, args)
	return {
		"ok": GFVariantData.get_option_bool(call_result, "ok"),
		"reason": GFVariantData.get_option_string_name(call_result, "reason", &"ok"),
		"value": GFVariantData.get_option_value(call_result, "value"),
		"bridge_id": bridge_id,
		"args": args,
	}


## 构建目标 Callable 参数。
## [br]
## @api public
## [br]
## @param signal_args: 原始信号参数。
## [br]
## @return 映射后的参数。
## [br]
## @schema signal_args: Array，来源信号发出的原始参数。
## [br]
## @schema return: Array，传给目标 Callable 且位于 target.default_args 之前的参数。
func build_callable_args(signal_args: Array = []) -> Array:
	var args: Array = []
	if argument_indices.is_empty():
		args.append_array(signal_args)
	else:
		for index: int in argument_indices:
			args.append(signal_args[index] if index >= 0 and index < signal_args.size() else null)
	args.append_array(constant_args)
	if append_context:
		args.append(_make_context(signal_args))
	return args


## 获取校验报告。
## [br]
## @api public
## [br]
## @param root: 路径解析根节点。
## [br]
## @return 兼容 GFValidationReportDictionary 的报告字典。
## [br]
## @schema return: GFValidationReportDictionary 兼容 Dictionary，包含 subject、bridge_id、issues、counts、summary 和 next_action。
func get_validation_report(root: Node) -> Dictionary:
	var report: Dictionary = {
		"subject": "Signal bridge",
		"bridge_id": bridge_id,
		"issues": [],
	}
	var source_is_valid: bool = false
	if source == null:
		_append_validation_issue(report, &"missing_source", "source", "Signal bridge source is missing.")
	elif not source.is_valid_for(root):
		_append_validation_issue(report, &"invalid_source_signal", "source", "Signal bridge source signal is invalid.")
	else:
		source_is_valid = true

	var target_is_valid: bool = false
	if target == null:
		_append_validation_issue(report, &"missing_target", "target", "Signal bridge target is missing.")
	elif not target.is_valid_for(root):
		_append_validation_issue(report, &"invalid_callable_target", "target", "Signal bridge target callable is invalid.")
	else:
		target_is_valid = true

	var signal_argument_count: int = source.get_signal_argument_count(root) if source_is_valid else -1
	_validate_argument_indices(report, signal_argument_count)
	if target_is_valid:
		_validate_callable_argument_count(report, root, signal_argument_count)

	return GFValidationReportDictionary.finalize_report(report, "Signal bridge", {
		"include_issue_count": true,
		"next_actions": _get_validation_next_actions(),
	})


## 转换为调试字典。
## [br]
## @api public
## [br]
## @return 桥接快照。
## [br]
## @schema return: Dictionary，包含 bridge_id、enabled、source、target、argument_indices、constant_args、append_context、one_shot 和 metadata。
func to_dictionary() -> Dictionary:
	return {
		"bridge_id": bridge_id,
		"enabled": enabled,
		"source": source.to_dictionary() if source != null else {},
		"target": target.to_dictionary() if target != null else {},
		"argument_indices": argument_indices,
		"constant_args": constant_args.duplicate(true),
		"append_context": append_context,
		"one_shot": one_shot,
		"metadata": metadata.duplicate(true),
	}


# --- 私有/辅助方法 ---

## 构造传给目标方法的桥接上下文字典。
## [br]
## @api private
## [br]
func _make_context(signal_args: Array) -> Dictionary:
	return {
		"bridge_id": bridge_id,
		"source_path": source.source_path if source != null else NodePath(""),
		"signal_name": source.signal_name if source != null else &"",
		"signal_args": signal_args.duplicate(true),
		"metadata": metadata.duplicate(true),
	}


## 创建带桥接 ID 的直接调用结果字典。
## [br]
## @api private
## [br]
func _make_result(ok: bool, reason: StringName, value: Variant) -> Dictionary:
	return {
		"ok": ok,
		"reason": reason,
		"value": value,
		"bridge_id": bridge_id,
	}


## 将负索引及已知参数范围之外的索引追加为校验问题。
## [br]
## @api private
## [br]
func _validate_argument_indices(report: Dictionary, signal_argument_count: int) -> void:
	for argument_index: int in argument_indices:
		if argument_index < 0:
			_append_validation_issue(
				report,
				&"negative_argument_index",
				"argument_indices",
				"Signal bridge argument index cannot be negative.",
				{ "argument_index": argument_index }
			)
		elif signal_argument_count >= 0 and argument_index >= signal_argument_count:
			_append_validation_issue(
				report,
				&"argument_index_out_of_range",
				"argument_indices",
				"Signal bridge argument index %d is outside the source signal argument count %d." % [
					argument_index,
					signal_argument_count,
				],
				{
					"argument_index": argument_index,
					"signal_argument_count": signal_argument_count,
				}
			)


## 根据目标方法元数据检查桥接提供的参数个数是否满足 required、maximum 和 vararg 约束。
## [br]
## @api private
## [br]
func _validate_callable_argument_count(report: Dictionary, root: Node, signal_argument_count: int) -> void:
	var provided_argument_count: int = _get_provided_callable_argument_count(signal_argument_count)
	if provided_argument_count < 0:
		return

	var target_object: Object = target.resolve_target(root)
	if target_object == null:
		return

	for method_info: Dictionary in target_object.get_method_list():
		if GFVariantData.get_option_string_name(method_info, "name") != target.method_name:
			continue

		var method_args: Array = GFVariantData.get_option_array(method_info, "args")
		var default_args: Array = GFVariantData.get_option_array(method_info, "default_args")
		var required_argument_count: int = maxi(method_args.size() - default_args.size(), 0)
		var maximum_argument_count: int = method_args.size()
		var accepts_extra_args: bool = (GFVariantData.get_option_int(method_info, "flags") & METHOD_FLAG_VARARG) != 0
		if provided_argument_count >= required_argument_count and (accepts_extra_args or provided_argument_count <= maximum_argument_count):
			return

		_append_validation_issue(
			report,
			&"callable_argument_mismatch",
			"target",
			"Signal bridge provides %d argument(s), but target method expects %d-%s." % [
				provided_argument_count,
				required_argument_count,
				"*" if accepts_extra_args else str(maximum_argument_count),
			],
			{
				"provided_argument_count": provided_argument_count,
				"required_argument_count": required_argument_count,
				"maximum_argument_count": maximum_argument_count,
				"accepts_extra_args": accepts_extra_args,
			}
		)
		return


## 统计信号映射参数、常量、上下文和目标默认参数的总数；信号参数数未知且未选择索引时返回 -1。
## [br]
## @api private
## [br]
func _get_provided_callable_argument_count(signal_argument_count: int) -> int:
	var count: int = 0
	if argument_indices.is_empty():
		if signal_argument_count < 0:
			return -1
		count = signal_argument_count
	else:
		count = argument_indices.size()
	count += constant_args.size()
	if append_context:
		count += 1
	if target != null:
		count += target.default_args.size()
	return count


## 添加包含 bridge_id 与路径的错误问题，并合并额外字段。
## [br]
## @api private
## [br]
func _append_validation_issue(
	report: Dictionary,
	kind: StringName,
	path: String,
	message: String,
	fields: Dictionary = {}
) -> void:
	var issue_fields: Dictionary = {
		"bridge_id": bridge_id,
		"path": path,
	}
	issue_fields.merge(fields, true)
	var _append_issue_result_349: Variant = GFValidationReportDictionary.append_issue(report, "error", kind, message, issue_fields)


## 返回信号桥接校验问题类型到建议操作的映射。
## [br]
## @api private
## [br]
func _get_validation_next_actions() -> Dictionary:
	return {
		"missing_source": "Assign a GFSignalSourceRef before connecting the bridge.",
		"invalid_source_signal": "Check the source path and signal name against the bridge root.",
		"missing_target": "Assign a GFCallableTargetRef before connecting the bridge.",
		"invalid_callable_target": "Check the target path and method name against the bridge root.",
		"negative_argument_index": "Remove negative values from argument_indices.",
		"argument_index_out_of_range": "Keep argument_indices within the source signal argument list.",
		"callable_argument_mismatch": "Adjust argument_indices, constant_args, append_context, or the target method signature.",
	}
