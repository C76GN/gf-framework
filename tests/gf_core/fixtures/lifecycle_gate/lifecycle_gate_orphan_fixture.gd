extends GutTest


const ORPHAN_META_KEY: StringName = &"gf_lifecycle_gate_orphan_fixture"
const ORPHAN_NAME: StringName = &"GF lifecycle gate orphan fixture"


func test_creates_a_real_orphan_node() -> void:
	var orphan: Node = Node.new()
	orphan.name = ORPHAN_NAME
	Engine.set_meta(ORPHAN_META_KEY, orphan)

	assert_true(orphan.is_inside_tree() == false, "故障注入节点必须是真实 orphan。")
