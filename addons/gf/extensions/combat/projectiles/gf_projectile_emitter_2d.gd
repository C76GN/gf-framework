## GFProjectileEmitter2D: 通用 2D 发射体生成节点。
##
## 负责按场景目录和生成点模式实例化发射体，并把本次发射上下文交给
## 发射体的 launch()。它不解释伤害、阵营、弹药、冷却或特效规则。
## [br]
## @api public
## [br]
## @category runtime_handle
## [br]
## @since 3.17.0
class_name GFProjectileEmitter2D
extends Node2D


# --- 信号 ---

## 发射体已生成。
## [br]
## @api public
## [br]
## @param projectile: 生成的发射体节点。
## [br]
## @param projectile_context: 本次发射上下文。
## [br]
## @schema projectile_context: Dictionary，本次发射上下文副本，包含默认上下文、调用方上下文和 spawn 信息。
signal projectile_emitted(projectile: Node, projectile_context: Dictionary)

## 发射失败时发出。
## [br]
## @api public
## [br]
## @param reason: 失败原因。
## [br]
## @param details: 失败细节。
## [br]
## @schema details: Dictionary，失败上下文，通常包含 projectile_id、spawn_index 等诊断字段。
signal projectile_emit_failed(reason: StringName, details: Dictionary)


# --- 常量 ---

const _GF_NODE_CONTEXT_SCRIPT = preload("res://addons/gf/kernel/core/gf_node_context.gd")


# --- 导出变量 ---

## 默认发射体场景。未使用目录或目录缺少 ID 时使用。
## [br]
## @api public
@export var projectile_scene: PackedScene = null

## 可选发射体目录。
## [br]
## @api public
@export var projectile_catalog: GFProjectileCatalog = null

## 默认目录 ID。
## [br]
## @api public
@export var default_projectile_id: StringName = &""

## 2D 发射点模式。为空时使用发射器自身全局变换。
## [br]
## @api public
@export var spawn_pattern: GFProjectileSpawnPattern2D = null

## 默认上下文。每次发射会深拷贝后再合并调用方上下文。
## [br]
## @api public
## [br]
## @schema default_context: Dictionary，默认发射上下文；每次发射会深拷贝后合并调用方上下文。
@export var default_context: Dictionary = {}

## 可选生成父节点路径。为空时优先使用发射器父节点。
## [br]
## @api public
@export_node_path("Node") var spawn_parent_path: NodePath = NodePath("")

## 是否在生成后调用发射体的 launch(context)。
## [br]
## @api public
@export var launch_after_spawn: bool = true

## 生成前是否关闭常见发射体的 auto_launch_on_ready，避免进入树时使用空上下文启动。
## [br]
## @api public
@export var disable_auto_launch_before_add: bool = true

## 是否使用 GFObjectPoolUtility 获取节点。池化场景应把 projectile 的 auto_launch_on_ready 设为 false。
## [br]
## @api public
@export var use_object_pool: bool = false

## 使用对象池时，是否在 projectile_finished 后自动归还节点。
## [br]
## @api public
@export var release_pooled_projectile_on_finish: bool = true


# --- 公共变量 ---

## 可选对象池工具。为空时会从注入架构或最近的 GFNodeContext 查询。
## [br]
## @api public
var object_pool_utility: GFObjectPoolUtility = null


# --- 私有变量 ---

var _next_emission_token: int = 1
var _architecture_ref: WeakRef = null


# --- 公共方法 ---

## 注入当前发射器所属架构。
## [br]
## @api framework_internal
## [br]
## @param architecture: 当前架构。
func inject_dependencies(architecture: GFArchitecture) -> void:
	_architecture_ref = weakref(architecture) if architecture != null else null


## 发射单个发射体。
## [br]
## @api public
## [br]
## @param projectile_context: 本次发射上下文。
## [br]
## @param projectile_id: 可选目录 ID；为空时使用 default_projectile_id。
## [br]
## @return 生成的发射体节点；失败时返回 null。
## [br]
## @schema projectile_context: Dictionary，本次发射上下文；会与 default_context 合并后传给发射体。
func emit_projectile(projectile_context: Dictionary = {}, projectile_id: StringName = &"") -> Node:
	var projectiles: Array[Node] = emit_projectiles(projectile_context, projectile_id, 1)
	if projectiles.is_empty():
		return null
	return projectiles[0]


## 按当前模式发射一批发射体。
## [br]
## @api public
## [br]
## @param projectile_context: 本次发射上下文。
## [br]
## @param projectile_id: 可选目录 ID；为空时使用 default_projectile_id。
## [br]
## @param emit_count: 请求生成数量；小于等于 0 时由 spawn_pattern 决定。
## [br]
## @return 成功生成的发射体节点列表。
## [br]
## @schema projectile_context: Dictionary，本次发射上下文；会与 default_context 合并后传给每个发射体。
func emit_projectiles(
	projectile_context: Dictionary = {},
	projectile_id: StringName = &"",
	emit_count: int = -1
) -> Array[Node]:
	var effective_id: StringName = projectile_id if projectile_id != &"" else default_projectile_id
	var scene: PackedScene = resolve_projectile_scene(effective_id)
	if scene == null:
		_emit_failure(&"missing_scene", { "projectile_id": effective_id })
		return []

	var parent: Node = resolve_spawn_parent()
	if parent == null:
		_emit_failure(&"missing_parent", { "projectile_id": effective_id })
		return []

	var transforms: Array[Transform2D] = _get_spawn_transforms(projectile_context, emit_count)
	if transforms.is_empty():
		_emit_failure(&"empty_spawn_pattern", { "projectile_id": effective_id })
		return []

	var result: Array[Node] = []
	for index: int in range(transforms.size()):
		var spawn_transform: Transform2D = transforms[index]
		var projectile: Node = _create_projectile_node(scene, parent)
		if projectile == null:
			_emit_failure(&"instantiate_failed", {
				"projectile_id": effective_id,
				"spawn_index": index,
			})
			continue

		_apply_spawn_transform(projectile, spawn_transform)
		var context: Dictionary = _build_spawn_context(projectile_context, effective_id, spawn_transform, index, transforms.size())
		_prepare_projectile_runtime(projectile, scene)
		if launch_after_spawn and projectile.has_method(&"launch"):
			var _launch_result: Variant = projectile.call(&"launch", context)
		projectile_emitted.emit(projectile, context.duplicate(true))
		result.append(projectile)
	return result


## 解析当前要使用的发射体场景。
## [br]
## @api public
## [br]
## @param projectile_id: 可选目录 ID。
## [br]
## @return 找到时返回 PackedScene，否则返回 null。
func resolve_projectile_scene(projectile_id: StringName = &"") -> PackedScene:
	if projectile_catalog != null and projectile_id != &"":
		var catalog_scene: PackedScene = projectile_catalog.get_scene(projectile_id)
		if catalog_scene != null:
			return catalog_scene
	return projectile_scene


## 解析发射体生成父节点。
## [br]
## @api public
## [br]
## @return 有效父节点；找不到时返回 null。
func resolve_spawn_parent() -> Node:
	if spawn_parent_path != NodePath(""):
		var configured_parent: Node = get_node_or_null(spawn_parent_path)
		if configured_parent != null:
			return configured_parent
	var parent: Node = get_parent()
	if parent != null:
		return parent
	return self if is_inside_tree() else null


## 预热对象池。
## [br]
## @api public
## [br]
## @param count: 预热数量。
## [br]
## @param projectile_id: 可选目录 ID。
## [br]
## @return 预热请求被接受时返回 true。
func prewarm_projectiles(count: int, projectile_id: StringName = &"") -> bool:
	if count <= 0:
		return false
	var pool: GFObjectPoolUtility = _get_object_pool()
	if pool == null:
		return false
	var scene: PackedScene = resolve_projectile_scene(projectile_id if projectile_id != &"" else default_projectile_id)
	var parent: Node = resolve_spawn_parent()
	if scene == null or parent == null:
		return false
	pool.prewarm(scene, parent, count)
	return true


# --- 私有/辅助方法 ---

func _get_spawn_transforms(projectile_context: Dictionary, emit_count: int) -> Array[Transform2D]:
	if spawn_pattern != null:
		return spawn_pattern.get_spawn_transforms(self, projectile_context, emit_count)
	return [global_transform]


func _create_projectile_node(scene: PackedScene, parent: Node) -> Node:
	if use_object_pool:
		var pool: GFObjectPoolUtility = _get_object_pool()
		if pool != null:
			return pool.acquire(scene, parent)

	var projectile: Node = _variant_to_node(scene.instantiate())
	if projectile == null:
		return null
	_disable_auto_launch_if_supported(projectile)
	parent.add_child(projectile)
	return projectile


func _prepare_projectile_runtime(projectile: Node, scene: PackedScene) -> void:
	_disable_auto_launch_if_supported(projectile)
	var emission_token: int = _next_emission_token
	_next_emission_token += 1
	projectile.set_meta(&"gf_emission_token", emission_token)
	if use_object_pool and "queue_free_on_finish" in projectile:
		projectile.set("queue_free_on_finish", false)
	if use_object_pool and release_pooled_projectile_on_finish and projectile.has_signal("projectile_finished"):
		var _connected: int = projectile.connect(
			"projectile_finished",
			_on_pooled_projectile_finished.bind(projectile, scene, emission_token),
			CONNECT_ONE_SHOT as Object.ConnectFlags
		)


func _disable_auto_launch_if_supported(projectile: Node) -> void:
	if disable_auto_launch_before_add and "auto_launch_on_ready" in projectile:
		projectile.set("auto_launch_on_ready", false)


func _apply_spawn_transform(projectile: Node, spawn_transform: Transform2D) -> void:
	if projectile is Node2D:
		var projectile_2d: Node2D = projectile
		projectile_2d.global_transform = spawn_transform
	elif "global_position" in projectile:
		projectile.set("global_position", spawn_transform.origin)
	elif "position" in projectile:
		projectile.set("position", spawn_transform.origin)


func _build_spawn_context(
	projectile_context: Dictionary,
	projectile_id: StringName,
	spawn_transform: Transform2D,
	spawn_index: int,
	spawn_count: int
) -> Dictionary:
	var context: Dictionary = default_context.duplicate(true)
	for key: Variant in projectile_context.keys():
		context[key] = projectile_context[key]
	context["projectile_id"] = projectile_id
	context["emitter"] = self
	context["spawn_index"] = spawn_index
	context["spawn_count"] = spawn_count
	context["spawn_transform_2d"] = spawn_transform
	return context


func _get_object_pool() -> GFObjectPoolUtility:
	if object_pool_utility != null and is_instance_valid(object_pool_utility):
		return object_pool_utility

	var architecture: GFArchitecture = _get_architecture_or_null()
	if architecture == null:
		return null
	return _variant_to_object_pool(architecture.get_utility(GFObjectPoolUtility))


func _get_architecture_or_null() -> GFArchitecture:
	if _architecture_ref != null:
		var architecture: GFArchitecture = _variant_to_architecture(_architecture_ref.get_ref())
		if architecture != null:
			return architecture
	return _find_context_architecture()


func _find_context_architecture() -> GFArchitecture:
	var current_node: Node = self
	while current_node != null:
		if current_node is _GF_NODE_CONTEXT_SCRIPT:
			var context: GFNodeContext = current_node
			var architecture: GFArchitecture = context.get_architecture()
			if architecture != null:
				return architecture
		current_node = current_node.get_parent()
	return null


func _emit_failure(reason: StringName, details: Dictionary) -> void:
	projectile_emit_failed.emit(reason, details)


func _variant_to_node(value: Variant) -> Node:
	if value is Node:
		var node: Node = value
		return node
	return null


func _variant_to_architecture(value: Variant) -> GFArchitecture:
	if value is GFArchitecture:
		var architecture: GFArchitecture = value
		return architecture
	return null


func _variant_to_object_pool(value: Variant) -> GFObjectPoolUtility:
	if value is GFObjectPoolUtility:
		var object_pool: GFObjectPoolUtility = value
		return object_pool
	return null


# --- 信号处理函数 ---

func _on_pooled_projectile_finished(
	_projectile_arg: Node,
	_reason: StringName,
	projectile: Node,
	scene: PackedScene,
	emission_token: int
) -> void:
	if not is_instance_valid(projectile):
		return
	if GFVariantData.to_int(projectile.get_meta(&"gf_emission_token", -1), -1) != emission_token:
		return
	var pool: GFObjectPoolUtility = _get_object_pool()
	if pool != null:
		pool.release(projectile, scene)
