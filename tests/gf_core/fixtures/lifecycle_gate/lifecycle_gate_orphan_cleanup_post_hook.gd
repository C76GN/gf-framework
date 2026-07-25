extends "res://tests/gf_core/support/gf_gut_post_run_hook.gd"


const ORPHAN_META_KEY: StringName = &"gf_lifecycle_gate_orphan_fixture"


func run() -> void:
	var _snapshot_result: Variant = await super.run()
	var orphan_value: Variant = Engine.get_meta(ORPHAN_META_KEY)
	if orphan_value is Node:
		var orphan: Node = orphan_value
		if is_instance_valid(orphan):
			orphan.free()
	Engine.remove_meta(ORPHAN_META_KEY)
