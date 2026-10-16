## 测试声明式信号桥接资源。
extends GutTest


# --- 测试方法 ---

## 验证信号桥接可重排参数、追加常量和上下文。
func test_signal_bridge_maps_signal_arguments() -> void:
	var root: Node = Node.new()
	add_child_autofree(root)

	var emitter: SampleEmitter = SampleEmitter.new()
	emitter.name = "Emitter"
	root.add_child(emitter)

	var listener: SampleListener = SampleListener.new()
	listener.name = "Listener"
	root.add_child(listener)

	var bridge: GFSignalBridge = GFSignalBridge.new()
	bridge.source.source_path = root.get_path_to(emitter)
	bridge.source.signal_name = &"changed"
	bridge.target.target_path = root.get_path_to(listener)
	bridge.target.method_name = &"record"
	bridge.argument_indices = PackedInt32Array([1, 0])
	bridge.constant_args = ["fixed"]
	bridge.append_context = true

	var binding: GFSignalBridgeBinding = bridge.connect_bridge(root)
	emitter.emit_changed(7, "hp")
	var received: Dictionary = GFVariantData.as_dictionary(listener.received[0])
	var context: Dictionary = GFVariantData.get_option_dictionary(received, "context")

	assert_true(
		binding != null and binding.is_active(),
		"桥接应创建有效运行绑定。"
	)
	assert_eq(
		listener.received.size(),
		1,
		"桥接目标应收到调用。"
	)
	assert_eq(
		GFVariantData.get_option_string(received, "label"),
		"hp",
		"参数应支持重排。"
	)
	assert_eq(
		GFVariantData.get_option_int(received, "value"),
		7,
		"参数值应保持原始信号数据。"
	)
	assert_eq(
		GFVariantData.get_option_string(received, "constant"),
		"fixed",
		"常量参数应追加到桥接参数后。"
	)
	assert_eq(
		GFVariantData.get_option_array(context, "signal_args"),
		[7, "hp"],
		"上下文应包含原始信号参数。"
	)


func test_signal_bridge_keeps_nine_signal_arguments() -> void:
	var root: Node = Node.new()
	add_child_autofree(root)

	var emitter: WideEmitter = WideEmitter.new()
	emitter.name = "Emitter"
	root.add_child(emitter)

	var listener: WideListener = WideListener.new()
	listener.name = "Listener"
	root.add_child(listener)

	var bridge: GFSignalBridge = GFSignalBridge.new()
	bridge.source.source_path = root.get_path_to(emitter)
	bridge.source.signal_name = &"wide_changed"
	bridge.target.target_path = root.get_path_to(listener)
	bridge.target.method_name = &"record_wide"

	var binding: GFSignalBridgeBinding = bridge.connect_bridge(root)
	emitter.emit_wide_changed()

	assert_true(
		binding != null and binding.is_active(),
		"桥接应创建有效运行绑定。"
	)
	assert_eq(
		listener.received,
		[
			1,
			2,
			3,
			4,
			5,
			6,
			7,
			8,
			9,
		],
		"桥接应保留 9 个信号参数。"
	)


func test_signal_bridge_validation_reports_argument_index_out_of_range() -> void:
	var root: Node = Node.new()
	add_child_autofree(root)

	var emitter: SampleEmitter = SampleEmitter.new()
	emitter.name = "Emitter"
	root.add_child(emitter)

	var listener: SampleListener = SampleListener.new()
	listener.name = "Listener"
	root.add_child(listener)

	var bridge: GFSignalBridge = GFSignalBridge.new()
	bridge.source.source_path = root.get_path_to(emitter)
	bridge.source.signal_name = &"changed"
	bridge.target.target_path = root.get_path_to(listener)
	bridge.target.method_name = &"record_value"
	bridge.argument_indices = PackedInt32Array([2])

	var report: Dictionary = bridge.get_validation_report(root)
	var issues: Array = GFVariantData.get_option_array(report, "issues")

	assert_false(
		GFVariantData.get_option_bool(report, "ok"),
		"越界参数索引应产生校验错误。"
	)
	assert_true(
		_has_issue_kind(issues, "argument_index_out_of_range"),
		"校验报告应包含参数索引越界问题。"
	)


func test_signal_bridge_validation_reports_callable_argument_mismatch() -> void:
	var root: Node = Node.new()
	add_child_autofree(root)

	var emitter: SampleEmitter = SampleEmitter.new()
	emitter.name = "Emitter"
	root.add_child(emitter)

	var listener: SampleListener = SampleListener.new()
	listener.name = "Listener"
	root.add_child(listener)

	var bridge: GFSignalBridge = GFSignalBridge.new()
	bridge.source.source_path = root.get_path_to(emitter)
	bridge.source.signal_name = &"changed"
	bridge.target.target_path = root.get_path_to(listener)
	bridge.target.method_name = &"record_value"

	var report: Dictionary = bridge.get_validation_report(root)
	var issues: Array = GFVariantData.get_option_array(report, "issues")

	assert_false(
		GFVariantData.get_option_bool(report, "ok"),
		"目标方法参数数量不匹配应产生校验错误。"
	)
	assert_true(
		_has_issue_kind(issues, "callable_argument_mismatch"),
		"校验报告应包含目标参数数量不匹配问题。"
	)


## 验证信号桥接报告无效目标。
func test_signal_bridge_validation_reports_invalid_target() -> void:
	var root: Node = Node.new()
	add_child_autofree(root)

	var emitter: SampleEmitter = SampleEmitter.new()
	emitter.name = "Emitter"
	root.add_child(emitter)

	var listener: SampleListener = SampleListener.new()
	listener.name = "Listener"
	root.add_child(listener)

	var bridge: GFSignalBridge = GFSignalBridge.new()
	bridge.source.source_path = root.get_path_to(emitter)
	bridge.source.signal_name = &"changed"
	bridge.target.target_path = root.get_path_to(listener)
	bridge.target.method_name = &"missing"

	var report: Dictionary = bridge.get_validation_report(root)
	var issues: Array = GFVariantData.get_option_array(report, "issues")
	var first_issue: Dictionary = GFVariantData.as_dictionary(issues[0])

	assert_false(
		GFVariantData.get_option_bool(report, "ok"),
		"无效目标应产生校验错误。"
	)
	assert_eq(
		GFVariantData.get_option_string(first_issue, "kind"),
		"invalid_callable_target",
		"校验报告应包含目标错误。"
	)
	assert_eq(
		GFVariantData.get_option_int(report, "error_count"),
		1,
		"校验报告应统计错误数量。"
	)
	assert_eq(
		GFVariantData.get_option_int(report, "issue_count"),
		1,
		"校验报告应统计问题总数。"
	)
	assert_eq(
		GFVariantData.get_option_string(first_issue, "path"),
		"target",
		"校验问题应包含通用路径字段。"
	)


# --- 私有/辅助方法 ---

func _has_issue_kind(issues: Array, kind: String) -> bool:
	for issue_value: Variant in issues:
		var issue: Dictionary = GFVariantData.as_dictionary(issue_value)
		if GFVariantData.get_option_string(issue, "kind") == kind:
			return true
	return false


# --- 内部类 ---

class SampleEmitter:
	extends Node

	signal changed(value: int, label: String)

	func emit_changed(value: int, label: String) -> void:
		changed.emit(value, label)


class WideEmitter:
	extends Node

	signal wide_changed(
		first: int,
		second: int,
		third: int,
		fourth: int,
		fifth: int,
		sixth: int,
		seventh: int,
		eighth: int,
		ninth: int
	)

	func emit_wide_changed() -> void:
		wide_changed.emit(
			1,
			2,
			3,
			4,
			5,
			6,
			7,
			8,
			9
		)


class SampleListener:
	extends Node

	var received: Array[Variant] = []

	func record(
		label: String,
		value: int,
		constant_value: String,
		context: Dictionary
	) -> void:
		received.append(
			{
				"label": label,
				"value": value,
				"constant": constant_value,
				"context": context,
			}
		)


	func record_value(value: int) -> void:
		received.append(value)


class WideListener:
	extends Node

	var received: Array[Variant] = []

	func record_wide(
		first: int,
		second: int,
		third: int,
		fourth: int,
		fifth: int,
		sixth: int,
		seventh: int,
		eighth: int,
		ninth: int
	) -> void:
		received = [
			first,
			second,
			third,
			fourth,
			fifth,
			sixth,
			seventh,
			eighth,
			ninth,
		]
