## GFHitBoxState2D: 2D 命中区域状态组。
##
## 统一启停子树内的 GFHitBox2D、GFHurtBox2D 与 Area2D，不处理伤害、阵营或技能规则。
## [br]
## @api public
## [br]
## @category runtime_handle
## [br]
## @since 3.17.0
class_name GFHitBoxState2D
extends Node2D


# --- 信号 ---

## 状态应用后发出。
## [br]
## @api public
## [br]
## @param active: 当前是否激活。
signal active_changed(active: bool)


# --- 常量 ---

const _GF_HIT_BOX_STATE_SUPPORT = preload("res://addons/gf/extensions/combat/hit_detection/gf_hit_box_state_support.gd")


# --- 导出变量 ---

## 当前状态是否激活。
## [br]
## @api public
## [br]
## @since 3.17.0
@export var active: bool:
	get:
		return _active
	set(value):
		_set_active(value)

## 是否在 _ready() 时应用当前状态。
## [br]
## @api public
@export var apply_on_ready: bool = true

## 是否递归管理子节点。
## [br]
## @api public
@export var recursive: bool = true

## 是否同步 GFHitBox2D/GFHurtBox2D 的 enabled 字段。
## [br]
## @api public
@export var manage_enabled: bool = true

## 是否同步 Area2D 的 monitoring 与 monitorable。
## [br]
## @api public
@export var manage_monitoring: bool = true

## 是否同步 CanvasItem.visible。
## [br]
## @api public
@export var manage_visibility: bool = false


# --- 私有变量 ---

var _active: bool = true


# --- Godot 生命周期方法 ---

func _ready() -> void:
	if apply_on_ready:
		apply_state()


# --- 公共方法 ---

## 激活状态组。
## [br]
## @api public
func activate() -> void:
	set_active_state(true)


## 关闭状态组。
## [br]
## @api public
func deactivate() -> void:
	set_active_state(false)


## 设置状态组激活状态。
## [br]
## @api public
## [br]
## @param value: 是否激活。
func set_active_state(value: bool) -> void:
	active = value


## 应用当前状态到所有受管理节点。
## [br]
## @api public
func apply_state() -> void:
	for node: Node in get_managed_nodes():
		_apply_to_node(node)


## 获取受管理节点列表。
## [br]
## @api public
## [br]
## @return 节点列表。
func get_managed_nodes() -> Array[Node]:
	return _GF_HIT_BOX_STATE_SUPPORT.collect_managed_nodes(
		self,
		recursive,
		Callable(self, "_is_managed_node")
	)


# --- 私有/辅助方法 ---

func _set_active(value: bool) -> void:
	if _active == value:
		return
	_active = value
	if is_inside_tree():
		apply_state()
		active_changed.emit(_active)


func _is_managed_node(node: Node) -> bool:
	return node is GFHitBox2D or node is GFHurtBox2D or node is Area2D


func _apply_to_node(node: Node) -> void:
	if manage_enabled:
		if node is GFHitBox2D:
			var hit_box: GFHitBox2D = node
			hit_box.enabled = active
		elif node is GFHurtBox2D:
			var hurt_box: GFHurtBox2D = node
			hurt_box.enabled = active

	if manage_monitoring and node is Area2D:
		var area: Area2D = node
		area.monitoring = active
		area.monitorable = active

	if manage_visibility and node is CanvasItem:
		var canvas_item: CanvasItem = node
		canvas_item.visible = active
