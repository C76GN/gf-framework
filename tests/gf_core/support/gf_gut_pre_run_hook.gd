# Captures the process-local orphan baseline used by the GF lifecycle gate.
extends GutHookScript


# --- 常量 ---

const GF_GUT_LIFECYCLE_STATE_SCRIPT = preload(
	"res://tests/gf_core/support/gf_gut_lifecycle_state.gd"
)


# --- 可重写钩子 / 虚方法 ---

func run() -> void:
	GF_GUT_LIFECYCLE_STATE_SCRIPT.commit_orphan_baseline(
		_capture_orphan_ids()
	)


# --- 私有/辅助方法 ---

func _capture_orphan_ids() -> Dictionary:
	var orphan_ids: Dictionary = {}
	for orphan_id: int in Node.get_orphan_node_ids():
		orphan_ids[orphan_id] = true
	return orphan_ids
