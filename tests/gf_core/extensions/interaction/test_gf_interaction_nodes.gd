## 测试通用交互 Sensor/Receiver 节点。
extends GutTest


# --- 常量 ---

const GF_MESSAGE_DISPATCH_SUPPORT = preload("res://addons/gf/standard/common/gf_message_dispatch_support.gd")
const GF_OBJECT_CANDIDATE_REGISTRY_SCRIPT = preload("res://addons/gf/standard/common/gf_object_candidate_registry.gd")


# --- 辅助类 ---

class RecordingReceiver extends GFInteractionReceiver:
	var received_context: GFInteractionContext = null
	var validate_count: int = 0

	func _init() -> void:
		validation_callback = Callable(self, "_validate_interaction")

	func _validate_interaction(context: GFInteractionContext, _report: Dictionary) -> Dictionary:
		received_context = context
		validate_count += 1
		return {
			"ok": true,
			"metadata": {
				"validated": true,
			},
		}


class BusinessInteractionReceiver extends Node:
	var received_context: GFInteractionContext = null
	var received_id: StringName = &""

	func receive_interaction(context: GFInteractionContext, interaction_id: StringName = &"") -> Dictionary:
		received_context = context
		received_id = interaction_id
		return {
			"ok": true,
			"interaction_id": interaction_id,
			"receiver": self,
			"reason": "handled",
			"message": "",
			"metadata": {
				"business": true,
			},
		}


class SideEffectInteractionReceiver extends Node:
	var received_context: GFInteractionContext = null
	var received_id: StringName = &""

	func receive_interaction(context: GFInteractionContext, interaction_id: StringName = &"") -> void:
		received_context = context
		received_id = interaction_id


class PlainInteractionTarget extends Node:
	pass


class RecordingDispatchHost extends RefCounted:
	var received_receiver: Object = null
	var received_payload: Variant = null
	var received_id: StringName = &""

	func send_to(receiver: Object, payload_override: Variant = null, id_override: StringName = &"") -> Dictionary:
		received_receiver = receiver
		received_payload = payload_override
		received_id = id_override
		return {
			"ok": true,
			"receiver": receiver,
			"interaction_id": id_override,
			"metadata": {},
		}


class RecordingDispatchNode extends Node:
	var received_receiver: Object = null
	var received_payload: Variant = null
	var received_id: StringName = &""

	func send_to(receiver: Object, payload_override: Variant = null, id_override: StringName = &"") -> Dictionary:
		received_receiver = receiver
		received_payload = payload_override
		received_id = id_override
		return {
			"ok": true,
			"receiver": receiver,
			"interaction_id": id_override,
			"metadata": {},
		}


class InvalidDispatchNode extends Node:
	var called: bool = false

	func send_to(_receiver: Object) -> Dictionary:
		called = true
		return {
			"ok": false,
			"metadata": {},
		}


class ExcessRequiredArgsDispatchNode extends Node:
	var called: bool = false

	func send_to(
		_receiver: Object,
		_payload_override: Variant,
		_id_override: StringName,
		_required_argument: Variant
	) -> Dictionary:
		called = true
		return {
			"ok": false,
			"metadata": {},
		}


class UnsafeReportDispatchNode extends Node:
	func send_to(receiver: Object, _payload_override: Variant = null, id_override: StringName = &"") -> Dictionary:
		return {
			"ok": true,
			"receiver": receiver,
			"interaction_id": id_override,
			"leaked_object": receiver,
			"nested_values": [receiver],
			"metadata": {
				"object": receiver,
			},
		}


class EmptyReportDispatchNode extends Node:
	func send_to(_receiver: Object, _payload_override: Variant = null, _id_override: StringName = &"") -> Dictionary:
		return {}


class ConfigurableInvalidReportDispatchNode extends Node:
	var result: Variant = {}

	func send_to(
		_receiver: Object,
		_payload_override: Variant = null,
		_id_override: StringName = &""
	) -> Variant:
		return result


class WrongTypedDispatchNode extends Node:
	var called: bool = false

	func send_to(
		_receiver: int,
		_payload_override: Variant = null,
		_id_override: StringName = &""
	) -> Dictionary:
		called = true
		return {}


class WrongTypedInteractionReceiver extends Node:
	var called: bool = false

	func receive_interaction(
		_context: int,
		_interaction_id: StringName = &""
	) -> Dictionary:
		called = true
		return {}


class ZeroArgumentCandidateProvider extends RefCounted:
	var called: bool = false

	func get_candidate_objects() -> Array:
		called = true
		return []


class ArrayCandidateProvider extends RefCounted:
	var candidates: Array = []

	func get_candidate_objects(_options: Dictionary) -> Array:
		return candidates


class FreeingInteractionReceiver extends GFInteractionReceiver:
	var receiver_to_free: Node = null
	var receive_count: int = 0

	func receive_interaction(
		context: GFInteractionContext,
		interaction_id: StringName = &""
	) -> Dictionary:
		receive_count += 1
		if receiver_to_free != null and is_instance_valid(receiver_to_free):
			receiver_to_free.free()
		receiver_to_free = null
		return super.receive_interaction(context, interaction_id)


class ValidationCallbackOwner extends Node:
	func validate_interaction(
		_context: GFInteractionContext,
		_report: Dictionary
	) -> bool:
		return true


class ForgedMarkerInteractionReceiver extends GFInteractionReceiver:
	func receive_interaction_raw_for_framework(
		_context: GFInteractionContext,
		interaction_id: StringName = &""
	) -> Dictionary:
		var circular: Dictionary = {}
		circular["self"] = circular
		return {
			"ok": true,
			"interaction_id": interaction_id,
			"receiver": {
				"__gf_report_value__": {
					"version": 1,
					"type": "Object",
					"redacted": true,
					"object_instance_id": get_instance_id(),
					"leaked_object": self,
					"path": "res://private/receiver.tres",
				},
			},
			"metadata": {
				"forged": {
					"__gf_report_value__": {
						"version": 1,
						"type": "Object",
						"redacted": true,
						"leaked_object": self,
						"circular": circular,
						"path": "res://private/metadata.tres",
					},
				},
				"object": self,
				"circular": circular,
				"path": "res://private/report.json",
			},
		}


class PublicOverrideInteractionReceiver extends GFInteractionReceiver:
	var receive_count: int = 0
	var received_context: GFInteractionContext = null
	var received_id: StringName = &""

	func receive_interaction(
		context: GFInteractionContext,
		interaction_id: StringName = &""
	) -> Dictionary:
		receive_count += 1
		received_context = context
		received_id = interaction_id
		return {
			"ok": true,
			"interaction_id": interaction_id,
			"receiver": self,
			"metadata": {
				"object": self,
			},
		}


class DerivedPublicOverrideInteractionReceiver extends PublicOverrideInteractionReceiver:
	pass


class SuperCallingPublicOverrideInteractionReceiver extends GFInteractionReceiver:
	var receive_count: int = 0

	func receive_interaction(
		context: GFInteractionContext,
		interaction_id: StringName = &""
	) -> Dictionary:
		receive_count += 1
		var report: Dictionary = super.receive_interaction(context, interaction_id)
		report["reason"] = "extended"
		return report


class ReentrantInteractionObserver extends Node:
	var receiver: SuperCallingPublicOverrideInteractionReceiver = null
	var reentrant_report: Dictionary = {}
	var did_reenter: bool = false

	func on_interaction_received(
		_context: GFInteractionContext,
		_report: Dictionary
	) -> void:
		if did_reenter or receiver == null:
			return
		did_reenter = true
		reentrant_report = receiver.receive_interaction(
			GFInteractionContext.new(null, receiver),
			&"reentrant"
		)


class NestedRawTokenInteractionReceiver extends GFInteractionReceiver:
	var outer_context: GFInteractionContext = null
	var nested_mismatch_report: Dictionary = {}

	func receive_interaction(
		context: GFInteractionContext,
		interaction_id: StringName = &""
	) -> Dictionary:
		if interaction_id == &"inner":
			nested_mismatch_report = super.receive_interaction(
				outer_context,
				&"outer"
			)
			return nested_mismatch_report
		outer_context = context
		var _nested_report: Dictionary = receive_interaction_raw_for_framework(
			GFInteractionContext.new(null, self),
			&"inner"
		)
		return super.receive_interaction(context, interaction_id)


class InteractionCollisionArea2D extends Area2D:
	func receive_interaction(
		_context: GFInteractionContext,
		_interaction_id: StringName = &""
	) -> Dictionary:
		return {}


class InteractionCollisionArea3D extends Area3D:
	func receive_interaction(
		_context: GFInteractionContext,
		_interaction_id: StringName = &""
	) -> Dictionary:
		return {}


# --- 测试方法 ---

func test_sensor_send_to_receiver_builds_context_and_report() -> void:
	var sensor: GFInteractionSensor = GFInteractionSensor.new()
	var receiver: RecordingReceiver = RecordingReceiver.new()
	add_child_autofree(sensor)
	add_child_autofree(receiver)
	sensor.interaction_id = &"use"
	sensor.group_name = &"nearby"
	sensor.payload = { "amount": 2 }

	var report: Dictionary = sensor.send_to(receiver)
	var received_payload: Dictionary = GFVariantData.as_dictionary(receiver.received_context.payload)
	var report_metadata: Dictionary = GFVariantData.get_option_dictionary(report, "metadata")

	assert_true(GFVariantData.get_option_bool(report, "ok"), "有效接收器应接受交互。")
	assert_same(receiver.received_context.sender, sensor, "默认 sender 应为 Sensor 自身。")
	assert_same(receiver.received_context.target, receiver, "上下文 target 应指向接收器。")
	assert_eq(GFVariantData.get_option_int(received_payload, "amount"), 2, "payload 应写入上下文。")
	assert_eq(receiver.received_context.group_name, &"nearby", "group_name 应写入上下文。")
	assert_true(GFVariantData.get_option_bool(report_metadata, "validated"), "接收器校验结果应合并 metadata。")


func test_sensor_report_uses_receiver_summary_instead_of_live_object() -> void:
	var sensor: GFInteractionSensor = GFInteractionSensor.new()
	var receiver: RecordingReceiver = RecordingReceiver.new()
	add_child_autofree(sensor)
	add_child_autofree(receiver)

	var report: Dictionary = sensor.send_to(receiver)
	var receiver_report: Variant = GFVariantData.get_option_value(report, "receiver")
	var receiver_summary: Dictionary = GFVariantData.get_option_dictionary(report, "receiver")

	assert_false(receiver_report is Object, "交互报告不应携带 live receiver Object。")
	assert_eq(_receiver_instance_id(report), receiver.get_instance_id(), "receiver 摘要应保留实例 ID 便于诊断关联。")
	assert_true(receiver_summary.has("__gf_report_value__"), "receiver 应使用 GFReportValueCodec marker。")
	assert_eq(
		GFVariantData.get_option_string(
			GFVariantData.get_option_dictionary(receiver_summary, "__gf_report_value__"),
			"type"
		),
		"Object",
		"receiver marker 应只编码一次，不能再次折叠成 Dictionary marker。"
	)


func test_receiver_report_metadata_is_encoded_once_at_public_boundary() -> void:
	var receiver: GFInteractionReceiver = GFInteractionReceiver.new()
	add_child_autofree(receiver)
	var circular: Dictionary = {}
	circular["self"] = circular
	receiver.metadata = {
		"object": receiver,
		"circular": circular,
		"tags": PackedStringArray(["alpha", "beta"]),
		"path": "res://private/receiver.json",
	}

	var report: Dictionary = receiver.receive_interaction(
		GFInteractionContext.new(),
		&"inspect"
	)
	var report_metadata: Dictionary = GFVariantData.get_option_dictionary(
		report,
		"metadata"
	)

	assert_eq(_report_marker_type(report_metadata.get("object")), "Object")
	assert_eq(
		_report_marker_type(
			GFVariantData.get_option_value(
				GFVariantData.get_option_dictionary(report_metadata, "circular"),
				"self"
			)
		),
		"CircularReference"
	)
	assert_eq(_report_marker_type(report_metadata.get("tags")), "PackedArray")
	assert_eq(
		GFVariantData.get_option_string(report_metadata, "path"),
		"receiver.json"
	)
	assert_false(_contains_live_object(report), "Receiver 公共报告不得残留 live Object。")
	assert_false(JSON.stringify(report).is_empty(), "Receiver 公共报告必须可直接 JSON.stringify。")


func test_pointer_finalizes_framework_receiver_report_exactly_once() -> void:
	var root: Node = Node.new()
	var pointer: GFPointerInteraction3D = GFPointerInteraction3D.new()
	var receiver: GFInteractionReceiver = GFInteractionReceiver.new()
	add_child_autofree(root)
	root.add_child(pointer)
	root.add_child(receiver)
	receiver.name = "Receiver"
	pointer.receiver_path = NodePath("../Receiver")
	receiver.metadata = {
		"object": receiver,
		"name": &"receiver_name",
		"tags": PackedStringArray(["alpha", "beta"]),
	}

	var report: Dictionary = pointer.send_pointer_interaction(&"clicked", {}, &"inspect")
	var report_metadata: Dictionary = GFVariantData.get_option_dictionary(report, "metadata")

	assert_eq(_report_marker_type(report_metadata.get("object")), "Object")
	assert_eq(_report_marker_type(report_metadata.get("name")), "StringName")
	assert_eq(_report_marker_type(report_metadata.get("tags")), "PackedArray")
	assert_false(_contains_live_object(report), "Pointer 最终报告不得残留 live Object。")
	assert_false(JSON.stringify(report).is_empty(), "Pointer 最终报告必须可直接 JSON.stringify。")


func test_pointer_rejects_receiver_with_incompatible_argument_types() -> void:
	var root: Node = Node.new()
	var pointer: GFPointerInteraction3D = GFPointerInteraction3D.new()
	var receiver: WrongTypedInteractionReceiver = WrongTypedInteractionReceiver.new()
	add_child_autofree(root)
	root.add_child(pointer)
	root.add_child(receiver)
	receiver.name = "Receiver"
	pointer.receiver_path = NodePath("../Receiver")

	var report: Dictionary = pointer.send_pointer_interaction(&"clicked", {}, &"inspect")

	assert_false(GFVariantData.get_option_bool(report, "ok"), "Pointer 不得调用参数类型不兼容的 receiver。")
	assert_eq(GFVariantData.get_option_string(report, "reason"), "invalid_receiver")
	assert_false(receiver.called, "Pointer 应在调用前拒绝不兼容的 duck-typed receiver。")


func test_nested_framework_receiver_finalizes_report_exactly_once() -> void:
	var root: Node = Node.new()
	var sensor: GFInteractionSensor = GFInteractionSensor.new()
	var outer_receiver: GFInteractionReceiver = GFInteractionReceiver.new()
	var inner_receiver: GFInteractionReceiver = GFInteractionReceiver.new()
	add_child_autofree(root)
	root.add_child(sensor)
	root.add_child(outer_receiver)
	root.add_child(inner_receiver)
	inner_receiver.name = "InnerReceiver"
	outer_receiver.receiver_path = NodePath("../InnerReceiver")
	inner_receiver.metadata = {
		"object": inner_receiver,
		"tags": PackedStringArray(["nested"]),
	}

	var report: Dictionary = sensor.send_to(outer_receiver, null, &"inspect")
	var report_metadata: Dictionary = GFVariantData.get_option_dictionary(report, "metadata")

	assert_eq(_report_marker_type(report_metadata.get("object")), "Object")
	assert_eq(_report_marker_type(report_metadata.get("tags")), "PackedArray")
	assert_false(_contains_live_object(report), "嵌套 Receiver 最终报告不得残留 live Object。")
	assert_false(JSON.stringify(report).is_empty(), "嵌套 Receiver 最终报告必须可直接 JSON.stringify。")


func test_sensor_does_not_trust_forged_report_marker_shape() -> void:
	var sensor: GFInteractionSensor = GFInteractionSensor.new()
	var receiver: ForgedMarkerInteractionReceiver = ForgedMarkerInteractionReceiver.new()
	add_child_autofree(sensor)
	add_child_autofree(receiver)

	var report: Dictionary = sensor.send_to(receiver, null, &"inspect")
	var receiver_marker: Dictionary = _report_marker(
		GFVariantData.get_option_value(report, "receiver")
	)
	var report_metadata: Dictionary = GFVariantData.get_option_dictionary(
		report,
		"metadata"
	)
	var forged_marker: Dictionary = _report_marker(
		GFVariantData.get_option_value(report_metadata, "forged")
	)

	assert_eq(GFVariantData.get_option_string(receiver_marker, "type"), "Object")
	assert_eq(
		GFVariantData.get_option_int(receiver_marker, "instance_id"),
		receiver.get_instance_id(),
		"Sensor 应以实际接收对象重建 receiver 摘要，不能信任用户 marker。"
	)
	assert_eq(
		GFVariantData.get_option_string(forged_marker, "type"),
		"Dictionary",
		"用户伪造的 report marker 必须按普通 Dictionary 保真编码。"
	)
	assert_eq(_report_marker_type(report_metadata.get("object")), "Object")
	assert_eq(
		_report_marker_type(
			GFVariantData.get_option_value(
				GFVariantData.get_option_dictionary(report_metadata, "circular"),
				"self"
			)
		),
		"CircularReference"
	)
	assert_eq(GFVariantData.get_option_string(report_metadata, "path"), "report.json")
	assert_false(_contains_live_object(report), "伪 marker 不得把 live Object 带过报告边界。")
	assert_false(JSON.stringify(report).is_empty(), "伪 marker 报告仍必须可直接 JSON.stringify。")


func test_sensor_preserves_public_receive_override_across_script_chain() -> void:
	var sensor: GFInteractionSensor = GFInteractionSensor.new()
	var receiver: DerivedPublicOverrideInteractionReceiver = DerivedPublicOverrideInteractionReceiver.new()
	add_child_autofree(sensor)
	add_child_autofree(receiver)

	var report: Dictionary = sensor.send_to(receiver, { "value": 3 }, &"inspect")
	var report_metadata: Dictionary = GFVariantData.get_option_dictionary(
		report,
		"metadata"
	)

	assert_eq(receiver.receive_count, 1, "Sensor 必须保留 GFInteractionReceiver 子类的公开 receive_interaction override。")
	assert_not_null(receiver.received_context, "公开 override 应收到 Sensor 构建的交互上下文。")
	if receiver.received_context != null:
		assert_same(receiver.received_context.target, receiver, "公开 override 的上下文 target 应指向实际接收器。")
	assert_eq(receiver.received_id, &"inspect", "公开 override 应收到有效交互 ID。")
	assert_eq(_report_marker_type(GFVariantData.get_option_value(report, "receiver")), "Object")
	assert_eq(_report_marker_type(GFVariantData.get_option_value(report_metadata, "object")), "Object")
	assert_false(_contains_live_object(report), "公开 override 返回值仍必须由 Sensor 转为 JSON-safe 报告。")
	assert_false(JSON.stringify(report).is_empty(), "公开 override 报告必须可直接 JSON.stringify。")


func test_sensor_encodes_super_calling_public_override_exactly_once() -> void:
	var sensor: GFInteractionSensor = GFInteractionSensor.new()
	var receiver: SuperCallingPublicOverrideInteractionReceiver = (
		SuperCallingPublicOverrideInteractionReceiver.new()
	)
	add_child_autofree(sensor)
	add_child_autofree(receiver)
	receiver.metadata = {
		"object": receiver,
	}

	var report: Dictionary = sensor.send_to(receiver, null, &"inspect")
	var report_metadata: Dictionary = GFVariantData.get_option_dictionary(
		report,
		"metadata"
	)

	assert_eq(receiver.receive_count, 1, "Sensor 应且仅应调用一次公开 receive_interaction override。")
	assert_eq(GFVariantData.get_option_string(report, "reason"), "extended")
	assert_eq(
		_report_marker_type(GFVariantData.get_option_value(report_metadata, "object")),
		"Object",
		"override 调用 super 时，base raw 报告必须只在 Sensor 边界编码一次。"
	)
	assert_false(_contains_live_object(report), "super override 的最终报告不得泄露 live Object。")
	assert_false(JSON.stringify(report).is_empty(), "super override 的最终报告必须可直接 JSON.stringify。")


func test_super_override_raw_token_does_not_leak_into_signal_reentry() -> void:
	var sensor: GFInteractionSensor = GFInteractionSensor.new()
	var receiver: SuperCallingPublicOverrideInteractionReceiver = (
		SuperCallingPublicOverrideInteractionReceiver.new()
	)
	var observer: ReentrantInteractionObserver = ReentrantInteractionObserver.new()
	add_child_autofree(sensor)
	add_child_autofree(receiver)
	add_child_autofree(observer)
	receiver.metadata = {
		"object": receiver,
	}
	observer.receiver = receiver
	var connect_error: Error = receiver.interaction_received.connect(
		Callable(observer, "on_interaction_received")
	) as Error
	assert_eq(connect_error, OK, "测试监听器应成功连接。")

	var outer_report: Dictionary = sensor.send_to(receiver, null, &"inspect")
	var reentrant_metadata: Dictionary = GFVariantData.get_option_dictionary(
		observer.reentrant_report,
		"metadata"
	)

	assert_true(observer.did_reenter, "Receiver 公开信号应触发一次同步重入测试。")
	assert_eq(receiver.receive_count, 2, "外层 override 与重入公开调用应各执行一次。")
	assert_eq(
		_report_marker_type(
			GFVariantData.get_option_value(reentrant_metadata, "object")
		),
		"Object",
		"同步重入的独立公开调用必须保持自身的 JSON-safe 编码边界。"
	)
	assert_false(
		_contains_live_object(observer.reentrant_report),
		"外层 raw token 不得让信号监听器拿到未编码的公开调用报告。"
	)
	assert_false(_contains_live_object(outer_report), "外层 Sensor 报告仍必须保持单次编码。")


func test_nested_raw_dispatch_cannot_consume_outer_token() -> void:
	var sensor: GFInteractionSensor = GFInteractionSensor.new()
	var receiver: NestedRawTokenInteractionReceiver = (
		NestedRawTokenInteractionReceiver.new()
	)
	add_child_autofree(sensor)
	add_child_autofree(receiver)
	receiver.metadata = {
		"object": receiver,
	}

	var report: Dictionary = sensor.send_to(receiver, null, &"outer")
	var report_metadata: Dictionary = GFVariantData.get_option_dictionary(
		report,
		"metadata"
	)

	assert_false(
		_contains_live_object(receiver.nested_mismatch_report),
		"最内层参数不匹配的 super 调用不得越栈消费外层 raw token。"
	)
	assert_eq(
		_report_marker_type(GFVariantData.get_option_value(report_metadata, "object")),
		"Object",
		"嵌套 raw 调用返回后，外层 token 仍应供对应 super 单次消费。"
	)
	assert_false(_contains_live_object(report), "嵌套 raw 调用后的外层报告必须保持 JSON-safe。")


func test_receiver_filters_interaction_ids() -> void:
	var receiver: GFInteractionReceiver = GFInteractionReceiver.new()
	add_child_autofree(receiver)
	receiver.accepted_interaction_ids = [&"open"]

	var rejected: Dictionary = receiver.receive_interaction(GFInteractionContext.new(), &"use")
	var accepted: Dictionary = receiver.receive_interaction(GFInteractionContext.new(), &"open")

	assert_false(GFVariantData.get_option_bool(rejected, "ok"), "不在 accepted_interaction_ids 内的交互应被拒绝。")
	assert_eq(GFVariantData.get_option_string(rejected, "reason"), "unaccepted_id")
	assert_true(GFVariantData.get_option_bool(accepted, "ok"), "允许的交互 ID 应通过基础过滤。")


func test_receiver_fails_closed_when_configured_validator_owner_is_freed() -> void:
	var root: Node = Node.new()
	var receiver: GFInteractionReceiver = GFInteractionReceiver.new()
	var validation_owner: ValidationCallbackOwner = ValidationCallbackOwner.new()
	add_child_autofree(root)
	root.add_child(receiver)
	root.add_child(validation_owner)
	receiver.validation_callback = Callable(validation_owner, "validate_interaction")
	validation_owner.free()
	watch_signals(receiver)

	var report: Dictionary = receiver.receive_interaction(
		GFInteractionContext.new(null, receiver),
		&"inspect"
	)

	assert_false(receiver.can_receive_interaction(&"inspect"), "失效校验器存在时预检也必须失败关闭。")
	assert_false(GFVariantData.get_option_bool(report, "ok"), "已配置但失效的校验器不得静默放行交互。")
	assert_eq(GFVariantData.get_option_string(report, "reason"), "invalid_validator")
	assert_signal_emitted(receiver, "interaction_rejected", "失效校验器应产生可观测拒绝结果。")


func test_receiver_path_forwards_interaction_to_business_receiver() -> void:
	var root: Node = Node.new()
	var bridge: GFInteractionReceiver = GFInteractionReceiver.new()
	var business_receiver: BusinessInteractionReceiver = BusinessInteractionReceiver.new()
	add_child_autofree(root)
	root.add_child(bridge)
	root.add_child(business_receiver)
	bridge.name = "InteractionAreaBridge"
	business_receiver.name = "BusinessReceiver"
	bridge.receiver_path = NodePath("../BusinessReceiver")
	bridge.accepted_interaction_ids = [&"use"]
	watch_signals(bridge)

	var context: GFInteractionContext = GFInteractionContext.new(null, bridge, { "item": "door" })
	var report: Dictionary = bridge.receive_interaction(context, &"use")
	var report_metadata: Dictionary = GFVariantData.get_option_dictionary(report, "metadata")

	assert_true(GFVariantData.get_option_bool(report, "ok"), "通过本地过滤的交互应转发给业务接收器。")
	assert_same(business_receiver.received_context, context, "业务接收器应收到同一个交互上下文。")
	assert_same(context.target, business_receiver, "转发时上下文 target 应更新为业务接收器。")
	assert_eq(business_receiver.received_id, &"use", "交互 ID 应透传给业务接收器。")
	assert_eq(_receiver_instance_id(report), business_receiver.get_instance_id(), "最终报告摘要应来自业务接收器。")
	assert_true(GFVariantData.get_option_bool(report_metadata, "business"), "业务接收器返回的报告应成为最终报告。")
	assert_signal_emitted(bridge, "interaction_received", "业务接收成功后桥接节点应发出接收信号。")


func test_receiver_path_rejects_delegate_with_incompatible_argument_types() -> void:
	var root: Node = Node.new()
	var bridge: GFInteractionReceiver = GFInteractionReceiver.new()
	var business_receiver: WrongTypedInteractionReceiver = WrongTypedInteractionReceiver.new()
	add_child_autofree(root)
	root.add_child(bridge)
	root.add_child(business_receiver)
	business_receiver.name = "BusinessReceiver"
	bridge.receiver_path = NodePath("../BusinessReceiver")
	watch_signals(bridge)

	var report: Dictionary = bridge.receive_interaction(
		GFInteractionContext.new(null, bridge),
		&"use"
	)

	assert_false(bridge.can_receive_interaction(&"use"), "签名不兼容的 delegate 不应被报告为可接收。")
	assert_false(GFVariantData.get_option_bool(report, "ok"), "签名不兼容的 delegate 必须失败关闭。")
	assert_eq(GFVariantData.get_option_string(report, "reason"), "invalid_receiver")
	assert_false(business_receiver.called, "桥接 Receiver 不得调用参数类型不兼容的 delegate。")
	assert_signal_emitted(bridge, "interaction_rejected")


func test_receiver_path_accepts_side_effect_business_receiver() -> void:
	var root: Node = Node.new()
	var bridge: GFInteractionReceiver = GFInteractionReceiver.new()
	var business_receiver: SideEffectInteractionReceiver = SideEffectInteractionReceiver.new()
	add_child_autofree(root)
	root.add_child(bridge)
	root.add_child(business_receiver)
	business_receiver.name = "BusinessReceiver"
	bridge.receiver_path = NodePath("../BusinessReceiver")
	bridge.accepted_interaction_ids = [&"use"]
	watch_signals(bridge)

	var context: GFInteractionContext = GFInteractionContext.new(null, bridge, { "item": "door" })
	var report: Dictionary = bridge.receive_interaction(context, &"use")

	assert_true(GFVariantData.get_option_bool(report, "ok"), "副作用式业务接收器不返回报告时仍应沿用桥接接收报告。")
	assert_same(business_receiver.received_context, context, "业务接收器应收到同一个交互上下文。")
	assert_same(context.target, business_receiver, "转发时上下文 target 应更新为业务接收器。")
	assert_eq(business_receiver.received_id, &"use", "交互 ID 应透传给业务接收器。")
	assert_eq(_receiver_instance_id(report), business_receiver.get_instance_id(), "默认接收报告摘要应指向业务接收器。")
	assert_signal_emitted(bridge, "interaction_received", "业务接收器处理后桥接节点应发出接收信号。")


func test_receiver_path_can_only_retarget_context() -> void:
	var root: Node = Node.new()
	var bridge: GFInteractionReceiver = GFInteractionReceiver.new()
	var business_target: PlainInteractionTarget = PlainInteractionTarget.new()
	add_child_autofree(root)
	root.add_child(bridge)
	root.add_child(business_target)
	business_target.name = "BusinessTarget"
	bridge.receiver_path = NodePath("../BusinessTarget")
	bridge.accepted_interaction_ids = [&"use"]
	watch_signals(bridge)

	var context: GFInteractionContext = GFInteractionContext.new(null, bridge, { "item": "door" })
	var report: Dictionary = bridge.receive_interaction(context, &"use")

	assert_true(bridge.can_receive_interaction(&"use"), "receiver_path 指向普通业务节点时仍应允许 Receiver 接收交互。")
	assert_true(GFVariantData.get_option_bool(report, "ok"), "普通业务节点可只作为交互 target，不必实现 receive_interaction()。")
	assert_same(context.target, business_target, "转发时上下文 target 应更新为业务 target。")
	assert_eq(_receiver_instance_id(report), business_target.get_instance_id(), "默认接收报告摘要应指向业务 target。")
	assert_signal_emitted(bridge, "interaction_received", "Receiver retarget 后仍应发出接收信号。")


func test_receiver_path_does_not_forward_rejected_interaction() -> void:
	var root: Node = Node.new()
	var bridge: GFInteractionReceiver = GFInteractionReceiver.new()
	var business_receiver: BusinessInteractionReceiver = BusinessInteractionReceiver.new()
	add_child_autofree(root)
	root.add_child(bridge)
	root.add_child(business_receiver)
	business_receiver.name = "BusinessReceiver"
	bridge.receiver_path = NodePath("../BusinessReceiver")
	bridge.accepted_interaction_ids = [&"open"]

	var report: Dictionary = bridge.receive_interaction(GFInteractionContext.new(null, bridge), &"use")

	assert_false(GFVariantData.get_option_bool(report, "ok"), "未通过本地 ID 过滤的交互不应转发。")
	assert_eq(GFVariantData.get_option_string(report, "reason"), "unaccepted_id")
	assert_null(business_receiver.received_context, "被本地拒绝时业务接收器不应收到上下文。")


func test_sensor_rejects_invalid_receiver() -> void:
	var sensor: GFInteractionSensor = GFInteractionSensor.new()
	var invalid_receiver: Node = Node.new()
	add_child_autofree(sensor)
	add_child_autofree(invalid_receiver)

	var report: Dictionary = sensor.send_to(invalid_receiver)

	assert_false(GFVariantData.get_option_bool(report, "ok"), "缺少 receive_interaction() 的对象应被拒绝。")
	assert_eq(GFVariantData.get_option_string(report, "reason"), "invalid_receiver")


func test_sensor_rejects_receiver_with_incompatible_argument_types() -> void:
	var sensor: GFInteractionSensor = GFInteractionSensor.new()
	var receiver: WrongTypedInteractionReceiver = WrongTypedInteractionReceiver.new()
	add_child_autofree(sensor)
	add_child_autofree(receiver)

	var report: Dictionary = sensor.send_to(receiver, null, &"inspect")

	assert_false(GFVariantData.get_option_bool(report, "ok"), "参数类型不兼容的 receive_interaction() 不得被调用。")
	assert_eq(GFVariantData.get_option_string(report, "reason"), "invalid_receiver")
	assert_false(receiver.called, "框架应在调用前拒绝不兼容的 duck-typed receiver。")


func test_sensor_broadcast_to_group_sends_to_receivers() -> void:
	var sensor: GFInteractionSensor = GFInteractionSensor.new()
	var receiver_a: RecordingReceiver = RecordingReceiver.new()
	var receiver_b: RecordingReceiver = RecordingReceiver.new()
	add_child_autofree(sensor)
	add_child_autofree(receiver_a)
	add_child_autofree(receiver_b)
	sensor.group_name = &"targets"
	receiver_a.add_to_group("targets")
	receiver_b.add_to_group("targets")

	var reports: Array[Dictionary] = sensor.broadcast_to_group()

	assert_eq(reports.size(), 2, "广播应发送给分组中的所有接收器。")
	assert_eq(receiver_a.validate_count + receiver_b.validate_count, 2, "每个接收器都应收到一次交互。")


func test_sensor_send_to_best_candidate_uses_candidate_provider_priority() -> void:
	var registry: RefCounted = GF_OBJECT_CANDIDATE_REGISTRY_SCRIPT.new()
	var sensor: GFInteractionSensor = GFInteractionSensor.new()
	var low_receiver: RecordingReceiver = RecordingReceiver.new()
	var high_receiver: RecordingReceiver = RecordingReceiver.new()
	add_child_autofree(sensor)
	add_child_autofree(low_receiver)
	add_child_autofree(high_receiver)

	assert_true(GFVariantData.to_bool(registry.call("register_candidate", low_receiver, {
		"group": &"usable",
		"priority": 1,
	})))
	assert_true(GFVariantData.to_bool(registry.call("register_candidate", high_receiver, {
		"group": &"usable",
		"priority": 10,
	})))

	var report: Dictionary = sensor.send_to_best_candidate(registry, { "group": &"usable" })

	assert_true(GFVariantData.get_option_bool(report, "ok"), "最佳候选应收到交互。")
	assert_eq(high_receiver.validate_count, 1, "高优先级候选应被选中。")
	assert_eq(low_receiver.validate_count, 0, "低优先级候选不应被 send_to_best_candidate 调用。")


func test_sensor_rejects_candidate_provider_with_incompatible_signature() -> void:
	var sensor: GFInteractionSensor = GFInteractionSensor.new()
	var provider: ZeroArgumentCandidateProvider = ZeroArgumentCandidateProvider.new()
	add_child_autofree(sensor)

	var report: Dictionary = sensor.send_to_best_candidate(provider)

	assert_false(GFVariantData.get_option_bool(report, "ok"), "不兼容的候选 provider 应安全返回 missing_receiver。")
	assert_eq(GFVariantData.get_option_string(report, "reason"), "missing_receiver")
	assert_false(provider.called, "框架不得以错误参数数量调用候选 provider。")


func test_sensor_broadcast_to_candidates_uses_candidate_provider() -> void:
	var registry: RefCounted = GF_OBJECT_CANDIDATE_REGISTRY_SCRIPT.new()
	var sensor: GFInteractionSensor = GFInteractionSensor.new()
	var receiver_a: RecordingReceiver = RecordingReceiver.new()
	var receiver_b: RecordingReceiver = RecordingReceiver.new()
	add_child_autofree(sensor)
	add_child_autofree(receiver_a)
	add_child_autofree(receiver_b)

	assert_true(GFVariantData.to_bool(registry.call("register_candidate", receiver_a, { "group": &"usable" })))
	assert_true(GFVariantData.to_bool(registry.call("register_candidate", receiver_b, { "group": &"usable" })))

	var reports: Array[Dictionary] = sensor.broadcast_to_candidates(registry, { "group": &"usable" })

	assert_eq(reports.size(), 2, "候选 provider 广播应发送给全部匹配候选。")
	assert_eq(receiver_a.validate_count + receiver_b.validate_count, 2, "每个候选接收器都应收到一次交互。")


func test_sensor_candidate_broadcast_revalidates_receiver_before_dispatch() -> void:
	var root: Node = Node.new()
	var sensor: GFInteractionSensor = GFInteractionSensor.new()
	var first_receiver: FreeingInteractionReceiver = FreeingInteractionReceiver.new()
	var second_receiver: RecordingReceiver = RecordingReceiver.new()
	var provider: ArrayCandidateProvider = ArrayCandidateProvider.new()
	add_child_autofree(root)
	root.add_child(sensor)
	root.add_child(first_receiver)
	root.add_child(second_receiver)
	first_receiver.receiver_to_free = second_receiver
	provider.candidates = [first_receiver, second_receiver]

	var reports: Array[Dictionary] = sensor.broadcast_to_candidates(provider)

	assert_eq(first_receiver.receive_count, 1, "首个候选应正常完成一次分发。")
	assert_eq(reports.size(), 1, "在使用前已经失效的后续候选应被安全跳过。")
	if not reports.is_empty():
		assert_true(GFVariantData.get_option_bool(reports[0], "ok"), "有效候选的报告必须保留。")


func test_sensor_candidate_broadcast_revalidates_dispatch_host_before_each_call() -> void:
	var root: Node = Node.new()
	var sensor: GFInteractionSensor = GFInteractionSensor.new()
	var sender: RecordingDispatchNode = RecordingDispatchNode.new()
	var receiver_a: RecordingReceiver = RecordingReceiver.new()
	var receiver_b: RecordingReceiver = RecordingReceiver.new()
	var provider: ArrayCandidateProvider = ArrayCandidateProvider.new()
	var sender_ref: WeakRef = weakref(sender)
	add_child_autofree(root)
	root.add_child(sensor)
	root.add_child(sender)
	root.add_child(receiver_a)
	root.add_child(receiver_b)
	sender.name = "Sender"
	sensor.sender_path = NodePath("../Sender")
	provider.candidates = [receiver_a, receiver_b]
	var _interaction_sent_connected: Error = sensor.interaction_sent.connect(
		func(_context: GFInteractionContext, _receiver: Object, _report: Dictionary) -> void:
			var sender_value: Variant = sender_ref.get_ref()
			if sender_value != null:
				var live_sender: Node = sender_value
				live_sender.free()
	) as Error

	var reports: Array[Dictionary] = sensor.broadcast_to_candidates(provider)

	assert_eq(reports.size(), 2, "dispatch host 失效后，剩余候选应安全回退到 Sensor 标准发送。")
	assert_eq(receiver_a.validate_count, 0, "首个候选由业务 sender 接管时不应隐式调用 Receiver。")
	assert_eq(receiver_b.validate_count, 1, "失效 sender 后的候选应由 Sensor 完成分发。")


func test_sensor_candidate_broadcast_deduplicates_receiver_identity() -> void:
	var sensor: GFInteractionSensor = GFInteractionSensor.new()
	var receiver: RecordingReceiver = RecordingReceiver.new()
	var provider: ArrayCandidateProvider = ArrayCandidateProvider.new()
	add_child_autofree(sensor)
	add_child_autofree(receiver)
	provider.candidates = [receiver, receiver, receiver]

	var reports: Array[Dictionary] = sensor.broadcast_to_candidates(provider)

	assert_eq(reports.size(), 1, "同一 receiver 实例在单次候选广播中只能分发一次。")
	assert_eq(receiver.validate_count, 1, "候选去重必须发生在分发之前。")


func test_sensor_broadcast_to_candidates_max_count_counts_accepted_receivers() -> void:
	var registry: RefCounted = GF_OBJECT_CANDIDATE_REGISTRY_SCRIPT.new()
	var sensor: GFInteractionSensor = GFInteractionSensor.new()
	var rejected_receiver: GFInteractionReceiver = GFInteractionReceiver.new()
	var accepted_receiver: RecordingReceiver = RecordingReceiver.new()
	add_child_autofree(sensor)
	add_child_autofree(rejected_receiver)
	add_child_autofree(accepted_receiver)
	rejected_receiver.enabled = false

	assert_true(GFVariantData.to_bool(registry.call("register_candidate", rejected_receiver, {
		"group": &"usable",
		"priority": 10,
	})))
	assert_true(GFVariantData.to_bool(registry.call("register_candidate", accepted_receiver, {
		"group": &"usable",
		"priority": 1,
	})))

	var reports: Array[Dictionary] = sensor.broadcast_to_candidates(registry, { "group": &"usable" }, 1)

	assert_eq(accepted_receiver.validate_count, 1, "rejected 候选不应耗尽 accepted 配额。")
	assert_eq(reports.size(), 2, "配额达成前的 rejected 报告仍应保留用于诊断。")
	if reports.size() >= 2:
		assert_true(GFVariantData.get_option_bool(reports[1], "ok"), "最后一个报告应来自 accepted 候选。")


func test_sensor_broadcast_reports_empty_dispatch_override_result() -> void:
	var root: Node = Node.new()
	var sensor: GFInteractionSensor = GFInteractionSensor.new()
	var dispatch: EmptyReportDispatchNode = EmptyReportDispatchNode.new()
	var receiver: RecordingReceiver = RecordingReceiver.new()
	add_child_autofree(root)
	root.add_child(sensor)
	root.add_child(dispatch)
	root.add_child(receiver)
	dispatch.name = "Dispatch"
	sensor.sender_path = NodePath("../Dispatch")
	sensor.group_name = &"targets"
	sensor.metadata = {
		"object": receiver,
	}
	receiver.add_to_group("targets")
	watch_signals(sensor)

	var reports: Array[Dictionary] = sensor.broadcast_to_group()
	var signal_parameters: Array = get_signal_parameters(sensor, "interaction_rejected")
	var signal_report: Dictionary = (
		GFVariantData.as_dictionary(signal_parameters[2])
		if signal_parameters.size() >= 3
		else {}
	)

	assert_eq(reports.size(), 1, "空报告不应在广播路径中被吞掉。")
	assert_false(GFVariantData.get_option_bool(reports[0], "ok"), "空报告应被转成失败报告。")
	assert_eq(GFVariantData.get_option_string(reports[0], "reason"), "invalid_report", "失败原因应明确为 invalid_report。")
	assert_false(_contains_live_object(signal_report), "空 override 报告的失败信号也必须保持 JSON-safe。")
	if not reports.is_empty():
		assert_eq(signal_report, reports[0], "空 override 报告的信号和返回值不得出现二次编码差异。")


func test_pointer_context_does_not_allow_pointer_reserved_payload_override() -> void:
	var pointer: GFPointerInteraction3D = GFPointerInteraction3D.new()
	add_child_autofree(pointer)

	var context: GFInteractionContext = pointer.build_context(&"entered", {
		"pointer_event": &"forged",
		"pointer_metadata": { "forged": true },
		"custom": 2,
	})
	var context_payload: Dictionary = GFVariantData.as_dictionary(context.payload)

	assert_eq(GFVariantData.get_option_string_name(context_payload, "pointer_event"), &"entered", "pointer_event 应由桥接节点控制。")
	assert_false(GFVariantData.get_option_dictionary(context_payload, "pointer_metadata").has("forged"), "pointer_metadata 不应被 pointer_data 覆盖。")
	assert_eq(GFVariantData.get_option_int(context_payload, "custom"), 2, "非保留业务字段仍应透传。")


func test_pointer_pickable_restore_uses_owner_count() -> void:
	var body: StaticBody3D = StaticBody3D.new()
	var first_pointer: GFPointerInteraction3D = GFPointerInteraction3D.new()
	var second_pointer: GFPointerInteraction3D = GFPointerInteraction3D.new()
	add_child_autofree(body)
	add_child_autofree(first_pointer)
	add_child_autofree(second_pointer)
	body.input_ray_pickable = false

	first_pointer.bind_collision_object(body)
	second_pointer.bind_collision_object(body)
	first_pointer.bind_collision_object(null)
	var still_pickable: bool = body.input_ray_pickable
	second_pointer.bind_collision_object(null)

	assert_true(still_pickable, "仍有桥接节点绑定时不应恢复 input_ray_pickable。")
	assert_false(body.input_ray_pickable, "最后一个桥接节点解绑后应恢复原始 input_ray_pickable。")


func test_pointer_cursor_owner_out_of_order_exit_restores_initial_cursor() -> void:
	var initial_cursor: Input.CursorShape = Input.get_current_cursor_shape()
	var first_pointer: GFPointerInteraction3D = GFPointerInteraction3D.new()
	var second_pointer: GFPointerInteraction3D = GFPointerInteraction3D.new()
	add_child_autofree(first_pointer)
	add_child_autofree(second_pointer)
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)
	Input.set_default_cursor_shape(Input.CURSOR_CROSS)
	var cursor_shape_is_observable: bool = (
		Input.get_current_cursor_shape() == Input.CURSOR_CROSS
	)
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)
	first_pointer.change_cursor_on_hover = true
	first_pointer.cursor_shape = Input.CURSOR_IBEAM
	second_pointer.change_cursor_on_hover = true
	second_pointer.cursor_shape = Input.CURSOR_CROSS

	first_pointer._set_hover_cursor(true)
	second_pointer._set_hover_cursor(true)
	first_pointer._set_hover_cursor(false)
	var cursor_after_first_exit: Input.CursorShape = Input.get_current_cursor_shape()
	var stack_after_first_exit: Array[Dictionary] = GFPointerInteraction3D._cursor_owner_stack.duplicate(true)
	second_pointer._set_hover_cursor(false)
	var cursor_after_last_exit: Input.CursorShape = Input.get_current_cursor_shape()
	var stack_after_last_exit: Array[Dictionary] = GFPointerInteraction3D._cursor_owner_stack.duplicate(true)
	Input.set_default_cursor_shape(initial_cursor)

	assert_eq(stack_after_first_exit.size(), 1, "非栈顶 owner 退出后应保留当前栈顶 owner。")
	if not stack_after_first_exit.is_empty():
		assert_eq(
			GFVariantData.get_option_int(stack_after_first_exit[0], "shape"),
			Input.CURSOR_CROSS,
			"保留的栈顶 owner 应维持自己的 cursor。"
		)
	assert_true(stack_after_last_exit.is_empty(), "最后一个 owner 退出后应清空所有权栈。")
	if cursor_shape_is_observable:
		assert_eq(cursor_after_first_exit, Input.CURSOR_CROSS, "非栈顶 owner 退出后应保持当前栈顶 cursor。")
		assert_eq(cursor_after_last_exit, Input.CURSOR_ARROW, "最后一个 owner 退出后应恢复首个 owner 进入前的 cursor。")


func test_pointer_off_tree_free_releases_pickable_owner() -> void:
	var body: StaticBody3D = StaticBody3D.new()
	var pointer: GFPointerInteraction3D = GFPointerInteraction3D.new()
	add_child_autofree(body)
	body.input_ray_pickable = false

	pointer.bind_collision_object(body)
	assert_true(body.input_ray_pickable, "绑定期间应 retain pickable 状态。")
	pointer.free()

	assert_false(body.input_ray_pickable, "off-tree pointer 释放时必须恢复 pickable 状态。")


func test_pointer_disabling_pickable_ensure_releases_existing_retain() -> void:
	var body: StaticBody3D = StaticBody3D.new()
	var pointer: GFPointerInteraction3D = GFPointerInteraction3D.new()
	add_child_autofree(body)
	add_child_autofree(pointer)
	body.input_ray_pickable = false
	pointer.bind_collision_object(body)

	pointer.ensure_input_ray_pickable = false

	assert_false(body.input_ray_pickable, "关闭 ensure_input_ray_pickable 应立即释放已有 retain。")


func test_sensor_broadcast_to_group_max_count_counts_accepted_receivers() -> void:
	var sensor: GFInteractionSensor = GFInteractionSensor.new()
	var rejected_receiver: GFInteractionReceiver = GFInteractionReceiver.new()
	var accepted_receiver: RecordingReceiver = RecordingReceiver.new()
	add_child_autofree(sensor)
	add_child_autofree(rejected_receiver)
	add_child_autofree(accepted_receiver)
	sensor.group_name = &"targets"
	rejected_receiver.enabled = false
	rejected_receiver.add_to_group("targets")
	accepted_receiver.add_to_group("targets")

	var reports: Array[Dictionary] = sensor.broadcast_to_group(&"", 1)

	assert_eq(accepted_receiver.validate_count, 1, "rejected 目标不应耗尽 max_count 的 accepted 配额。")
	assert_true(reports.size() >= 1, "广播应返回可诊断报告。")
	assert_true(GFVariantData.get_option_bool(reports[reports.size() - 1], "ok"), "最后一个报告应来自 accepted 目标。")


func test_sensor_broadcast_to_group_uses_sender_send_to_override() -> void:
	var root: Node = Node.new()
	var sensor: GFInteractionSensor = GFInteractionSensor.new()
	var sender: RecordingDispatchNode = RecordingDispatchNode.new()
	var receiver: RecordingReceiver = RecordingReceiver.new()
	add_child_autofree(root)
	root.add_child(sensor)
	root.add_child(sender)
	root.add_child(receiver)
	sender.name = "Sender"
	sensor.group_name = &"targets"
	sensor.sender_path = NodePath("../Sender")
	receiver.add_to_group("targets")
	watch_signals(sensor)

	var reports: Array[Dictionary] = sensor.broadcast_to_group()

	assert_eq(reports.size(), 1, "分组广播应通过可覆写发送者发送一次交互。")
	assert_same(sender.received_receiver, receiver, "sender_path 指向的发送者实现 send_to() 时应接管分组广播。")
	assert_true(sender.received_payload == null, "未覆盖 payload 时应透传 null，让业务发送者使用自身默认值。")
	assert_eq(sender.received_id, &"", "未覆盖交互 ID 时应透传空值，让业务发送者使用自身默认值。")
	assert_signal_emitted(sensor, "interaction_sent", "业务发送者接管分组广播时 Sensor 仍应发出 interaction_sent。")
	assert_signal_emitted(sensor, "interaction_accepted", "业务发送者返回成功报告时 Sensor 仍应发出 interaction_accepted。")


func test_sensor_ignores_sender_send_to_override_with_invalid_signature() -> void:
	var root: Node = Node.new()
	var sensor: GFInteractionSensor = GFInteractionSensor.new()
	var invalid_sender: InvalidDispatchNode = InvalidDispatchNode.new()
	var receiver: RecordingReceiver = RecordingReceiver.new()
	add_child_autofree(root)
	root.add_child(sensor)
	root.add_child(invalid_sender)
	root.add_child(receiver)
	invalid_sender.name = "InvalidSender"
	sensor.group_name = &"targets"
	sensor.sender_path = NodePath("../InvalidSender")
	receiver.add_to_group("targets")

	var reports: Array[Dictionary] = sensor.broadcast_to_group()

	assert_eq(reports.size(), 1, "无效 sender override 应回退到 Sensor 标准发送。")
	assert_false(invalid_sender.called, "签名不匹配的 send_to 不应被调用。")
	assert_same(receiver.received_context.sender, invalid_sender, "上下文 sender 仍应来自 sender_path。")


func test_sensor_ignores_sender_override_with_incompatible_argument_types() -> void:
	var root: Node = Node.new()
	var sensor: GFInteractionSensor = GFInteractionSensor.new()
	var invalid_sender: WrongTypedDispatchNode = WrongTypedDispatchNode.new()
	var receiver: RecordingReceiver = RecordingReceiver.new()
	add_child_autofree(root)
	root.add_child(sensor)
	root.add_child(invalid_sender)
	root.add_child(receiver)
	invalid_sender.name = "InvalidSender"
	sensor.group_name = &"targets"
	sensor.sender_path = NodePath("../InvalidSender")
	receiver.add_to_group("targets")

	var reports: Array[Dictionary] = sensor.broadcast_to_group()

	assert_eq(reports.size(), 1, "参数类型不兼容的 sender override 应回退到 Sensor 标准发送。")
	if not reports.is_empty():
		assert_true(GFVariantData.get_option_bool(reports[0], "ok"), "回退路径应保留有效接收结果。")
	assert_false(invalid_sender.called, "框架不得把 Object 传给要求 int 的 send_to()。")
	assert_eq(receiver.validate_count, 1, "回退路径应调用标准交互接收器。")


func test_sensor_ignores_sender_override_with_excess_required_arguments() -> void:
	var root: Node = Node.new()
	var sensor: GFInteractionSensor = GFInteractionSensor.new()
	var invalid_sender: ExcessRequiredArgsDispatchNode = ExcessRequiredArgsDispatchNode.new()
	var receiver: RecordingReceiver = RecordingReceiver.new()
	add_child_autofree(root)
	root.add_child(sensor)
	root.add_child(invalid_sender)
	root.add_child(receiver)
	invalid_sender.name = "InvalidSender"
	sensor.group_name = &"targets"
	sensor.sender_path = NodePath("../InvalidSender")
	receiver.add_to_group("targets")

	var reports: Array[Dictionary] = sensor.broadcast_to_group()

	assert_eq(reports.size(), 1, "额外必填参数的 override 应回退到 Sensor 标准发送。")
	assert_false(invalid_sender.called, "GF 不应以不足参数调用不兼容的 send_to()。")
	assert_eq(receiver.validate_count, 1, "回退路径应正常调用交互接收器。")


func test_sensor_normalizes_entire_override_report() -> void:
	var root: Node = Node.new()
	var sensor: GFInteractionSensor = GFInteractionSensor.new()
	var sender: UnsafeReportDispatchNode = UnsafeReportDispatchNode.new()
	var receiver: RecordingReceiver = RecordingReceiver.new()
	add_child_autofree(root)
	root.add_child(sensor)
	root.add_child(sender)
	root.add_child(receiver)
	sender.name = "Sender"
	sensor.sender_path = NodePath("../Sender")
	sensor.group_name = &"targets"
	receiver.add_to_group("targets")
	watch_signals(sensor)

	var reports: Array[Dictionary] = sensor.broadcast_to_group()
	assert_eq(reports.size(), 1, "sender override 应返回一个报告。")
	if reports.is_empty():
		return
	var report: Dictionary = reports[0]
	var signal_parameters: Array = get_signal_parameters(sensor, "interaction_sent")
	var signal_report: Dictionary = (
		GFVariantData.as_dictionary(signal_parameters[2])
		if signal_parameters.size() >= 3
		else {}
	)
	var nested_values: Array = GFVariantData.get_option_array(report, "nested_values")
	var report_metadata: Dictionary = GFVariantData.get_option_dictionary(report, "metadata")

	assert_true(GFVariantData.get_option_value(report, "leaked_object") is Dictionary, "顶层 Object 应编码为可诊断 marker。")
	assert_eq(nested_values.size(), 1, "报告编码不应丢弃嵌套数组值。")
	if not nested_values.is_empty():
		assert_false(nested_values[0] is Object, "嵌套数组中的 Object 也必须经过报告编码。")
	assert_false(GFVariantData.get_option_value(report_metadata, "object") is Object, "metadata 应与整个报告使用同一编码边界。")
	assert_true(GFVariantData.get_option_value(report_metadata, "object") is Dictionary, "metadata Object 不应被静默降级为 null。")
	assert_false(_contains_live_object(signal_report), "自定义 sender 信号不得暴露 raw Object。")
	assert_eq(signal_report, report, "自定义 sender 信号和返回值必须各自只编码一次。")


func test_sensor_collision_candidates_resolve_receiver_ancestors() -> void:
	var host: RecordingDispatchHost = RecordingDispatchHost.new()
	var receiver: RecordingReceiver = RecordingReceiver.new()
	var collider_child: Node = Node.new()
	add_child_autofree(receiver)
	receiver.add_child(collider_child)

	var reports: Array[Dictionary] = []
	reports.assign(GF_MESSAGE_DISPATCH_SUPPORT._send_to_collision_candidates(
		host,
		[collider_child],
		0,
		{ "value": 3 },
		&"hit",
		&"receive_interaction"
	))

	assert_eq(reports.size(), 1, "碰撞候选应能向上解析到交互接收器。")
	assert_true(GFVariantData.get_option_bool(reports[0], "ok"), "解析到的接收器应交给发送宿主。")
	assert_same(host.received_receiver, receiver, "交互上下文 target 应使用解析后的接收器。")
	assert_eq(GFVariantData.as_dictionary(host.received_payload), { "value": 3 }, "payload 覆盖值应透传给发送宿主。")
	assert_eq(host.received_id, &"hit", "交互 ID 覆盖值应透传给发送宿主。")


func test_sensor_collision_dispatch_uses_sender_send_to_override() -> void:
	var root: Node = Node.new()
	var sensor: GFInteractionSensor = GFInteractionSensor.new()
	var sender: RecordingDispatchNode = RecordingDispatchNode.new()
	var receiver: RecordingReceiver = RecordingReceiver.new()
	add_child_autofree(root)
	root.add_child(sensor)
	root.add_child(sender)
	root.add_child(receiver)
	sender.name = "Sender"
	sensor.sender_path = NodePath("../Sender")
	watch_signals(sensor)

	var reports: Array[Dictionary] = []
	reports.assign(GF_MESSAGE_DISPATCH_SUPPORT._send_to_collision_candidates(
		sensor._resolve_collision_dispatch_host(),
		[receiver],
		0,
		{ "value": 3 },
		&"use",
		&"receive_interaction",
		Callable(sensor, "_emit_collision_dispatch_result")
	))

	assert_eq(reports.size(), 1, "碰撞广播应通过可覆写发送者发送一次交互。")
	assert_same(sender.received_receiver, receiver, "sender_path 指向的发送者实现 send_to() 时应接管碰撞分发。")
	assert_eq(GFVariantData.as_dictionary(sender.received_payload), { "value": 3 }, "payload 覆盖值应透传给业务发送者。")
	assert_eq(sender.received_id, &"use", "交互 ID 覆盖值应透传给业务发送者。")
	assert_signal_emitted(sensor, "interaction_sent", "业务发送者接管碰撞分发时 Sensor 仍应发出 interaction_sent。")


func test_sensor_area_2d_signal_receives_normalized_override_report() -> void:
	var root: Node2D = Node2D.new()
	var sensor: GFInteractionSensor = GFInteractionSensor.new()
	var sender: UnsafeReportDispatchNode = UnsafeReportDispatchNode.new()
	var query_area: Area2D = Area2D.new()
	var receiver_area: InteractionCollisionArea2D = InteractionCollisionArea2D.new()
	add_child_autofree(root)
	root.add_child(sensor)
	root.add_child(sender)
	root.add_child(query_area)
	root.add_child(receiver_area)
	sender.name = "Sender"
	sensor.sender_path = NodePath("../Sender")
	_add_area_2d_shape(query_area)
	_add_area_2d_shape(receiver_area)
	watch_signals(sensor)
	await get_tree().physics_frame
	await get_tree().physics_frame

	var reports: Array[Dictionary] = sensor.broadcast_to_area_2d(query_area)
	var signal_parameters: Array = get_signal_parameters(sensor, "interaction_sent")
	var signal_report: Dictionary = (
		GFVariantData.as_dictionary(signal_parameters[2])
		if signal_parameters.size() >= 3
		else {}
	)

	assert_eq(reports.size(), 1, "Area2D 重叠接收器应产生一个报告。")
	assert_eq(signal_parameters.size(), 3, "Area2D 碰撞分发应发出完整 interaction_sent 参数。")
	assert_false(_contains_live_object(signal_report), "Area2D interaction_sent 不得先暴露 raw Object。")
	assert_false(JSON.stringify(signal_report).is_empty(), "Area2D interaction_sent 报告必须可直接 JSON.stringify。")
	if not reports.is_empty():
		assert_eq(signal_report, reports[0], "Area2D 信号和返回值必须共享同一规范化报告。")


func test_sensor_area_2d_converts_every_invalid_override_result_to_report() -> void:
	var root: Node2D = Node2D.new()
	var sensor: GFInteractionSensor = GFInteractionSensor.new()
	var sender: ConfigurableInvalidReportDispatchNode = ConfigurableInvalidReportDispatchNode.new()
	var query_area: Area2D = Area2D.new()
	var receiver_area: InteractionCollisionArea2D = InteractionCollisionArea2D.new()
	add_child_autofree(root)
	root.add_child(sensor)
	root.add_child(sender)
	root.add_child(query_area)
	root.add_child(receiver_area)
	sender.name = "Sender"
	sensor.sender_path = NodePath("../Sender")
	_add_area_2d_shape(query_area)
	_add_area_2d_shape(receiver_area)
	watch_signals(sensor)
	await get_tree().physics_frame
	await get_tree().physics_frame

	sender.result = {}
	var empty_reports: Array[Dictionary] = sensor.broadcast_to_area_2d(query_area, 0, null, &"inspect")
	sender.result = 42
	var non_dictionary_reports: Array[Dictionary] = sensor.broadcast_to_area_2d(query_area, 0, null, &"inspect")

	assert_eq(empty_reports.size(), 1, "Area2D 的空 Dictionary 返回值必须转换为一个失败报告。")
	assert_eq(non_dictionary_reports.size(), 1, "Area2D 的非 Dictionary 返回值不得被静默丢弃。")
	if not empty_reports.is_empty():
		_assert_complete_invalid_report(empty_reports[0], &"inspect")
	if not non_dictionary_reports.is_empty():
		_assert_complete_invalid_report(non_dictionary_reports[0], &"inspect")
	assert_signal_emit_count(sensor, "interaction_rejected", 2, "每次 Area2D 失败分发都必须可观测。")


func test_sensor_area_3d_signal_receives_normalized_override_report() -> void:
	var root: Node3D = Node3D.new()
	var sensor: GFInteractionSensor = GFInteractionSensor.new()
	var sender: UnsafeReportDispatchNode = UnsafeReportDispatchNode.new()
	var query_area: Area3D = Area3D.new()
	var receiver_area: InteractionCollisionArea3D = InteractionCollisionArea3D.new()
	add_child_autofree(root)
	root.add_child(sensor)
	root.add_child(sender)
	root.add_child(query_area)
	root.add_child(receiver_area)
	sender.name = "Sender"
	sensor.sender_path = NodePath("../Sender")
	_add_area_3d_shape(query_area)
	_add_area_3d_shape(receiver_area)
	watch_signals(sensor)
	await get_tree().physics_frame
	await get_tree().physics_frame

	var reports: Array[Dictionary] = sensor.broadcast_to_area_3d(query_area)
	var signal_parameters: Array = get_signal_parameters(sensor, "interaction_sent")
	var signal_report: Dictionary = (
		GFVariantData.as_dictionary(signal_parameters[2])
		if signal_parameters.size() >= 3
		else {}
	)

	assert_eq(reports.size(), 1, "Area3D 重叠接收器应产生一个报告。")
	assert_eq(signal_parameters.size(), 3, "Area3D 碰撞分发应发出完整 interaction_sent 参数。")
	assert_false(_contains_live_object(signal_report), "Area3D interaction_sent 不得先暴露 raw Object。")
	assert_false(JSON.stringify(signal_report).is_empty(), "Area3D interaction_sent 报告必须可直接 JSON.stringify。")
	if not reports.is_empty():
		assert_eq(signal_report, reports[0], "Area3D 信号和返回值必须共享同一规范化报告。")


func test_sensor_area_3d_converts_every_invalid_override_result_to_report() -> void:
	var root: Node3D = Node3D.new()
	var sensor: GFInteractionSensor = GFInteractionSensor.new()
	var sender: ConfigurableInvalidReportDispatchNode = ConfigurableInvalidReportDispatchNode.new()
	var query_area: Area3D = Area3D.new()
	var receiver_area: InteractionCollisionArea3D = InteractionCollisionArea3D.new()
	add_child_autofree(root)
	root.add_child(sensor)
	root.add_child(sender)
	root.add_child(query_area)
	root.add_child(receiver_area)
	sender.name = "Sender"
	sensor.sender_path = NodePath("../Sender")
	_add_area_3d_shape(query_area)
	_add_area_3d_shape(receiver_area)
	watch_signals(sensor)
	await get_tree().physics_frame
	await get_tree().physics_frame

	sender.result = {}
	var empty_reports: Array[Dictionary] = sensor.broadcast_to_area_3d(query_area, 0, null, &"inspect")
	sender.result = 42
	var non_dictionary_reports: Array[Dictionary] = sensor.broadcast_to_area_3d(query_area, 0, null, &"inspect")

	assert_eq(empty_reports.size(), 1, "Area3D 的空 Dictionary 返回值必须转换为一个失败报告。")
	assert_eq(non_dictionary_reports.size(), 1, "Area3D 的非 Dictionary 返回值不得被静默丢弃。")
	if not empty_reports.is_empty():
		_assert_complete_invalid_report(empty_reports[0], &"inspect")
	if not non_dictionary_reports.is_empty():
		_assert_complete_invalid_report(non_dictionary_reports[0], &"inspect")
	assert_signal_emit_count(sensor, "interaction_rejected", 2, "每次 Area3D 失败分发都必须可观测。")


func test_pointer_interaction_3d_sends_click_context_to_receiver() -> void:
	var root: Node3D = Node3D.new()
	var body: StaticBody3D = StaticBody3D.new()
	var receiver: RecordingReceiver = RecordingReceiver.new()
	var pointer: GFPointerInteraction3D = GFPointerInteraction3D.new()
	add_child_autofree(root)
	root.add_child(body)
	root.add_child(receiver)
	body.add_child(pointer)
	pointer.receiver_path = NodePath("../../RecordingReceiver")
	receiver.name = "RecordingReceiver"
	pointer.interaction_id = &"inspect"
	pointer.payload = { "kind": "object" }
	pointer.bind_collision_object(body)

	var press: InputEventMouseButton = _make_mouse_button(MOUSE_BUTTON_LEFT, true)
	var release: InputEventMouseButton = _make_mouse_button(MOUSE_BUTTON_LEFT, false)
	pointer._on_collision_input_event(null, press, Vector3(1.0, 2.0, 3.0), Vector3.UP, 0)
	pointer._on_collision_input_event(null, release, Vector3(1.0, 2.0, 3.0), Vector3.UP, 0)

	assert_not_null(receiver.received_context, "点击应发送交互上下文。")
	assert_same(receiver.received_context.target, receiver, "上下文 target 应为解析到的接收器。")
	var received_payload: Dictionary = GFVariantData.as_dictionary(receiver.received_context.payload)
	assert_eq(GFVariantData.get_option_string(received_payload, "kind"), "object", "基础 payload 应保留。")
	assert_eq(GFVariantData.get_option_string_name(received_payload, "pointer_event"), &"clicked", "点击事件应写入 payload。")
	assert_eq(GFVariantData.get_option_vector3(received_payload, "pointer_position"), Vector3(1.0, 2.0, 3.0), "点击位置应写入 payload。")
	assert_false(received_payload.has("pointer_camera"), "pointer payload 不应携带 Camera3D 原始对象。")
	assert_false(received_payload.has("pointer_input_event"), "pointer payload 不应携带 InputEvent 原始对象。")
	assert_eq(GFVariantData.get_option_string(received_payload, "pointer_input_event_class"), "InputEventMouseButton", "pointer payload 应保留事件类型快照。")


func test_pointer_interaction_3d_tracks_pressed_state_per_button() -> void:
	var pointer: GFPointerInteraction3D = GFPointerInteraction3D.new()
	add_child_autofree(pointer)
	pointer.send_on_clicked = false
	watch_signals(pointer)

	pointer._on_collision_input_event(null, _make_mouse_button(MOUSE_BUTTON_LEFT, true), Vector3.ZERO, Vector3.UP, 0)
	pointer._on_collision_input_event(null, _make_mouse_button(MOUSE_BUTTON_RIGHT, true), Vector3.ZERO, Vector3.UP, 0)
	pointer._on_collision_input_event(null, _make_mouse_button(MOUSE_BUTTON_RIGHT, false), Vector3.ZERO, Vector3.UP, 0)
	pointer._on_collision_input_event(null, _make_mouse_button(MOUSE_BUTTON_LEFT, false), Vector3.ZERO, Vector3.UP, 0)
	pointer._on_collision_input_event(null, _make_mouse_button(MOUSE_BUTTON_LEFT, true, 1), Vector3.ZERO, Vector3.UP, 0)
	pointer._on_collision_input_event(null, _make_mouse_button(MOUSE_BUTTON_LEFT, true, 2), Vector3.ZERO, Vector3.UP, 0)
	pointer._on_collision_input_event(null, _make_mouse_button(MOUSE_BUTTON_LEFT, false, 2), Vector3.ZERO, Vector3.UP, 0)
	pointer._on_collision_input_event(null, _make_mouse_button(MOUSE_BUTTON_LEFT, false, 1), Vector3.ZERO, Vector3.UP, 0)

	assert_signal_emit_count(pointer, "pointer_clicked", 4, "并行按钮及不同设备上的同名按钮应各自完成一次点击。")
	pointer._reset_pointer_state(false)
	for device: int in range(GFPointerInteraction3D._MAX_ACTIVE_PRESSED_BUTTONS + 1):
		pointer._on_collision_input_event(
			null,
			_make_mouse_button(MOUSE_BUTTON_LEFT, true, device),
			Vector3.ZERO,
			Vector3.UP,
			0
		)
	assert_eq(
		pointer._pressed_buttons.size(),
		GFPointerInteraction3D._MAX_ACTIVE_PRESSED_BUTTONS,
		"未完成 pressed 状态必须受硬上限约束。"
	)


func test_pointer_interaction_3d_emits_hover_without_sending_by_default() -> void:
	var root: Node3D = Node3D.new()
	var body: StaticBody3D = StaticBody3D.new()
	var receiver: RecordingReceiver = RecordingReceiver.new()
	var pointer: GFPointerInteraction3D = GFPointerInteraction3D.new()
	var entered: Array[GFInteractionContext] = []
	add_child_autofree(root)
	root.add_child(body)
	root.add_child(receiver)
	body.add_child(pointer)
	pointer.receiver_path = NodePath("../../RecordingReceiver")
	receiver.name = "RecordingReceiver"
	var _connect_result_370: Variant = pointer.pointer_entered.connect(func(context: GFInteractionContext) -> void:
		entered.append(context)
	)
	pointer.bind_collision_object(body)

	pointer._on_collision_mouse_entered()

	assert_eq(entered.size(), 1, "hover 进入应发出本地信号。")
	assert_null(receiver.received_context, "默认不应把 hover 自动发送给接收器。")


func test_pointer_interaction_3d_rebinding_resets_hover_press_state() -> void:
	var first_body: StaticBody3D = StaticBody3D.new()
	var second_body: StaticBody3D = StaticBody3D.new()
	var pointer: GFPointerInteraction3D = GFPointerInteraction3D.new()
	add_child_autofree(first_body)
	add_child_autofree(second_body)
	first_body.add_child(pointer)
	pointer.bind_collision_object(first_body)
	watch_signals(pointer)

	pointer._on_collision_mouse_entered()
	pointer._on_collision_input_event(null, _make_mouse_button(MOUSE_BUTTON_LEFT, true), Vector3.ZERO, Vector3.UP, 0)
	pointer.bind_collision_object(second_body)
	pointer._on_collision_input_event(null, _make_mouse_button(MOUSE_BUTTON_LEFT, false), Vector3.ZERO, Vector3.UP, 0)

	assert_false(pointer._is_hovered, "重新绑定时应清理 hover 状态。")
	assert_eq(pointer._pressed_button, 0, "重新绑定时应清理 pressed button。")
	assert_signal_not_emitted(pointer, "pointer_clicked", "旧对象上的 press 不应在新对象 release 时形成点击。")


func test_pointer_interaction_3d_restores_input_ray_pickable_on_unbind() -> void:
	var body: StaticBody3D = StaticBody3D.new()
	var pointer: GFPointerInteraction3D = GFPointerInteraction3D.new()
	add_child_autofree(body)
	body.add_child(pointer)
	body.input_ray_pickable = false

	pointer.bind_collision_object(body)
	var pickable_during_bind: bool = body.input_ray_pickable
	pointer.bind_collision_object(null)

	assert_true(pickable_during_bind, "绑定期间应确保 input_ray_pickable。")
	assert_false(body.input_ray_pickable, "解绑后应恢复外部 CollisionObject3D 原始 pickable 设置。")


func test_pointer_interaction_3d_disabling_resets_active_state() -> void:
	var body: StaticBody3D = StaticBody3D.new()
	var pointer: GFPointerInteraction3D = GFPointerInteraction3D.new()
	add_child_autofree(body)
	body.add_child(pointer)
	pointer.bind_collision_object(body)
	watch_signals(pointer)

	pointer._on_collision_mouse_entered()
	pointer._on_collision_input_event(null, _make_mouse_button(MOUSE_BUTTON_LEFT, true), Vector3.ZERO, Vector3.UP, 0)
	pointer.enabled = false
	pointer._on_collision_input_event(null, _make_mouse_button(MOUSE_BUTTON_LEFT, false), Vector3.ZERO, Vector3.UP, 0)

	assert_false(pointer._is_hovered, "禁用时应清理 hover 状态。")
	assert_eq(pointer._pressed_button, 0, "禁用时应清理 pressed button。")
	assert_signal_not_emitted(pointer, "pointer_clicked", "禁用后 release 不应继承旧 press 形成点击。")


# --- 私有/辅助方法 ---

func _add_area_2d_shape(area: Area2D) -> void:
	var collision_shape: CollisionShape2D = CollisionShape2D.new()
	var shape: CircleShape2D = CircleShape2D.new()
	shape.radius = 8.0
	collision_shape.shape = shape
	area.add_child(collision_shape)


func _add_area_3d_shape(area: Area3D) -> void:
	var collision_shape: CollisionShape3D = CollisionShape3D.new()
	var shape: SphereShape3D = SphereShape3D.new()
	shape.radius = 8.0
	collision_shape.shape = shape
	area.add_child(collision_shape)


func _make_mouse_button(
	button_index: MouseButton,
	pressed: bool,
	device: int = 0,
	window_id: int = 0
) -> InputEventMouseButton:
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.button_index = button_index
	event.pressed = pressed
	event.device = device
	event.window_id = window_id
	return event


func _assert_complete_invalid_report(report: Dictionary, expected_id: StringName) -> void:
	assert_false(GFVariantData.get_option_bool(report, "ok"), "无效分发结果必须失败关闭。")
	assert_eq(
		_encoded_string_name(GFVariantData.get_option_value(report, "interaction_id")),
		expected_id
	)
	assert_eq(GFVariantData.get_option_string(report, "reason"), "invalid_report")
	assert_true(report.has("receiver"), "失败报告必须保留 receiver 字段。")
	assert_true(report.has("message"), "失败报告必须保留 message 字段。")
	assert_true(report.has("metadata"), "失败报告必须保留 metadata 字段。")
	assert_false(_contains_live_object(report), "失败报告必须保持 JSON-safe。")
	assert_false(JSON.stringify(report).is_empty(), "失败报告必须可直接 JSON.stringify。")


func _receiver_instance_id(report: Dictionary) -> int:
	var receiver_report: Dictionary = GFVariantData.get_option_dictionary(report, "receiver")
	var marker: Dictionary = GFVariantData.get_option_dictionary(receiver_report, "__gf_report_value__")
	return GFVariantData.get_option_int(marker, "instance_id", -1)


func _report_marker(value: Variant) -> Dictionary:
	return GFVariantData.get_option_dictionary(
		GFVariantData.as_dictionary(value),
		"__gf_report_value__"
	)


func _report_marker_type(value: Variant) -> String:
	var report_marker: Dictionary = _report_marker(value)
	if not report_marker.is_empty():
		return GFVariantData.get_option_string(report_marker, "type")
	var variant_marker: Dictionary = GFVariantData.get_option_dictionary(
		GFVariantData.as_dictionary(value),
		"__gf_variant__"
	)
	return GFVariantData.get_option_string(variant_marker, "type")


func _encoded_string_name(value: Variant) -> StringName:
	if value is StringName:
		var string_name_value: StringName = value
		return string_name_value
	if value is String:
		var string_value: String = value
		return StringName(string_value)
	var variant_marker: Dictionary = GFVariantData.get_option_dictionary(
		GFVariantData.as_dictionary(value),
		"__gf_variant__"
	)
	if GFVariantData.get_option_string(variant_marker, "type") != "StringName":
		return &""
	return StringName(GFVariantData.get_option_string(variant_marker, "value"))


func _contains_live_object(value: Variant) -> bool:
	var worklist: Array = [value]
	while not worklist.is_empty():
		var candidate: Variant = worklist.pop_back()
		if candidate is Object:
			return true
		if candidate is Dictionary:
			var dictionary: Dictionary = candidate
			for key: Variant in dictionary.keys():
				worklist.append(key)
				worklist.append(dictionary[key])
		elif candidate is Array:
			var array: Array = candidate
			for item: Variant in array:
				worklist.append(item)
	return false
