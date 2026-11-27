@tool
extends GFUIMotionEffect

var events: Array[String] = []
var current: RecordedAction
var config: GFTweenActionConfig
var properties: Array[NodePath] = []


func written_properties() -> Array[NodePath]:
	return properties


func bind_target(target: Object, _inputs: Dictionary) -> GFUIMotionBinding:
	var binding: GFUIMotionBinding = GFUIMotionBinding.new()
	if config != null:
		binding.action = config.create_action(target)
		return binding
	current = RecordedAction.new()
	current.events = events
	binding.action = current
	return binding


class RecordedAction extends GFVisualAction:
	signal completed(value: String)
	var events: Array[String] = []


	func execute() -> Variant:
		events.append("start")
		return completed


	func pause() -> void:
		events.append("pause")


	func resume() -> void:
		events.append("resume")


	func finish() -> void:
		events.append("finish")


	func cancel() -> void:
		events.append("cancel")
