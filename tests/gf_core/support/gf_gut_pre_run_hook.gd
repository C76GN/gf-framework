# Captures the process-local orphan baseline used by the GF lifecycle gate.
extends GutHookScript


# --- 常量 ---

const GF_GUT_LIFECYCLE_STATE_SCRIPT = preload(
	"res://tests/gf_core/support/gf_gut_lifecycle_state.gd"
)
const EXIT_FAILURE: int = 1


# --- 可重写钩子 / 虚方法 ---

func run() -> void:
	GF_GUT_LIFECYCLE_STATE_SCRIPT.commit_orphan_baseline(
		_capture_orphan_ids()
	)
	if not GF_GUT_LIFECYCLE_STATE_SCRIPT.gut_observation_is_enabled():
		return
	if not gut is GutMain:
		GF_GUT_LIFECYCLE_STATE_SCRIPT.record_configuration_error(
			"gut_observation_gut_instance_unavailable"
		)
		set_exit_code(EXIT_FAILURE)
		return

	var gut_main: GutMain = gut
	var start_connection_error: Error = gut_main.start_script.connect(
		_on_gut_observation_script_started
	) as Error
	var end_connection_error: Error = gut_main.end_script.connect(
		_on_gut_observation_script_ended
	) as Error
	var connections_ready: bool = (
		GF_GUT_LIFECYCLE_STATE_SCRIPT.commit_gut_observation_timing_connections(
			start_connection_error == OK,
			end_connection_error == OK
		)
	)
	if not connections_ready:
		set_exit_code(EXIT_FAILURE)


# --- 私有/辅助方法 ---

func _capture_orphan_ids() -> Dictionary:
	var orphan_ids: Dictionary = {}
	for orphan_id: int in Node.get_orphan_node_ids():
		orphan_ids[orphan_id] = true
	return orphan_ids


# --- 信号处理函数 ---

func _on_gut_observation_script_started(test_script_value: Variant) -> void:
	GF_GUT_LIFECYCLE_STATE_SCRIPT.record_gut_observation_script_started(
		test_script_value
	)


func _on_gut_observation_script_ended() -> void:
	GF_GUT_LIFECYCLE_STATE_SCRIPT.record_gut_observation_script_ended()
