extends RefCounted


# --- 公共方法 ---

func make_rewrite_interceptor(order_list: Array) -> Object:
	return RewriteInterceptor.new(order_list)


func make_priority_interceptor(order_list: Array, label: String, priority: int) -> Object:
	return PriorityInterceptor.new(order_list, label, priority)


func make_stop_after_interceptor() -> Object:
	return StopAfterInterceptor.new()


func make_replace_with_injected_interceptor(replacement: Object) -> Object:
	return ReplaceWithInjectedInterceptor.new(replacement)


func make_observe_injected_replacement_interceptor() -> Object:
	return ObserveInjectedReplacementInterceptor.new()


func make_clear_queue_before_interceptor() -> Object:
	return ClearQueueBeforeInterceptor.new()


# --- 内部类 ---

class RewriteInterceptor:
	extends GFActionInterceptor

	var order_list: Array

	func _init(p_order_list: Array) -> void:
		order_list = p_order_list

	func _before_execute(action: Object, _queue: GFActionQueueSystem) -> GFActionInterceptionResult:
		var label: String = FixtureReads.read_label(action)
		if label.is_empty():
			return GFActionInterceptionResult.continue_action()
		order_list.append("before:%s" % label)
		if label == "SKIP":
			return GFActionInterceptionResult.skip_action()
		if label == "OLD":
			return GFActionInterceptionResult.replace_with(OrderActionReplacement.new(order_list, "NEW"))
		return GFActionInterceptionResult.continue_action()

	func _after_execute(action: Object, _queue: GFActionQueueSystem, _execute_result: Variant) -> GFActionInterceptionResult:
		var label: String = FixtureReads.read_label(action)
		if not label.is_empty():
			order_list.append("after:%s" % label)
		return GFActionInterceptionResult.continue_action()


class PriorityInterceptor:
	extends GFActionInterceptor

	var order_list: Array
	var label: String

	func _init(p_order_list: Array, p_label: String, p_priority: int) -> void:
		order_list = p_order_list
		label = p_label
		priority = p_priority

	func _before_execute(_action: Object, _queue: GFActionQueueSystem) -> GFActionInterceptionResult:
		order_list.append(label)
		return GFActionInterceptionResult.continue_action()


class StopAfterInterceptor:
	extends GFActionInterceptor

	func _after_execute(action: Object, _queue: GFActionQueueSystem, _execute_result: Variant) -> GFActionInterceptionResult:
		if FixtureReads.read_label(action) == "STOP":
			return GFActionInterceptionResult.stop_queue()
		return GFActionInterceptionResult.continue_action()


class ReplaceWithInjectedInterceptor:
	extends GFActionInterceptor

	var replacement: Object

	func _init(p_replacement: Object) -> void:
		replacement = p_replacement

	func _before_execute(_action: Object, _queue: GFActionQueueSystem) -> GFActionInterceptionResult:
		return GFActionInterceptionResult.replace_with(replacement)


class ObserveInjectedReplacementInterceptor:
	extends GFActionInterceptor

	var observed_architecture: GFArchitecture = null

	func _before_execute(action: Object, _queue: GFActionQueueSystem) -> GFActionInterceptionResult:
		observed_architecture = FixtureReads.read_architecture(action)
		return GFActionInterceptionResult.continue_action()


class ClearQueueBeforeInterceptor:
	extends GFActionInterceptor

	func _before_execute(_action: Object, queue: GFActionQueueSystem) -> GFActionInterceptionResult:
		queue.clear_queue(true)
		return GFActionInterceptionResult.continue_action()


class OrderActionReplacement:
	extends GFVisualAction

	var order_list: Array
	var label: String

	func _init(p_order_list: Array, p_label: String) -> void:
		order_list = p_order_list
		label = p_label

	func execute() -> Variant:
		order_list.append(label)
		return null


class FixtureReads:
	static func read_label(action: Object) -> String:
		if action == null or not ("label" in action):
			return ""
		var label_value: Variant = action.call(&"get", &"label")
		return GFVariantData.to_text(label_value)

	static func read_architecture(action: Object) -> GFArchitecture:
		if action == null or not ("injected_architecture" in action):
			return null
		var value: Variant = action.call(&"get", &"injected_architecture")
		if value is GFArchitecture:
			var architecture: GFArchitecture = value
			return architecture
		return null
