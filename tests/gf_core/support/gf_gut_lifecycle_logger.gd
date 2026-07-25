# Captures push_warning calls outside GUT's tracked-test phase.
extends Logger


# --- 常量 ---

const GF_GUT_LIFECYCLE_STATE_SCRIPT = preload(
	"res://tests/gf_core/support/gf_gut_lifecycle_state.gd"
)


# --- Godot 回调方法 ---

func _log_error(
	source_function: String,
	file: String,
	line: int,
	code: String,
	_rationale: String,
	_editor_notify: bool,
	_error_type: int,
	_script_backtraces: Array[ScriptBacktrace]
) -> void:
	if source_function != "push_warning":
		return
	GF_GUT_LIFECYCLE_STATE_SCRIPT.record_raw_warning(code, file, line)
