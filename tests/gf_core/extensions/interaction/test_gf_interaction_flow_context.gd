## 测试 GFInteractionContext 链式构造与 GFInteractionFlow 的命令派发。
extends GutTest

class RecordingCommand extends RefCounted:
	var interaction_context: Variant = null

	func set_interaction_context(context: Variant) -> void:
		interaction_context = context

	func execute() -> String:
		return "ok"


class PlainExecuteCommand extends RefCounted:
	func execute() -> int:
		return 99


class PropertyOnlyCommand extends RefCounted:
	var interaction_context: Variant = null

	func execute() -> String:
		return "property"


class ExcessRequiredContextCommand extends RefCounted:
	var context_method_called: bool = false

	func set_interaction_context(_context: Variant, _required_argument: Variant) -> void:
		context_method_called = true

	func execute() -> String:
		return "executed"


class WrongTypedContextCommand extends RefCounted:
	var context_method_called: bool = false

	func set_interaction_context(_context: int) -> void:
		context_method_called = true

	func execute() -> String:
		return "executed"


class SpyArchitecture extends GFArchitecture:
	var sent_command: Object = null

	func send_command(command: Object) -> Variant:
		sent_command = command
		return "arch"


func test_interaction_context_chain_sets_fields() -> void:
	var ctx: GFInteractionContext = GFInteractionContext.new()
	var sender: Node = Node.new()
	add_child_autofree(sender)
	var target: Node = Node.new()
	add_child_autofree(target)
	var out: GFInteractionContext = (
		ctx.with_sender(sender).with_target(target).with_payload(42).with_group(&"g")
	)
	assert_same(out, ctx)
	assert_same(ctx.sender, sender)
	assert_same(ctx.target, target)
	assert_eq(GFVariantData.to_int(ctx.payload), 42)
	assert_eq(ctx.group_name, &"g")


func test_interaction_context_keeps_snapshots_without_strong_references() -> void:
	var ctx: GFInteractionContext = GFInteractionContext.new()
	var target: Node = Node.new()
	var _with_target_result: GFInteractionContext = ctx.with_target(target)
	var target_instance_id: int = target.get_instance_id()

	target.free()

	assert_null(ctx.target, "目标释放后上下文不应继续返回强引用。")
	assert_eq(ctx.target_instance_id, target_instance_id, "目标 instance_id 快照应保留用于诊断和回放。")


func test_interaction_flow_chaining_updates_context() -> void:
	var ctx: GFInteractionContext = GFInteractionContext.new()
	var flow: GFInteractionFlow = GFInteractionFlow.new(ctx)
	var sender: Node = Node.new()
	add_child_autofree(sender)
	var _in_group_result_48: Variant = flow.to(sender).with_payload("x").in_group(&"combat")
	assert_same(flow.context.target, sender)
	assert_eq(GFVariantData.to_text(flow.context.payload), "x")
	assert_eq(flow.context.group_name, &"combat")


func test_interaction_flow_execute_null_returns_null() -> void:
	var flow: GFInteractionFlow = GFInteractionFlow.new()
	assert_true(flow.execute(null) == null)


func test_interaction_flow_execute_applies_context_and_calls_architecture() -> void:
	var arch: SpyArchitecture = SpyArchitecture.new()
	var ctx: GFInteractionContext = GFInteractionContext.new()
	var flow: GFInteractionFlow = GFInteractionFlow.new(ctx)
	flow.inject_dependencies(arch)
	var cmd: RecordingCommand = RecordingCommand.new()
	var result: Variant = flow.execute(cmd)
	assert_eq(GFVariantData.to_text(result), "arch")
	assert_same(arch.sent_command, cmd)
	assert_same(_interaction_context(cmd.interaction_context), ctx)


func test_interaction_flow_execute_without_architecture_falls_back_to_command() -> void:
	var flow: GFInteractionFlow = GFInteractionFlow.new()
	var cmd: PlainExecuteCommand = PlainExecuteCommand.new()
	assert_eq(GFVariantData.to_int(flow.execute(cmd)), 99)


func test_interaction_flow_injects_property_only_context() -> void:
	var ctx: GFInteractionContext = GFInteractionContext.new()
	var flow: GFInteractionFlow = GFInteractionFlow.new(ctx)
	var cmd: PropertyOnlyCommand = PropertyOnlyCommand.new()

	var result: Variant = flow.execute(cmd)

	assert_eq(GFVariantData.to_text(result), "property")
	assert_same(_interaction_context(cmd.interaction_context), ctx)


func test_interaction_flow_rejects_context_method_with_excess_required_arguments() -> void:
	var flow: GFInteractionFlow = GFInteractionFlow.new(GFInteractionContext.new())
	var command: ExcessRequiredContextCommand = ExcessRequiredContextCommand.new()

	var result: Variant = flow.execute(command)

	assert_eq(GFVariantData.to_text(result), "executed")
	assert_false(command.context_method_called, "GF 不应以不足参数调用不兼容的 set_interaction_context()。")


func test_interaction_flow_rejects_context_method_with_incompatible_argument_type() -> void:
	var flow: GFInteractionFlow = GFInteractionFlow.new(GFInteractionContext.new())
	var command: WrongTypedContextCommand = WrongTypedContextCommand.new()

	var result: Variant = flow.execute(command)

	assert_eq(GFVariantData.to_text(result), "executed")
	assert_false(command.context_method_called, "GF 不得把 GFInteractionContext 传给要求 int 的 setter。")


func test_interaction_flow_send_event_null_is_no_op() -> void:
	var flow: GFInteractionFlow = GFInteractionFlow.new()
	flow.send_event(null)
	assert_true(flow.context != null, "send_event(null) 应静默返回且 Flow 仍持有默认上下文。")


func _interaction_context(value: Variant) -> GFInteractionContext:
	if value is GFInteractionContext:
		var context: GFInteractionContext = value
		return context
	return null
