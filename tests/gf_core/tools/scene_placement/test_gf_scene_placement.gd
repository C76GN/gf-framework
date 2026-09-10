@tool

# 拾取协议的纯行为测试；原生编辑器插件与撤销历史另由真实编辑器 fixture 验证。
extends GutTest


# --- 常量 ---

const _ASSET_PATH: String = "res://tests/gf_core/tools/scene_placement/fixtures/placement_asset.tscn"
const _SCRIPTED_ASSET_PATH: String = "res://tests/gf_core/tools/scene_placement/fixtures/placement_scripted_asset.tscn"
const _CANARY_KEY: StringName = &"gf_placement_canary_instances"
const _UNDO_ADAPTER_SCRIPT = preload("res://tests/gf_core/tools/scene_placement/fixtures/placement_undo_adapter.gd")


# --- 私有变量 ---

var _scene_roots: Array[Node3D] = []
var _undo_adapters: Array[_UNDO_ADAPTER_SCRIPT] = []


# --- 公共方法 ---

func before_each() -> void:
	Engine.set_meta(_CANARY_KEY, 0)


func after_each() -> void:
	for adapter: _UNDO_ADAPTER_SCRIPT in _undo_adapters:
		adapter.clear()
	_undo_adapters.clear()
	for root: Node3D in _scene_roots:
		if is_instance_valid(root):
			root.free()
	_scene_roots.clear()
	Engine.remove_meta(_CANARY_KEY)


func test_plane_preview_uses_ray_and_does_not_mutate_scene() -> void:
	var parent: Node3D = _make_parent()
	var operation: GFScenePlacementOperation = _make_operation(parent)
	var children_before: int = parent.get_child_count()
	assert_eq(operation.pick(_ray(Vector3(3.0, 8.0, -4.0))), GFEditorPickOperation.State.READY)
	assert_true(operation.can_apply())
	var preview: Dictionary = operation.get_preview()
	assert_true(_bool_field(preview, "valid"))
	assert_almost_eq(_transform_field(preview, "world_transform").origin, Vector3(3.0, 0.0, -4.0), Vector3.ONE * 0.00001)
	assert_eq(parent.get_child_count(), children_before, "预览不得把源场景实例加入待编辑场景。")
	assert_true(_transform_field(preview, "local_transform").is_equal_approx(_transform_field(preview, "world_transform")))
	assert_eq(_canary_count(), 0)


func test_preview_does_not_instantiate_tool_scripted_asset() -> void:
	var parent: Node3D = _make_parent()
	var operation: GFScenePlacementOperation = _make_operation(parent, {}, _SCRIPTED_ASSET_PATH)
	assert_eq(operation.pick(_ray(Vector3(2.0, 4.0, 3.0))), GFEditorPickOperation.State.READY)
	assert_eq(_canary_count(), 0, "选择和预览必须通过纯数据工作，不得实例化来源 @tool 脚本。")
	assert_eq(parent.get_child_count(), 0)
	operation.cancel()
	assert_eq(_canary_count(), 0)
	assert_eq(parent.get_child_count(), 0)


func test_non_unit_parent_preserves_world_placement() -> void:
	var parent: Node3D = _make_parent()
	parent.transform = Transform3D(Basis(Vector3.UP, PI * 0.5).scaled(Vector3(2.0, 3.0, 4.0)), Vector3(5.0, 2.0, -3.0))
	var operation: GFScenePlacementOperation = _make_operation(parent)
	assert_eq(operation.pick(_ray(Vector3(3.0, 8.0, -4.0))), GFEditorPickOperation.State.READY)
	var preview: Dictionary = operation.get_preview()
	var world: Transform3D = _transform_field(preview, "world_transform")
	var local: Transform3D = _transform_field(preview, "local_transform")
	assert_true((parent.global_transform * local).is_equal_approx(world))
	assert_almost_eq(world.origin, Vector3(3.0, 0.0, -4.0), Vector3.ONE * 0.00001)
	assert_false(local.origin.is_equal_approx(world.origin), "不能把世界位置直接当作非单位父节点下的局部位置。")


func test_explicit_anchor_lands_on_hit_after_yaw_and_scale() -> void:
	var parent: Node3D = _make_parent()
	var anchor: Vector3 = Vector3(1.0, 0.5, -2.0)
	var operation: GFScenePlacementOperation = _make_operation(parent, {
		"anchor": anchor,
		"yaw_degrees": 90.0,
		"scale": Vector3(2.0, 3.0, 4.0),
	})
	assert_eq(operation.pick(_ray(Vector3(5.0, 10.0, 7.0))), GFEditorPickOperation.State.READY)
	var world: Transform3D = _transform_field(operation.get_preview(), "world_transform")
	assert_almost_eq(world * anchor, Vector3(5.0, 0.0, 7.0), Vector3.ONE * 0.00001)
	assert_almost_eq(world.basis.get_scale(), Vector3(2.0, 3.0, 4.0), Vector3.ONE * 0.00001)


func test_plane_origin_normal_and_parallel_miss_are_observable() -> void:
	var parent: Node3D = _make_parent()
	var operation: GFScenePlacementOperation = _make_operation(parent, {
		"plane_origin": Vector3(0.0, 2.0, 0.0),
		"plane_normal": Vector3.UP,
	})
	assert_eq(operation.pick(_ray(Vector3(3.0, 8.0, -4.0))), GFEditorPickOperation.State.READY)
	assert_almost_eq(_transform_field(operation.get_preview(), "world_transform").origin, Vector3(3.0, 2.0, -4.0), Vector3.ONE * 0.00001)
	assert_eq(operation.pick({ "ray_origin": Vector3.ZERO, "ray_direction": Vector3.RIGHT }), GFEditorPickOperation.State.PICKING)
	assert_false(operation.can_apply(), "上一次有效预览不得在当前射线无交点时继续应用。")
	assert_false(_bool_field(operation.get_preview(), "valid"))


func test_grid_snaps_plane_hit_without_instantiating_asset() -> void:
	var parent: Node3D = _make_parent()
	var operation: GFScenePlacementOperation = _make_operation(parent, { "grid_step": 2.0 })
	assert_eq(operation.pick(_ray(Vector3(2.6, 8.0, -3.4))), GFEditorPickOperation.State.READY)
	assert_almost_eq(_transform_field(operation.get_preview(), "world_transform").origin, Vector3(2.0, 0.0, -4.0), Vector3.ONE * 0.00001)
	assert_eq(parent.get_child_count(), 0)


func test_surface_hit_aligns_up_and_applies_normal_offset() -> void:
	var parent: Node3D = _make_parent()
	var operation: GFScenePlacementOperation = _make_operation(parent, {
		"mode": "surface",
		"align_normal": true,
		"surface_offset": 0.5,
	})
	var normal: Vector3 = Vector3(0.0, 1.0, 1.0).normalized()
	var point: Vector3 = Vector3(2.0, 3.0, 4.0)
	assert_eq(operation.pick({ "hit": { "position": point, "normal": normal } }), GFEditorPickOperation.State.READY)
	var world: Transform3D = _transform_field(operation.get_preview(), "world_transform")
	assert_almost_eq(world.origin, point + normal * 0.5, Vector3.ONE * 0.00001)
	assert_almost_eq(world.basis.y.normalized(), normal, Vector3.ONE * 0.00001)


func test_surface_without_hit_invalidates_previous_ready_preview() -> void:
	var parent: Node3D = _make_parent()
	var operation: GFScenePlacementOperation = _make_operation(parent, { "mode": "surface" })
	assert_eq(operation.pick({ "hit": { "position": Vector3.ONE, "normal": Vector3.UP } }), GFEditorPickOperation.State.READY)
	assert_eq(operation.pick({}), GFEditorPickOperation.State.PICKING)
	assert_false(operation.can_apply())
	assert_false(_bool_field(operation.get_preview(), "valid"))
	assert_false(_bool_field(operation.apply(), "ok"))
	assert_eq(parent.get_child_count(), 0)


func test_invalid_surface_vectors_cannot_leave_a_ready_candidate() -> void:
	var parent: Node3D = _make_parent()
	var operation: GFScenePlacementOperation = _make_operation(parent, { "mode": "surface" })
	var invalid_hits: Array[Dictionary] = [
		{ "position": Vector3(NAN, 0.0, 0.0), "normal": Vector3.UP },
		{ "position": Vector3.ZERO, "normal": Vector3.ZERO },
		{ "position": Vector3.ZERO, "normal": Vector3(INF, 0.0, 0.0) },
		{ "position": "0,0,0", "normal": Vector3.UP },
	]
	for hit: Dictionary in invalid_hits:
		assert_eq(operation.pick({ "hit": { "position": Vector3.ONE, "normal": Vector3.UP } }), GFEditorPickOperation.State.READY)
		assert_eq(operation.pick({ "hit": hit }), GFEditorPickOperation.State.PICKING)
		assert_false(operation.can_apply())
		assert_false(_bool_field(operation.get_preview(), "valid"))


func test_invalid_plane_rays_cannot_leave_a_ready_candidate() -> void:
	var parent: Node3D = _make_parent()
	var operation: GFScenePlacementOperation = _make_operation(parent)
	var invalid_rays: Array[Dictionary] = [
		{ "ray_origin": Vector3(NAN, 0.0, 0.0), "ray_direction": Vector3.DOWN },
		{ "ray_origin": Vector3.UP, "ray_direction": Vector3.ZERO },
		{ "ray_origin": Vector3.UP, "ray_direction": Vector3(INF, 0.0, 0.0) },
		{ "ray_origin": Vector3.UP, "ray_direction": "down" },
		{},
	]
	for ray: Dictionary in invalid_rays:
		assert_eq(operation.pick(_ray(Vector3(3.0, 8.0, -4.0))), GFEditorPickOperation.State.READY)
		assert_eq(operation.pick(ray), GFEditorPickOperation.State.PICKING)
		assert_false(operation.can_apply())


func test_cancel_is_terminal_for_pointer_and_apply() -> void:
	var parent: Node3D = _make_parent()
	var operation: GFScenePlacementOperation = _make_operation(parent)
	assert_eq(operation.pick(_ray(Vector3(1.0, 8.0, 2.0))), GFEditorPickOperation.State.READY)
	operation.cancel()
	operation.cancel()
	assert_eq(operation.get_state(), GFEditorPickOperation.State.CANCELLED)
	assert_false(operation.can_apply())
	assert_eq(operation.pick(_ray(Vector3(5.0, 8.0, 6.0))), GFEditorPickOperation.State.CANCELLED)
	assert_false(_bool_field(operation.apply(), "ok"))
	assert_eq(parent.get_child_count(), 0)


func test_apply_without_undo_manager_rejects_without_instantiation() -> void:
	var parent: Node3D = _make_parent()
	var operation: GFScenePlacementOperation = _make_operation(parent, {}, _SCRIPTED_ASSET_PATH)
	assert_eq(operation.pick(_ray(Vector3(1.0, 8.0, 2.0))), GFEditorPickOperation.State.READY)
	var report: Dictionary = operation.apply()
	assert_false(_bool_field(report, "ok"))
	assert_eq(_int_field(report, "error_code"), ERR_UNCONFIGURED)
	assert_eq(_canary_count(), 0, "缺少原生撤销上下文时必须先拒绝，不能先实例化再回滚。")
	assert_eq(parent.get_child_count(), 0)


func test_parent_leaving_tree_invalidates_ready_operation() -> void:
	var parent: Node3D = _make_parent()
	var operation: GFScenePlacementOperation = _make_operation(parent)
	assert_eq(operation.pick(_ray(Vector3(1.0, 8.0, 2.0))), GFEditorPickOperation.State.READY)
	var root: Node = parent.get_parent()
	root.remove_child(parent)
	assert_false(operation.can_apply())
	assert_false(_bool_field(operation.apply(), "ok"))
	assert_eq(parent.get_child_count(), 0)
	parent.free()


func test_incompatible_undo_manager_rejects_before_source_instantiation() -> void:
	var parent: Node3D = _make_parent()
	var manager: RefCounted = RefCounted.new()
	var operation: GFScenePlacementOperation = _make_operation(parent, {}, _SCRIPTED_ASSET_PATH, manager)
	assert_eq(operation.pick(_ray(Vector3(1.0, 8.0, 2.0))), GFEditorPickOperation.State.READY)
	var report: Dictionary = operation.apply()
	assert_false(_bool_field(report, "ok"))
	assert_ne(_int_field(report, "error_code"), OK)
	assert_eq(_canary_count(), 0, "不兼容的撤销管理器必须在实例化源场景前被拒绝。")
	assert_eq(parent.get_child_count(), 0)


func test_parent_becoming_singular_invalidates_ready_operation() -> void:
	var parent: Node3D = _make_parent()
	var operation: GFScenePlacementOperation = _make_operation(parent)
	assert_eq(operation.pick(_ray(Vector3(1.0, 8.0, 2.0))), GFEditorPickOperation.State.READY)
	parent.scale = Vector3(1.0, 0.0, 1.0)
	assert_false(operation.can_apply())
	assert_false(_bool_field(operation.apply(), "ok"))
	assert_eq(parent.get_child_count(), 0)


func test_preview_and_result_are_defensive_value_copies() -> void:
	var parent: Node3D = _make_parent()
	var operation: GFScenePlacementOperation = _make_operation(parent)
	assert_eq(operation.pick(_ray(Vector3(3.0, 8.0, -4.0))), GFEditorPickOperation.State.READY)
	var preview: Dictionary = operation.get_preview()
	preview["world_transform"] = Transform3D(Basis.IDENTITY, Vector3(900.0, 900.0, 900.0))
	preview["valid"] = false
	var result: Dictionary = operation.get_result()
	result.clear()
	assert_true(operation.can_apply())
	assert_true(_bool_field(operation.get_preview(), "valid"))
	assert_almost_eq(_transform_field(operation.get_preview(), "world_transform").origin, Vector3(3.0, 0.0, -4.0), Vector3.ONE * 0.00001)
	assert_false(operation.get_result().is_empty())


func test_configuration_rejects_unknown_types_and_non_finite_values() -> void:
	var parent: Node3D = _make_parent()
	var invalid_options: Array[Dictionary] = [
		{ "mode": "guess" },
		{ "unknown_option": true },
		{ "grid_step": "1" },
		{ "grid_step": -1.0 },
		{ "grid_step": NAN },
		{ "align_normal": 1 },
		{ "plane_normal": Vector3.ZERO },
		{ "plane_origin": Vector3(INF, 0.0, 0.0) },
		{ "anchor": Vector3(0.0, NAN, 0.0) },
		{ "yaw_degrees": INF },
		{ "scale": Vector3(1.0, 0.0, 1.0) },
		{ "surface_offset": NAN },
		{ "max_distance": 0.0 },
		{ "max_distance": 100001.0 },
		{ "anchor": Vector3(1000001.0, 0.0, 0.0) },
	]
	var scene: PackedScene = _load_scene(_ASSET_PATH)
	for options: Dictionary in invalid_options:
		var operation: GFScenePlacementOperation = GFScenePlacementOperation.new()
		assert_ne(operation.configure(scene, parent, parent.get_parent(), options), OK)
		assert_false(operation.can_apply())
	assert_eq(parent.get_child_count(), 0)


func test_configuration_rejects_missing_scene_and_foreign_parent() -> void:
	var parent: Node3D = _make_parent()
	var other_parent: Node3D = _make_parent()
	var operation: GFScenePlacementOperation = GFScenePlacementOperation.new()
	assert_ne(operation.configure(null, parent, parent.get_parent()), OK)
	assert_ne(operation.configure(_load_scene(_ASSET_PATH), parent, other_parent.get_parent()), OK)
	assert_false(operation.can_apply())


func test_plane_rejects_hit_beyond_explicit_distance_budget() -> void:
	var parent: Node3D = _make_parent()
	var operation: GFScenePlacementOperation = _make_operation(parent, { "max_distance": 10.0 })
	assert_eq(operation.pick(_ray(Vector3(2.0, 9.0, 3.0))), GFEditorPickOperation.State.READY)
	assert_eq(operation.pick(_ray(Vector3(2.0, 11.0, 3.0))), GFEditorPickOperation.State.PICKING)
	assert_false(operation.can_apply())
	assert_false(_bool_field(operation.get_preview(), "valid"))


func test_source_root_basis_is_preserved_without_instantiating_for_preview() -> void:
	var source_root: Node3D = Node3D.new()
	var source_basis: Basis = Basis(Vector3.UP, 0.3).scaled(Vector3(2.0, 1.0, 3.0))
	source_root.transform = Transform3D(source_basis, Vector3(50.0, 20.0, 30.0))
	var scene: PackedScene = PackedScene.new()
	assert_eq(scene.pack(source_root), OK)
	source_root.free()
	var parent: Node3D = _make_parent()
	var operation: GFScenePlacementOperation = GFScenePlacementOperation.new()
	assert_eq(operation.configure(scene, parent, parent.get_parent()), OK)
	var context: GFEditorToolContext = GFEditorToolContext.new()
	context.edited_scene_root = parent.get_parent()
	assert_true(operation.begin(context))
	assert_eq(operation.pick(_ray(Vector3(3.0, 8.0, -4.0))), GFEditorPickOperation.State.READY)
	var world: Transform3D = _transform_field(operation.get_preview(), "world_transform")
	assert_true(world.basis.is_equal_approx(source_basis))
	assert_almost_eq(world.origin, Vector3(3.0, 0.0, -4.0), Vector3.ONE * 0.00001)


func test_configuration_rejects_a_non_3d_scene_root() -> void:
	var source_root: Control = Control.new()
	var scene: PackedScene = PackedScene.new()
	assert_eq(scene.pack(source_root), OK)
	source_root.free()
	var parent: Node3D = _make_parent()
	var operation: GFScenePlacementOperation = GFScenePlacementOperation.new()
	assert_ne(operation.configure(scene, parent, parent.get_parent()), OK)
	assert_false(operation.can_apply())


func test_confirm_then_undo_redo_reuses_instance_and_owner() -> void:
	var parent: Node3D = _make_parent()
	var adapter: _UNDO_ADAPTER_SCRIPT = _make_undo_adapter()
	var operation: GFScenePlacementOperation = _make_operation(parent, {}, _SCRIPTED_ASSET_PATH, adapter)
	assert_eq(operation.pick(_ray(Vector3(2.0, 8.0, -3.0))), GFEditorPickOperation.State.READY)
	assert_eq(_canary_count(), 0)
	var report: Dictionary = operation.apply()
	assert_true(_bool_field(report, "ok"))
	var placed: Node3D = _node_field(report, "node")
	if placed == null:
		return
	var instance_id: int = placed.get_instance_id()
	assert_eq(operation.get_state(), GFEditorPickOperation.State.APPLIED)
	assert_eq(placed.get_parent(), parent)
	assert_eq(placed.owner, parent.get_parent())
	assert_eq(_canary_count(), 1)
	assert_true(adapter.undo())
	assert_null(placed.get_parent())
	assert_eq(parent.get_child_count(), 0)
	assert_true(adapter.redo())
	assert_eq(placed.get_instance_id(), instance_id)
	assert_eq(placed.owner, parent.get_parent())
	assert_eq(parent.get_child_count(), 1)
	assert_eq(_canary_count(), 1, "重做应复用已经创建的场景实例，不应再次运行 _init。")
	assert_almost_eq(placed.global_position, Vector3(2.0, 0.0, -3.0), Vector3.ONE * 0.00001)


func test_confirmation_recomputes_local_transform_after_parent_moves() -> void:
	var parent: Node3D = _make_parent()
	var adapter: _UNDO_ADAPTER_SCRIPT = _make_undo_adapter()
	var operation: GFScenePlacementOperation = _make_operation(parent, {}, _ASSET_PATH, adapter)
	assert_eq(operation.pick(_ray(Vector3(3.0, 8.0, -4.0))), GFEditorPickOperation.State.READY)
	var expected: Transform3D = _transform_field(operation.get_preview(), "world_transform")
	parent.transform = Transform3D(Basis(Vector3.UP, PI * 0.5).scaled(Vector3(2.0, 3.0, 4.0)), Vector3(5.0, 2.0, -3.0))
	var report: Dictionary = operation.apply()
	assert_true(_bool_field(report, "ok"))
	var placed: Node3D = _node_field(report, "node")
	if placed != null:
		assert_true(placed.global_transform.is_equal_approx(expected))
		assert_true((parent.global_transform * placed.transform).is_equal_approx(expected))


func test_synchronous_child_callback_cannot_apply_the_same_operation_twice() -> void:
	var parent: Node3D = _make_parent()
	var adapter: _UNDO_ADAPTER_SCRIPT = _make_undo_adapter()
	var operation: GFScenePlacementOperation = _make_operation(parent, {}, _SCRIPTED_ASSET_PATH, adapter)
	assert_eq(operation.pick(_ray(Vector3(3.0, 8.0, -4.0))), GFEditorPickOperation.State.READY)
	var reentered: Array[bool] = [false]
	var nested_reports: Array[Dictionary] = []
	var apply_again: Callable = func(_child: Node) -> void:
		if reentered[0]:
			return
		reentered[0] = true
		nested_reports.append(operation.apply())
	var connect_error: int = parent.child_entered_tree.connect(apply_again)
	assert_eq(connect_error, OK)
	var report: Dictionary = operation.apply()
	parent.child_entered_tree.disconnect(apply_again)
	assert_true(_bool_field(report, "ok"), "外层首次确认必须成功。")
	assert_eq(nested_reports.size(), 1, "必须真实进入同步 child_entered_tree 回调。")
	if nested_reports.size() == 1:
		assert_false(_bool_field(nested_reports[0], "ok"), "同一确认的同步重入必须拒绝。")
	assert_eq(_canary_count(), 1, "重入不能再次实例化来源脚本。")
	assert_eq(parent.get_child_count(), 1, "一次确认只能创建一个实例。")
	assert_true(adapter.undo())
	assert_eq(parent.get_child_count(), 0)
	assert_false(adapter.undo(), "重入不能留下第二个历史动作。")
	assert_true(adapter.redo())
	assert_eq(parent.get_child_count(), 1)


func test_old_scene_history_does_not_remove_a_parent_moved_to_another_scene() -> void:
	var parent: Node3D = _make_parent()
	var adapter: _UNDO_ADAPTER_SCRIPT = _make_undo_adapter()
	var operation: GFScenePlacementOperation = _make_operation(parent, {}, _ASSET_PATH, adapter)
	assert_eq(operation.pick(_ray(Vector3(3.0, 8.0, -4.0))), GFEditorPickOperation.State.READY)
	var report: Dictionary = operation.apply()
	assert_true(_bool_field(report, "ok"))
	var placed: Node3D = _node_field(report, "node")
	if placed == null:
		return
	var other_parent: Node3D = _make_parent()
	parent.reparent(other_parent)
	var moved_world: Transform3D = placed.global_transform
	var placed_id: int = placed.get_instance_id()
	var _undo_advanced: bool = adapter.undo()
	assert_eq(placed.get_parent(), parent, "A 的旧历史不能从场景 B 移除实例。")
	assert_eq(parent.get_parent(), other_parent)
	assert_eq(parent.get_child_count(), 1)
	var _redo_advanced: bool = adapter.redo()
	assert_eq(placed.get_parent(), parent, "失效历史的 redo 同样不能改写 B。")
	assert_eq(placed.get_instance_id(), placed_id)
	if placed.is_inside_tree():
		assert_true(placed.global_transform.is_equal_approx(moved_world))


func test_cancel_during_confirmation_cannot_restart_before_compensation_finishes() -> void:
	var parent: Node3D = _make_parent()
	var adapter: _UNDO_ADAPTER_SCRIPT = _make_undo_adapter()
	var operation: GFScenePlacementOperation = _make_operation(parent, {}, _ASSET_PATH, adapter)
	assert_eq(operation.pick(_ray(Vector3(3.0, 8.0, -4.0))), GFEditorPickOperation.State.READY)
	var source: PackedScene = _load_scene(_ASSET_PATH)
	var context: GFEditorToolContext = GFEditorToolContext.new()
	context.edited_scene_root = parent.get_parent()
	context.undo_manager = adapter
	var observed: Dictionary = {}
	var cancel_and_restart: Callable = func(_child: Node) -> void:
		operation.cancel()
		observed["configure_error"] = operation.configure(source, parent, parent.get_parent())
		observed["begin_ok"] = operation.begin(context)
		observed["pick_state"] = operation.pick(_ray(Vector3(99.0, 8.0, 42.0)))
	var connect_error: int = parent.child_entered_tree.connect(cancel_and_restart)
	assert_eq(connect_error, OK)
	var report: Dictionary = operation.apply()
	parent.child_entered_tree.disconnect(cancel_and_restart)
	assert_false(_bool_field(report, "ok"), "同步取消必须撤回尚未提交的实例。")
	assert_eq(_int_field(observed, "configure_error"), ERR_BUSY)
	assert_false(_bool_field(observed, "begin_ok"))
	assert_eq(_int_field(observed, "pick_state"), GFEditorPickOperation.State.CANCELLED)
	assert_eq(operation.get_state(), GFEditorPickOperation.State.CANCELLED)
	assert_eq(parent.get_child_count(), 0)
	assert_false(adapter.undo(), "被同步取消的确认不能进入历史。")
	assert_eq(operation.configure(source, parent, parent.get_parent()), OK, "外层确认返回后才允许新操作。")
	assert_true(operation.begin(context))


func test_synchronous_parent_transform_change_preserves_confirmed_world_transform() -> void:
	var parent: Node3D = _make_parent()
	parent.transform = Transform3D(Basis(Vector3.UP, PI * 0.25).scaled(Vector3(2.0, 3.0, 4.0)), Vector3(1.0, 2.0, 3.0))
	var adapter: _UNDO_ADAPTER_SCRIPT = _make_undo_adapter()
	var operation: GFScenePlacementOperation = _make_operation(parent, {}, _ASSET_PATH, adapter)
	assert_eq(operation.pick(_ray(Vector3(3.0, 8.0, -4.0))), GFEditorPickOperation.State.READY)
	var expected: Transform3D = _transform_field(operation.get_preview(), "world_transform")
	var move_parent: Callable = func(_child: Node) -> void:
		parent.transform = Transform3D(Basis(Vector3.UP, -PI * 0.5).scaled(Vector3(5.0, 2.0, 3.0)), Vector3(-8.0, 7.0, 6.0))
	var connect_error: int = parent.child_entered_tree.connect(move_parent)
	assert_eq(connect_error, OK)
	var report: Dictionary = operation.apply()
	parent.child_entered_tree.disconnect(move_parent)
	assert_true(_bool_field(report, "ok"))
	var placed: Node3D = _node_field(report, "node")
	if placed == null:
		return
	assert_true(placed.global_transform.is_equal_approx(expected), "入树回调改变父变换后仍须落在确认的世界变换。")
	assert_true(adapter.undo())
	assert_eq(parent.get_child_count(), 0)
	assert_true(adapter.redo())
	assert_true(placed.global_transform.is_equal_approx(expected))
	assert_eq(placed.owner, parent.get_parent())


func test_undo_within_original_scene_does_not_require_an_invertible_parent_transform() -> void:
	var parent: Node3D = _make_parent()
	var adapter: _UNDO_ADAPTER_SCRIPT = _make_undo_adapter()
	var operation: GFScenePlacementOperation = _make_operation(parent, {}, _ASSET_PATH, adapter)
	assert_eq(operation.pick(_ray(Vector3(3.0, 8.0, -4.0))), GFEditorPickOperation.State.READY)
	var report: Dictionary = operation.apply()
	assert_true(_bool_field(report, "ok"))
	var placed: Node3D = _node_field(report, "node")
	if placed == null:
		return
	parent.transform = Transform3D(Basis.from_scale(Vector3.ZERO), Vector3.ZERO)
	assert_true(adapter.undo())
	assert_eq(parent.get_child_count(), 0, "原场景内的 undo 只需移除实例，不计算父变换逆矩阵。")
	assert_null(placed.get_parent())


func test_releasing_operation_preserves_history_without_holding_it_alive() -> void:
	var parent: Node3D = _make_parent()
	var adapter: _UNDO_ADAPTER_SCRIPT = _make_undo_adapter()
	var operation: GFScenePlacementOperation = _make_operation(parent, {}, _ASSET_PATH, adapter)
	assert_eq(operation.pick(_ray(Vector3(3.0, 8.0, -4.0))), GFEditorPickOperation.State.READY)
	var report: Dictionary = operation.apply()
	assert_true(_bool_field(report, "ok"))
	var placed: Node3D = _node_field(report, "node")
	var operation_ref: WeakRef = weakref(operation)
	operation = null
	var operation_released: bool = operation_ref.get_ref() == null
	assert_true(operation_released, "历史不能持有拾取操作及其 UI 上下文。")
	assert_true(adapter.undo())
	assert_eq(parent.get_child_count(), 0)
	assert_true(adapter.redo())
	if placed != null:
		assert_eq(placed.get_parent(), parent)
		assert_almost_eq(placed.global_position, Vector3(3.0, 0.0, -4.0), Vector3.ONE * 0.00001)


func test_dropping_undone_history_releases_detached_instance() -> void:
	var parent: Node3D = _make_parent()
	var adapter: _UNDO_ADAPTER_SCRIPT = _make_undo_adapter()
	var operation: GFScenePlacementOperation = _make_operation(parent, {}, _ASSET_PATH, adapter)
	assert_eq(operation.pick(_ray(Vector3(3.0, 8.0, -4.0))), GFEditorPickOperation.State.READY)
	var report: Dictionary = operation.apply()
	assert_true(_bool_field(report, "ok"))
	var placed: Node3D = _node_field(report, "node")
	if placed == null:
		return
	var placed_ref: WeakRef = weakref(placed)
	assert_true(adapter.undo())
	operation = null
	adapter.clear()
	var instance_released: bool = placed_ref.get_ref() == null
	assert_true(instance_released, "清除已撤销动作后，历史创建的脱树实例必须被销毁。")
	assert_eq(parent.get_child_count(), 0)


# --- 私有/辅助方法 ---

func _make_parent() -> Node3D:
	var root: Node3D = Node3D.new()
	root.name = "PlacementRoot"
	add_child(root)
	_scene_roots.append(root)
	var parent: Node3D = Node3D.new()
	parent.name = "PlacementParent"
	root.add_child(parent)
	parent.owner = root
	return parent


func _make_operation(parent: Node3D, options: Dictionary = {}, path: String = _ASSET_PATH, manager: Object = null) -> GFScenePlacementOperation:
	var operation: GFScenePlacementOperation = GFScenePlacementOperation.new()
	var scene: PackedScene = _load_scene(path)
	assert_eq(operation.configure(scene, parent, parent.get_parent(), options), OK)
	var context: GFEditorToolContext = GFEditorToolContext.new()
	context.edited_scene_root = parent.get_parent()
	context.undo_manager = manager
	assert_true(operation.begin(context))
	return operation


func _make_undo_adapter() -> _UNDO_ADAPTER_SCRIPT:
	var adapter: _UNDO_ADAPTER_SCRIPT = _UNDO_ADAPTER_SCRIPT.new()
	_undo_adapters.append(adapter)
	return adapter


func _load_scene(path: String) -> PackedScene:
	var loaded: Resource = ResourceLoader.load(path, "PackedScene", ResourceLoader.CACHE_MODE_IGNORE_DEEP)
	assert_true(loaded is PackedScene)
	if loaded is PackedScene:
		var scene: PackedScene = loaded
		return scene
	return null


func _ray(origin: Vector3) -> Dictionary:
	return { "ray_origin": origin, "ray_direction": Vector3.DOWN }


func _transform_field(report: Dictionary, key: String) -> Transform3D:
	var value: Variant = report.get(key)
	assert_true(value is Transform3D, "报告字段 %s 必须保持 Transform3D 类型。" % key)
	if value is Transform3D:
		var transform_value: Transform3D = value
		return transform_value
	return Transform3D.IDENTITY


func _bool_field(report: Dictionary, key: String) -> bool:
	var value: Variant = report.get(key)
	assert_true(value is bool, "报告字段 %s 必须保持 bool 类型。" % key)
	if value is bool:
		var boolean: bool = value
		return boolean
	return false


func _int_field(report: Dictionary, key: String) -> int:
	var value: Variant = report.get(key)
	assert_true(value is int, "报告字段 %s 必须保持 int 类型。" % key)
	if value is int:
		var integer: int = value
		return integer
	return -1


func _node_field(report: Dictionary, key: String) -> Node3D:
	var value: Variant = report.get(key)
	assert_true(value is Node3D, "报告字段 %s 必须保持 Node3D 类型。" % key)
	if value is Node3D:
		var node: Node3D = value
		return node
	return null


func _canary_count() -> int:
	var value: Variant = Engine.get_meta(_CANARY_KEY, 0)
	assert_true(value is int)
	if value is int:
		var count: int = value
		return count
	return -1
