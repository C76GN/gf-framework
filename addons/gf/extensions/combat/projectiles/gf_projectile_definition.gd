## GFProjectileDefinition: projectile 场景、runtime 与策略的 typed 定义基类。
## [br]
## @api public
## [br]
## @category resource_definition
## [br]
## @since unreleased
class_name GFProjectileDefinition
extends Resource


## 可实例化的完整 projectile scene。
## [br]
## @api public
## [br]
## @since unreleased
@export var scene: PackedScene = null

## scene root 到唯一 runtime 的显式路径。
## [br]
## @api public
## [br]
## @since unreleased
@export var runtime_path: NodePath = NodePath("ProjectileRuntime")

## scene root 到 0..N impact source 的显式有序路径。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @schema impact_source_paths: Array[NodePath]，不得重复、越过 root 或混用维度。
@export var impact_source_paths: Array[NodePath] = []

## 每个 session 使用的 motion 策略。
## [br]
## @api public
## [br]
## @since unreleased
@export var motion: GFProjectileMotion = null

## 可选生命周期策略；null 表示不自动结束。
## [br]
## @api public
## [br]
## @since unreleased
@export var lifetime_policy: GFProjectileLifetimePolicy = null


func _bind_instance(
	root: Node,
	dimension: GFProjectileSession.Dimension,
	body_adapter: Resource
) -> GFProjectileBinding:
	var binding: GFProjectileBinding = GFProjectileBinding2D.new()
	if dimension == GFProjectileSession.Dimension.THREE_D:
		binding = GFProjectileBinding3D.new()
	var scene_snapshot: PackedScene = scene
	var runtime_path_snapshot: NodePath = runtime_path
	var source_paths_snapshot: Array[NodePath] = impact_source_paths.duplicate()
	var motion_snapshot: GFProjectileMotion = motion
	var lifetime_snapshot: GFProjectileLifetimePolicy = lifetime_policy
	var adapter_snapshot: Resource = body_adapter
	if root == null or not is_instance_valid(root) or root.is_queued_for_deletion():
		return binding.initialize_for_framework(GFProjectileBinding.FailureReason.INVALID_ROOT)
	if not _root_matches_dimension(root, dimension):
		return binding.initialize_for_framework(GFProjectileBinding.FailureReason.ROOT_DIMENSION_MISMATCH)
	if not root.is_inside_tree():
		return binding.initialize_for_framework(GFProjectileBinding.FailureReason.ROOT_NOT_IN_TREE)
	if scene_snapshot == null or not is_instance_valid(scene_snapshot):
		return binding.initialize_for_framework(GFProjectileBinding.FailureReason.INVALID_DEFINITION)
	if runtime_path_snapshot == NodePath(""):
		return binding.initialize_for_framework(GFProjectileBinding.FailureReason.MISSING_RUNTIME_PATH)
	if motion_snapshot == null or not is_instance_valid(motion_snapshot):
		return binding.initialize_for_framework(GFProjectileBinding.FailureReason.MISSING_MOTION)
	if adapter_snapshot == null or not is_instance_valid(adapter_snapshot):
		return binding.initialize_for_framework(GFProjectileBinding.FailureReason.MISSING_BODY_ADAPTER)
	if lifetime_snapshot != null and not is_instance_valid(lifetime_snapshot):
		return binding.initialize_for_framework(GFProjectileBinding.FailureReason.INVALID_DEFINITION)
	var adapter_validation: Error = _validate_adapter(root, dimension, adapter_snapshot)
	if not is_instance_valid(root) or root.is_queued_for_deletion():
		return binding.initialize_for_framework(GFProjectileBinding.FailureReason.INVALID_ROOT)
	if not root.is_inside_tree():
		return binding.initialize_for_framework(GFProjectileBinding.FailureReason.ROOT_NOT_IN_TREE)
	if not _root_matches_dimension(root, dimension):
		return binding.initialize_for_framework(GFProjectileBinding.FailureReason.ROOT_DIMENSION_MISMATCH)
	if not is_instance_valid(adapter_snapshot):
		return binding.initialize_for_framework(GFProjectileBinding.FailureReason.MISSING_BODY_ADAPTER)
	if not _bind_fence_is_current(
		root,
		dimension,
		scene_snapshot,
		runtime_path_snapshot,
		source_paths_snapshot,
		motion_snapshot,
		lifetime_snapshot,
		adapter_snapshot
	):
		return binding.initialize_for_framework(GFProjectileBinding.FailureReason.INVALID_DEFINITION)
	if adapter_validation != OK:
		return binding.initialize_for_framework(GFProjectileBinding.FailureReason.UNSUPPORTED_MOTION_BODY)

	var resolved_runtime: Node = root.get_node_or_null(runtime_path_snapshot)
	if resolved_runtime != null and resolved_runtime != root and not root.is_ancestor_of(resolved_runtime):
		return binding.initialize_for_framework(GFProjectileBinding.FailureReason.RUNTIME_OUTSIDE_ROOT)
	if resolved_runtime != null and _runtime_has_opposite_dimension(resolved_runtime, dimension):
		return binding.initialize_for_framework(GFProjectileBinding.FailureReason.RUNTIME_DIMENSION_MISMATCH)
	var runtime_candidates: Array[Node] = []
	_collect_runtimes(root, dimension, runtime_candidates)
	if runtime_candidates.is_empty():
		return binding.initialize_for_framework(GFProjectileBinding.FailureReason.MISSING_RUNTIME)
	if runtime_candidates.size() > 1:
		return binding.initialize_for_framework(GFProjectileBinding.FailureReason.AMBIGUOUS_RUNTIME)
	var runtime: Node = runtime_candidates[0]
	if not is_instance_valid(runtime) or runtime.is_queued_for_deletion():
		return binding.initialize_for_framework(GFProjectileBinding.FailureReason.MISSING_RUNTIME)
	if resolved_runtime != runtime:
		return binding.initialize_for_framework(GFProjectileBinding.FailureReason.RUNTIME_PATH_MISMATCH)
	var runtime_claimed: bool = _runtime_is_claimed(runtime)
	if not is_instance_valid(root) or root.is_queued_for_deletion():
		return binding.initialize_for_framework(GFProjectileBinding.FailureReason.INVALID_ROOT)
	if not root.is_inside_tree():
		return binding.initialize_for_framework(GFProjectileBinding.FailureReason.ROOT_NOT_IN_TREE)
	if not is_instance_valid(runtime) or runtime.is_queued_for_deletion():
		return binding.initialize_for_framework(GFProjectileBinding.FailureReason.MISSING_RUNTIME)
	if runtime != root and not root.is_ancestor_of(runtime):
		return binding.initialize_for_framework(GFProjectileBinding.FailureReason.RUNTIME_OUTSIDE_ROOT)
	if not _bind_fence_is_current(
		root,
		dimension,
		scene_snapshot,
		runtime_path_snapshot,
		source_paths_snapshot,
		motion_snapshot,
		lifetime_snapshot,
		adapter_snapshot
	):
		return binding.initialize_for_framework(GFProjectileBinding.FailureReason.INVALID_DEFINITION)
	if runtime_claimed:
		return binding.initialize_for_framework(GFProjectileBinding.FailureReason.RUNTIME_BUSY)

	var impact_sources: Array[Node] = []
	var seen_paths: Dictionary = {}
	var seen_source_ids: Dictionary = {}
	for source_path: NodePath in source_paths_snapshot:
		if source_path == NodePath(""):
			return binding.initialize_for_framework(GFProjectileBinding.FailureReason.INVALID_IMPACT_SOURCE)
		var path_key: String = String(source_path)
		if seen_paths.has(path_key):
			return binding.initialize_for_framework(GFProjectileBinding.FailureReason.DUPLICATE_IMPACT_SOURCE)
		seen_paths[path_key] = true
		var source: Node = root.get_node_or_null(source_path)
		if source == null:
			return binding.initialize_for_framework(GFProjectileBinding.FailureReason.MISSING_IMPACT_SOURCE)
		if not is_instance_valid(source) or source.is_queued_for_deletion():
			return binding.initialize_for_framework(GFProjectileBinding.FailureReason.INVALID_IMPACT_SOURCE)
		var source_id: int = source.get_instance_id()
		if seen_source_ids.has(source_id):
			return binding.initialize_for_framework(GFProjectileBinding.FailureReason.DUPLICATE_IMPACT_SOURCE)
		seen_source_ids[source_id] = true
		if source != root and not root.is_ancestor_of(source):
			return binding.initialize_for_framework(GFProjectileBinding.FailureReason.IMPACT_SOURCE_OUTSIDE_ROOT)
		if _impact_has_opposite_dimension(source, dimension):
			return binding.initialize_for_framework(GFProjectileBinding.FailureReason.IMPACT_SOURCE_DIMENSION_MISMATCH)
		if not _impact_matches_dimension(source, dimension):
			return binding.initialize_for_framework(GFProjectileBinding.FailureReason.INVALID_IMPACT_SOURCE)
		impact_sources.append(source)
	return binding.initialize_for_framework(
		GFProjectileBinding.FailureReason.NONE,
		self,
		root,
		runtime,
		impact_sources,
		adapter_snapshot
	)


func _bind_fence_is_current(
	root: Node,
	dimension: GFProjectileSession.Dimension,
	scene_snapshot: PackedScene,
	runtime_path_snapshot: NodePath,
	source_paths_snapshot: Array[NodePath],
	motion_snapshot: GFProjectileMotion,
	lifetime_snapshot: GFProjectileLifetimePolicy,
	adapter_snapshot: Resource
) -> bool:
	if (
		root == null
		or not is_instance_valid(root)
		or root.is_queued_for_deletion()
		or not root.is_inside_tree()
		or not _root_matches_dimension(root, dimension)
		or scene != scene_snapshot
		or scene_snapshot == null
		or not is_instance_valid(scene_snapshot)
		or runtime_path != runtime_path_snapshot
		or impact_source_paths != source_paths_snapshot
		or motion != motion_snapshot
		or motion_snapshot == null
		or not is_instance_valid(motion_snapshot)
		or lifetime_policy != lifetime_snapshot
		or (lifetime_snapshot != null and not is_instance_valid(lifetime_snapshot))
		or adapter_snapshot == null
		or not is_instance_valid(adapter_snapshot)
	):
		return false
	if dimension == GFProjectileSession.Dimension.TWO_D and self is GFProjectileDefinition2D:
		var definition_2d: GFProjectileDefinition2D = self
		return definition_2d.body_adapter == adapter_snapshot
	if dimension == GFProjectileSession.Dimension.THREE_D and self is GFProjectileDefinition3D:
		var definition_3d: GFProjectileDefinition3D = self
		return definition_3d.body_adapter == adapter_snapshot
	return false


func _root_matches_dimension(root: Node, dimension: GFProjectileSession.Dimension) -> bool:
	return (
		(root is Node2D and dimension == GFProjectileSession.Dimension.TWO_D)
		or (root is Node3D and dimension == GFProjectileSession.Dimension.THREE_D)
	)


func _runtime_has_opposite_dimension(
	runtime: Node,
	dimension: GFProjectileSession.Dimension
) -> bool:
	return (
		(runtime is GFProjectile3D and dimension == GFProjectileSession.Dimension.TWO_D)
		or (runtime is GFProjectile2D and dimension == GFProjectileSession.Dimension.THREE_D)
	)


func _collect_runtimes(
	node: Node,
	dimension: GFProjectileSession.Dimension,
	result: Array[Node]
) -> void:
	for child: Node in node.get_children():
		if not is_instance_valid(child) or child.is_queued_for_deletion():
			continue
		if (
			(child is GFProjectile2D and dimension == GFProjectileSession.Dimension.TWO_D)
			or (child is GFProjectile3D and dimension == GFProjectileSession.Dimension.THREE_D)
		):
			result.append(child)
		_collect_runtimes(child, dimension, result)


func _impact_matches_dimension(
	source: Node,
	dimension: GFProjectileSession.Dimension
) -> bool:
	return (
		(source is GFHitBox2D and dimension == GFProjectileSession.Dimension.TWO_D)
		or (source is GFHitBox3D and dimension == GFProjectileSession.Dimension.THREE_D)
	)


func _impact_has_opposite_dimension(
	source: Node,
	dimension: GFProjectileSession.Dimension
) -> bool:
	return (
		(source is GFHitBox3D and dimension == GFProjectileSession.Dimension.TWO_D)
		or (source is GFHitBox2D and dimension == GFProjectileSession.Dimension.THREE_D)
	)


func _validate_adapter(
	root: Node,
	dimension: GFProjectileSession.Dimension,
	body_adapter: Resource
) -> Error:
	if dimension == GFProjectileSession.Dimension.TWO_D and body_adapter is GFProjectileBodyAdapter2D:
		var adapter_2d: GFProjectileBodyAdapter2D = body_adapter
		return adapter_2d.validate_root(root)
	if dimension == GFProjectileSession.Dimension.THREE_D and body_adapter is GFProjectileBodyAdapter3D:
		var adapter_3d: GFProjectileBodyAdapter3D = body_adapter
		return adapter_3d.validate_root(root)
	return ERR_INVALID_PARAMETER


func _runtime_is_claimed(runtime: Node) -> bool:
	if runtime is GFProjectile2D:
		var runtime_2d: GFProjectile2D = runtime
		if runtime_2d.is_active():
			return true
		if not is_instance_valid(runtime_2d):
			return true
		return runtime_2d.has_launch_claim_for_framework()
	if runtime is GFProjectile3D:
		var runtime_3d: GFProjectile3D = runtime
		if runtime_3d.is_active():
			return true
		if not is_instance_valid(runtime_3d):
			return true
		return runtime_3d.has_launch_claim_for_framework()
	return false
