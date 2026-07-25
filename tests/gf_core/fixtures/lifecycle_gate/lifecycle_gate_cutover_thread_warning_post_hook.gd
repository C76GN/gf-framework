extends "res://tests/gf_core/support/gf_gut_post_run_hook.gd"


const WARNING_CODE: String = "GF lifecycle cutover thread fixture warning"


func _collect_unhandled_warnings(gut_main: GutMain) -> Dictionary:
	var warning_thread: Thread = Thread.new()
	var start_error: Error = warning_thread.start(_emit_warning)
	if start_error != OK:
		push_error(
			"GF lifecycle cutover fixture could not start its warning thread: %s"
			% error_string(start_error)
		)
	else:
		var _thread_result: Variant = warning_thread.wait_to_finish()
	return super._collect_unhandled_warnings(gut_main)


func _emit_warning() -> void:
	push_warning(WARNING_CODE)
