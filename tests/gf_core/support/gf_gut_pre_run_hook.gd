# Captures the process-local orphan baseline used by the GF post-run gate.
extends GutHookScript


# --- 常量 ---

const ORPHAN_BASELINE_META_KEY: StringName = &"_gf_test_orphan_baseline"


# --- 可重写钩子 / 虚方法 ---

func run() -> void:
	if not gut is GutMain:
		return

	var gut_main: GutMain = gut
	gut_main.set_meta(ORPHAN_BASELINE_META_KEY, _capture_orphan_ids())


# --- 私有/辅助方法 ---

func _capture_orphan_ids() -> Dictionary:
	var orphan_ids: Dictionary = {}
	for orphan_id: int in Node.get_orphan_node_ids():
		orphan_ids[orphan_id] = true
	return orphan_ids
