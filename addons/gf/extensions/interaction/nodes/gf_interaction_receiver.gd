## GFInteractionReceiver: 通用交互接收节点。
##
## 用 GFInteractionContext 接收任意交互请求，并提供启用状态、交互 ID 过滤、
## 自定义校验回调和统一结果报告。节点不解释任何业务语义。
## [br]
## @api public
## [br]
## @category runtime_handle
## [br]
## @since 3.17.0
class_name GFInteractionReceiver
extends Node


# --- 信号 ---

## 交互进入自定义校验阶段时发出。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @param context: 交互上下文。
## [br]
## @param report: 当前结果报告副本。
## [br]
## @schema report: 交互结果报告 Dictionary，包含 ok、interaction_id、receiver(JSON-safe 摘要)、reason、message 和 metadata 等字段。
signal interaction_validating(context: GFInteractionContext, report: Dictionary)

## 交互被接受时发出。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @param context: 交互上下文。
## [br]
## @param report: 结果报告。
## [br]
## @schema report: 交互结果报告 Dictionary，包含 ok、interaction_id、receiver(JSON-safe 摘要)、reason、message 和 metadata 等字段。
signal interaction_received(context: GFInteractionContext, report: Dictionary)

## 交互被拒绝时发出。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @param context: 交互上下文。
## [br]
## @param report: 结果报告。
## [br]
## @schema report: 交互结果报告 Dictionary，包含 ok、interaction_id、receiver(JSON-safe 摘要)、reason、message 和 metadata 等字段。
signal interaction_rejected(context: GFInteractionContext, report: Dictionary)


# --- 常量 ---

const _MESSAGE_RECEIVER_SUPPORT = preload("res://addons/gf/standard/common/gf_message_receiver_support.gd")


# --- 导出变量 ---

## 是否允许接收交互。
## [br]
## @api public
## [br]
## @since 3.17.0
@export var enabled: bool = true

## 非空时，只接受这些交互 ID。
## [br]
## @api public
## [br]
## @since 3.17.0
@export var accepted_interaction_ids: Array[StringName] = []

## 始终拒绝的交互 ID。
## [br]
## @api public
## [br]
## @since 3.17.0
@export var rejected_interaction_ids: Array[StringName] = []

## 接收器自定义元数据。框架不解释该字段。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @schema metadata: 接收器自定义元数据 Dictionary；框架会复制到结果报告，但不解释其中键值。
@export var metadata: Dictionary = {}

## 可选业务接收节点路径；为空时由当前节点直接接收。
## [br]
## @api public
## [br]
## @since 3.17.0
@export_node_path("Node") var receiver_path: NodePath = NodePath("")


# --- 公共变量 ---

## 自定义校验回调，建议签名为 func(context: GFInteractionContext, report: Dictionary) -> Variant。
## 返回 bool 可直接决定是否接受；返回 Dictionary 可覆盖 ok、reason、metadata 等报告字段。
## 非空回调的 owner 失效时会以 invalid_validator 失败关闭；主动恢复无校验状态必须显式赋值 Callable()。
## [br]
## @api public
## [br]
## @since 3.17.0
var validation_callback: Callable = Callable()


# --- 私有变量 ---

var _framework_raw_dispatch_serial: int = 0
var _framework_raw_dispatch_tokens: Array[Dictionary] = []


# --- 公共方法 ---

## 检查指定交互 ID 是否可被当前接收器接受。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @param interaction_id: 交互 ID。
## [br]
## @return: 可接受时返回 true。
func can_receive_interaction(interaction_id: StringName = &"") -> bool:
	if not bool(_MESSAGE_RECEIVER_SUPPORT._can_receive(
		enabled,
		accepted_interaction_ids,
		rejected_interaction_ids,
		interaction_id
	)):
		return false
	if not validation_callback.is_null() and not validation_callback.is_valid():
		return false
	if receiver_path == NodePath(""):
		return true
	var receiver: Object = _resolve_receiver()
	if receiver == null:
		return false
	if not receiver.has_method(&"receive_interaction"):
		return true
	return GFInteractions.is_method_call_compatible_for_framework(
		receiver,
		&"receive_interaction",
		[GFInteractionContext.new(), interaction_id]
	)


## 接收一次交互。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @param context: 交互上下文。
## [br]
## @param interaction_id: 交互 ID。
## [br]
## @return: 统一结果报告。
## [br]
## @schema return: 交互结果报告 Dictionary，包含 ok、interaction_id、receiver(JSON-safe 摘要)、reason、message 和 metadata 等字段。
func receive_interaction(context: GFInteractionContext, interaction_id: StringName = &"") -> Dictionary:
	return _receive_interaction_for_framework(
		context,
		interaction_id,
		not _consume_framework_raw_dispatch_token(context, interaction_id)
	)


## 接收一次交互并把未编码的报告交给框架内层发送边界。
## [br]
## @api framework_internal
## [br]
## @since 10.0.0
## [br]
## @param context: 交互上下文。
## [br]
## @param interaction_id: 交互 ID。
## [br]
## @return: 只供 Interaction 框架最外层发布边界完成单次报告编码的原始报告。
## [br]
## @schema return: Raw interaction report Dictionary; callers must encode it exactly once before publication.
func receive_interaction_raw_for_framework(
	context: GFInteractionContext,
	interaction_id: StringName = &""
) -> Dictionary:
	_framework_raw_dispatch_serial += 1
	var dispatch_serial: int = _framework_raw_dispatch_serial
	_framework_raw_dispatch_tokens.append({
		"serial": dispatch_serial,
		"context": context,
		"interaction_id": interaction_id,
	})
	var report: Dictionary = receive_interaction(context, interaction_id)
	_discard_framework_raw_dispatch_token(dispatch_serial)
	return report


# --- 私有/辅助方法 ---

func _consume_framework_raw_dispatch_token(
	context: GFInteractionContext,
	interaction_id: StringName
) -> bool:
	if _framework_raw_dispatch_tokens.is_empty():
		return false
	var top_index: int = _framework_raw_dispatch_tokens.size() - 1
	var token: Dictionary = _framework_raw_dispatch_tokens[top_index]
	if token.get("context") != context:
		return false
	if GFVariantData.to_string_name(token.get("interaction_id", &"")) != interaction_id:
		return false
	_framework_raw_dispatch_tokens.remove_at(top_index)
	return true


func _discard_framework_raw_dispatch_token(dispatch_serial: int) -> void:
	for index: int in range(_framework_raw_dispatch_tokens.size() - 1, -1, -1):
		var token: Dictionary = _framework_raw_dispatch_tokens[index]
		if GFVariantData.to_int(token.get("serial", -1)) != dispatch_serial:
			continue
		_framework_raw_dispatch_tokens.remove_at(index)
		return


func _receive_interaction_for_framework(
	context: GFInteractionContext,
	interaction_id: StringName,
	normalize_output: bool
) -> Dictionary:
	var receiver: Object = _resolve_receiver()
	var has_receiver_path: bool = receiver_path != NodePath("")
	var delegate_method: StringName = (
		&"receive_interaction_raw_for_framework"
		if receiver is GFInteractionReceiver
		else &"receive_interaction"
	)
	var effective_validation_callback: Callable = validation_callback
	if not validation_callback.is_null() and not validation_callback.is_valid():
		effective_validation_callback = Callable(self, "_reject_invalid_validator")
	elif (
		receiver != null
		and receiver.has_method(delegate_method)
		and not GFInteractions.is_method_call_compatible_for_framework(
			receiver,
			delegate_method,
			[context, interaction_id]
		)
	):
		effective_validation_callback = Callable(self, "_reject_invalid_delegate")
	var report: Dictionary = _MESSAGE_RECEIVER_SUPPORT._receive_with_delegate(
		self,
		context,
		"interaction_id",
		interaction_id,
		enabled,
		accepted_interaction_ids,
		rejected_interaction_ids,
		metadata,
		effective_validation_callback,
		Callable(self, "_emit_interaction_validating"),
		Callable(self, "_emit_interaction_received"),
		Callable(self, "_emit_interaction_rejected"),
		"Interaction context is null.",
		"Interaction receiver is disabled.",
		"Interaction id is rejected.",
		"Interaction id is not accepted.",
		has_receiver_path,
		receiver,
		delegate_method,
		[context, interaction_id],
		"Interaction delegate receiver is missing.",
		"Interaction delegate receiver returned an invalid interaction report.",
		&"target",
		normalize_output
	)
	return report


func _reject_invalid_validator(
	_context: GFInteractionContext,
	_report: Dictionary
) -> Dictionary:
	return {
		"ok": false,
		"reason": "invalid_validator",
		"message": "Configured interaction validation callback is no longer valid.",
	}


func _reject_invalid_delegate(
	_context: GFInteractionContext,
	_report: Dictionary
) -> Dictionary:
	return {
		"ok": false,
		"reason": "invalid_receiver",
		"message": "Interaction delegate receiver has an incompatible receive_interaction() signature.",
	}


func _resolve_receiver() -> Object:
	if receiver_path == NodePath(""):
		return null
	var receiver: Node = get_node_or_null(receiver_path)
	if receiver == self:
		return null
	return receiver


func _emit_interaction_validating(context: GFInteractionContext, report: Dictionary) -> void:
	interaction_validating.emit(context, report)


func _emit_interaction_received(context: GFInteractionContext, report: Dictionary) -> void:
	interaction_received.emit(context, report)


func _emit_interaction_rejected(context: GFInteractionContext, report: Dictionary) -> void:
	interaction_rejected.emit(context, report)
