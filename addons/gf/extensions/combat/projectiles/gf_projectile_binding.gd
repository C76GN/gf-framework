## GFProjectileBinding: definition 与完整场景实例之间的拓扑快照。
## 直接 `new()` 得到封闭的 unconfigured invalid value，其原因为 `INTERNAL_FAILURE`；
## 只有 typed definition 的 `bind_instance()` 才能构造有效 topology。
## [br]
## @api public
## [br]
## @category value_object
## [br]
## @since unreleased
class_name GFProjectileBinding
extends RefCounted


# --- 枚举 ---

## 定义 binding 拒绝或失效的封闭原因。
## [br]
## @api public
## [br]
## @since unreleased
enum FailureReason {
	## Topology 完整有效。
	NONE = 0,
	## Definition 缺少可用 scene 或声明无效。
	INVALID_DEFINITION = 1,
	## 实例 root 为 null 或已失效。
	INVALID_ROOT = 2,
	## Root 类型与 definition 维度不一致。
	ROOT_DIMENSION_MISMATCH = 3,
	## Root 尚未进入 SceneTree。
	ROOT_NOT_IN_TREE = 4,
	## Definition 未声明 runtime path。
	MISSING_RUNTIME_PATH = 5,
	## 实例树内没有对应维度 runtime。
	MISSING_RUNTIME = 6,
	## 实例树内存在多个对应维度 runtime。
	AMBIGUOUS_RUNTIME = 7,
	## 显式 runtime path 未指向唯一 runtime。
	RUNTIME_PATH_MISMATCH = 8,
	## Runtime path 解析到实例 root 之外。
	RUNTIME_OUTSIDE_ROOT = 9,
	## Runtime 节点维度错误。
	RUNTIME_DIMENSION_MISMATCH = 10,
	## Runtime 已有 ACTIVE session 或 launch claim。
	RUNTIME_BUSY = 11,
	## Definition 未配置 motion。
	MISSING_MOTION = 12,
	## Typed definition 未配置 body adapter。
	MISSING_BODY_ADAPTER = 13,
	## Body adapter 不支持该 root。
	UNSUPPORTED_MOTION_BODY = 14,
	## Impact source 路径或节点类型无效。
	INVALID_IMPACT_SOURCE = 15,
	## 显式 impact source 路径不存在。
	MISSING_IMPACT_SOURCE = 16,
	## Impact source 路径重复。
	DUPLICATE_IMPACT_SOURCE = 17,
	## Impact source 位于实例 root 之外。
	IMPACT_SOURCE_OUTSIDE_ROOT = 18,
	## Impact source 与 definition 维度不一致。
	IMPACT_SOURCE_DIMENSION_MISMATCH = 19,
	## Binding topology 已不再 current。
	STALE_BINDING = 20,
	## Motion 拒绝创建 per-session state。
	MOTION_STATE_CREATION_FAILED = 21,
	## Reservation 在消费前失效。
	RESERVATION_INVALIDATED = 22,
	## 公开默认构造但尚未由 typed definition 初始化的封闭 invalid 状态。
	INTERNAL_FAILURE = 23,
}


# --- 私有变量 ---

var _failure_reason: FailureReason = FailureReason.INTERNAL_FAILURE
var _definition: GFProjectileDefinition = null
var _root_ref: WeakRef = null
var _runtime_ref: WeakRef = null
var _impact_source_refs: Array[WeakRef] = []
var _body_adapter: Resource = null
var _scene_snapshot: PackedScene = null
var _runtime_path_snapshot: NodePath = NodePath("")
var _impact_source_paths_snapshot: Array[NodePath] = []
var _motion_snapshot: GFProjectileMotion = null
var _lifetime_snapshot: GFProjectileLifetimePolicy = null


# --- 公共方法 ---

## 返回 topology 是否已完整绑定。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return: binding 是否有效。
func is_valid() -> bool:
	return _failure_reason == FailureReason.NONE


## 返回首个绑定失败原因。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return: 有效 binding 返回 `NONE`；默认 `new()` 返回 `INTERNAL_FAILURE`；其余返回首个确定失败原因。
func get_failure_reason() -> FailureReason:
	return _failure_reason


## 返回创建本快照的 typed definition。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return: definition；准入前失败时可能为 null。
func get_definition() -> GFProjectileDefinition:
	return _definition


## 返回绑定的完整实例根节点。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return: live root；已释放时返回 null。
func get_instance_root() -> Node:
	return _node_from_ref(_root_ref)


## 返回唯一 runtime 节点。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return: live runtime；已释放时返回 null。
func get_runtime() -> Node:
	return _node_from_ref(_runtime_ref)


## 返回 definition 声明顺序的 live impact source 快照。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return: 当前仍存活的 impact source。
## [br]
## @schema return: Array[Node]，definition 声明顺序的同维 GFHitBox/GFHitScan 显式 union；调用方可修改返回数组。
func get_impact_sources() -> Array[Node]:
	var result: Array[Node] = []
	for source_ref: WeakRef in _impact_source_refs:
		var source: Node = _node_from_ref(source_ref)
		if source != null:
			result.append(source)
	return result


## 返回本次绑定冻结的 dimension-specific body adapter。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return: `GFProjectileBodyAdapter2D` 或 `GFProjectileBodyAdapter3D`。
func get_body_adapter() -> Resource:
	return _body_adapter


## 检查弱引用 topology 是否仍与实例树一致。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return: root、runtime 与所有 source 仍存活且位于同一实例树时返回 true。
func is_current() -> bool:
	if not is_valid():
		return false
	if not is_topology_current_for_framework():
		return false
	if not _declaration_is_current():
		_failure_reason = FailureReason.STALE_BINDING
		return false
	return true


# --- 框架内部方法 ---

## 检查 ACTIVE session 使用的冻结实例 topology，不重读 mutable definition 声明。
## [br]
## @api framework_internal
## [br]
## @since unreleased
## [br]
## @return: root、runtime 与全部 source identity 仍存活并保持同根时返回 true。
func is_topology_current_for_framework() -> bool:
	if (
		_failure_reason != FailureReason.NONE
		and _failure_reason != FailureReason.STALE_BINDING
	):
		return false
	var root: Node = get_instance_root()
	var runtime: Node = get_runtime()
	if (
		root == null
		or runtime == null
		or root.is_queued_for_deletion()
		or runtime.is_queued_for_deletion()
		or not root.is_inside_tree()
	):
		return false
	if runtime != root and not root.is_ancestor_of(runtime):
		return false
	if get_impact_sources().size() != _impact_source_refs.size():
		return false
	for source: Node in get_impact_sources():
		if source.is_queued_for_deletion():
			return false
		if source != root and not root.is_ancestor_of(source):
			return false
	return true


## 以 first-wins 语义冻结运行期准入失败。
## [br]
## @api framework_internal
## [br]
## @since unreleased
## [br]
## @param failure_reason: 非 NONE 的稳定失败原因。
## [br]
## @return: 本调用是否首次冻结失败。
func fail_for_framework(failure_reason: FailureReason) -> bool:
	if _failure_reason != FailureReason.NONE or failure_reason == FailureReason.NONE:
		return false
	_failure_reason = failure_reason
	return true

## 构造框架内部 binding 快照。
## [br]
## @api framework_internal
## [br]
## @since unreleased
## [br]
## @param failure_reason: 冻结的成功或首个失败原因。
## [br]
## @param definition: 通过准入时的 typed definition。
## [br]
## @param instance_root: 完整实例根节点。
## [br]
## @param runtime: definition 指向的唯一 runtime。
## [br]
## @param impact_sources: definition 声明顺序的显式 impact source。
## [br]
## @param body_adapter: dimension-specific body adapter。
## [br]
## @return: 初始化后的同一 binding。
## [br]
## @schema impact_sources: Array[Node]，仅包含同一实例树内的同维 GFHitBox/GFHitScan 显式 union。
func initialize_for_framework(
	failure_reason: FailureReason,
	definition: GFProjectileDefinition = null,
	instance_root: Node = null,
	runtime: Node = null,
	impact_sources: Array[Node] = [],
	body_adapter: Resource = null
) -> GFProjectileBinding:
	_failure_reason = failure_reason
	_definition = definition
	_root_ref = weakref(instance_root) if instance_root != null else null
	_runtime_ref = weakref(runtime) if runtime != null else null
	_impact_source_refs.clear()
	for source: Node in impact_sources:
		_impact_source_refs.append(weakref(source))
	_body_adapter = body_adapter
	_capture_declaration_snapshot()
	return self


# --- 私有/辅助方法 ---

func _node_from_ref(weak_reference: WeakRef) -> Node:
	if weak_reference == null:
		return null
	var value: Variant = weak_reference.get_ref()
	if value is Node:
		var node: Node = value
		if node.is_queued_for_deletion():
			return null
		return node
	return null


func _capture_declaration_snapshot() -> void:
	_scene_snapshot = null
	_runtime_path_snapshot = NodePath("")
	_impact_source_paths_snapshot.clear()
	_motion_snapshot = null
	_lifetime_snapshot = null
	if (
		_failure_reason != FailureReason.NONE
		or _definition == null
		or not is_instance_valid(_definition)
	):
		return
	_scene_snapshot = _definition.scene
	_runtime_path_snapshot = _definition.runtime_path
	_impact_source_paths_snapshot = _definition.impact_source_paths.duplicate()
	_motion_snapshot = _definition.motion
	_lifetime_snapshot = _definition.lifetime_policy


func _declaration_is_current() -> bool:
	if (
		_definition == null
		or not is_instance_valid(_definition)
		or _scene_snapshot == null
		or not is_instance_valid(_scene_snapshot)
		or _definition.scene != _scene_snapshot
		or _definition.runtime_path != _runtime_path_snapshot
		or _definition.impact_source_paths != _impact_source_paths_snapshot
		or _motion_snapshot == null
		or not is_instance_valid(_motion_snapshot)
		or _definition.motion != _motion_snapshot
		or _definition.lifetime_policy != _lifetime_snapshot
		or (_lifetime_snapshot != null and not is_instance_valid(_lifetime_snapshot))
		or _body_adapter == null
		or not is_instance_valid(_body_adapter)
	):
		return false
	if _definition is GFProjectileDefinition2D:
		var definition_2d: GFProjectileDefinition2D = _definition
		return definition_2d.body_adapter == _body_adapter
	if _definition is GFProjectileDefinition3D:
		var definition_3d: GFProjectileDefinition3D = _definition
		return definition_3d.body_adapter == _body_adapter
	return false
