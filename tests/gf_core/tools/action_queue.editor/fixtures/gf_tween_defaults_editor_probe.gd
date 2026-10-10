@tool

# 独立真实 EditorPlugin probe，可连同两个纯资源 fixture 放入原始基线重现占位默认值。
extends EditorPlugin


const _DEFAULTS_PATH: String = "res://tests/gf_core/tools/action_queue.editor/fixtures/gf_tween_preview_omitted_defaults.tres"
const _ZERO_PATH: String = "res://tests/gf_core/tools/action_queue.editor/fixtures/gf_tween_preview_explicit_zero.tres"

var _stable_frames: int = 0
var _finished: bool = false


func _enter_tree() -> void:
	var _connected: int = get_tree().process_frame.connect(_on_process_frame)


func _exit_tree() -> void:
	if get_tree().process_frame.is_connected(_on_process_frame):
		get_tree().process_frame.disconnect(_on_process_frame)


func _on_process_frame() -> void:
	if _finished:
		return
	var filesystem: EditorFileSystem = EditorInterface.get_resource_filesystem()
	if filesystem.is_scanning() or filesystem.is_importing():
		_stable_frames = 0
		return
	_stable_frames += 1
	if _stable_frames < 5:
		return
	_finished = true
	var source: Resource = ResourceLoader.load(_DEFAULTS_PATH, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP)
	var zeros: Resource = ResourceLoader.load(_ZERO_PATH, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP)
	var error: String = _get_probe_error(source, zeros)
	if not error.is_empty():
		print("GF_TWEEN_DEFAULTS_EDITOR_PROBE_FAILED: " + error)
		get_tree().call_deferred(&"quit", 1)
		return
	print("GF_TWEEN_DEFAULTS_EDITOR_PROBE_OK")
	get_tree().call_deferred(&"quit", 0)


func _get_probe_error(source: Resource, zeros: Resource) -> String:
	if not Engine.is_editor_hint() or source == null or zeros == null:
		return "Real editor resources are required."
	var script_value: Variant = source.get_script()
	if not (script_value is Script):
		return "The omitted-default fixture has no native resource script."
	var script: Script = script_value
	if script.is_tool():
		return "The resource must retain its non-tool script boundary."
	if source.get(&"duration_scale") != 1.0:
		return "Omitted duration_scale read %s instead of 1.0." % source.get(&"duration_scale")
	var steps_value: Variant = source.get(&"steps")
	if not (steps_value is Array):
		return "The resource has no steps array."
	var steps: Array = steps_value
	if steps.size() != 1 or not (steps[0] is Resource):
		return "The fixture must contain one resource step."
	var step: Resource = steps[0]
	if step.get(&"duration") != 0.2 or step.get(&"delay") != 0.0:
		return "Omitted duration/delay read %s/%s instead of 0.2/0.0." % [step.get(&"duration"), step.get(&"delay")]
	if zeros.get(&"duration_scale") != 0.0:
		return "Explicit zero duration_scale changed."
	var zero_steps_value: Variant = zeros.get(&"steps")
	if not (zero_steps_value is Array):
		return "Explicit zero fixture has no steps."
	var zero_steps: Array = zero_steps_value
	if zero_steps.size() != 1 or not (zero_steps[0] is Resource):
		return "Explicit zero fixture must contain one resource step."
	var zero_step: Resource = zero_steps[0]
	if zero_step.get(&"duration") != 0.0:
		return "Explicit zero step duration changed."
	return ""
