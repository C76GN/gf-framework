# Registers GUT error tracking before test discovery loads any test script.
extends "res://addons/gut/gui/GutRunner.gd"


# --- 常量 ---

const GF_GUT_LIFECYCLE_STATE_SCRIPT = preload(
	"res://tests/gf_core/support/gf_gut_lifecycle_state.gd"
)


# --- 公共方法 ---

func run_tests(show_gui: bool = true) -> void:
	var raw_tracker: Variant = error_tracker
	var tracker_registered: bool = false
	if raw_tracker is GutErrorTracker:
		var tracker: GutErrorTracker = raw_tracker
		GutErrorTracker.register_logger(tracker)
		tracker_registered = GutErrorTracker.registered_loggers.has(tracker)
	GF_GUT_LIFECYCLE_STATE_SCRIPT.enter_tracking_phase(tracker_registered)
	var _run_result: Variant = super.run_tests(show_gui)
