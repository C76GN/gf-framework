## 测试 GFInstanceGuard 的失效实例安全解析。
extends GutTest


# --- 常量 ---

const GF_INSTANCE_GUARD = preload("res://addons/gf/kernel/core/gf_instance_guard.gd")


# --- 测试 ---

func test_get_live_object_returns_null_for_freed_variant() -> void:
	var object: Object = Object.new()
	var object_variant: Variant = object
	object.free()

	assert_null(
		GF_INSTANCE_GUARD._get_live_object(object_variant),
		"已释放 Object Variant 不应被转型返回。"
	)


func test_get_live_object_returns_null_for_non_object_variant() -> void:
	assert_null(
		GF_INSTANCE_GUARD._get_live_object(42),
		"非 Object Variant 不应被解析为 Object。"
	)


func test_get_live_node_from_ref_returns_null_after_free() -> void:
	var node: Node = Node.new()
	var node_ref: WeakRef = weakref(node)
	node.free()

	assert_null(
		GF_INSTANCE_GUARD._get_live_node_from_ref(node_ref),
		"已释放 Node 弱引用不应被转型返回。"
	)


func test_get_live_control_from_ref_requires_control_type() -> void:
	var node: Node = Node.new()
	var node_ref: WeakRef = weakref(node)
	var control: Control = Control.new()
	var control_ref: WeakRef = weakref(control)

	assert_null(
		GF_INSTANCE_GUARD._get_live_control_from_ref(node_ref),
		"非 Control 节点不应被解析为 Control。"
	)
	assert_eq(
		GF_INSTANCE_GUARD._get_live_control_from_ref(control_ref),
		control,
		"有效 Control 弱引用应解析为原控件。"
	)

	node.free()
	control.free()


func test_get_live_node_from_id_returns_node_only_while_alive() -> void:
	var node: Node = Node.new()
	var node_id: int = node.get_instance_id()

	assert_eq(
		GF_INSTANCE_GUARD._get_live_node_from_id(node_id),
		node,
		"有效实例 ID 应解析为原 Node。"
	)

	node.free()

	assert_null(
		GF_INSTANCE_GUARD._get_live_node_from_id(node_id),
		"释放后的实例 ID 不应解析为 Node。"
	)
