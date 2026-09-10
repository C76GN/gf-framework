@tool

## GFScenePlacementCreateCommand: 单个场景实例的编辑器创建历史。
##
## 历史保留已经创建的实例；撤销时脱树，重做复用同一实例。历史释放时只销毁仍脱树的实例。
## [br]
## @api framework_internal
## [br]
## @category internal_helper
## [br]
## @since unreleased
class_name GFScenePlacementCreateCommand
extends GFEditorCommand


# --- 私有变量 ---

var _source: PackedScene = null
var _parent_ref: WeakRef = null
var _root_ref: WeakRef = null
var _world_transform: Transform3D = Transform3D.IDENTITY
var _instance: Node3D = null


# --- Godot 生命周期方法 ---

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		if is_instance_valid(_instance) and _instance.get_parent() == null:
			_instance.free()
		_instance = null


# --- 可重写钩子 / 虚方法 ---

## 创建或重新加入同一实例，并恢复确认时的世界变换。
## [br]
## @api protected
## [br]
## @since unreleased
## [br]
## @return 失效父节点或场景返回错误，不写入其他场景。
func _do_it() -> Error:
	var parent: Node3D = _get_parent_node()
	var scene_root: Node = _get_root_node()
	if not _is_valid_destination(parent, scene_root) or _source == null:
		return ERR_UNAVAILABLE
	if is_instance_valid(_instance) and _instance.get_parent() != null:
		return ERR_ALREADY_IN_USE
	if not is_instance_valid(_instance):
		var edit_state: PackedScene.GenEditState = PackedScene.GEN_EDIT_STATE_DISABLED
		if Engine.is_editor_hint():
			edit_state = PackedScene.GEN_EDIT_STATE_INSTANCE
		var created: Node = _source.instantiate(edit_state)
		if not is_instance_valid(created) or not created is Node3D:
			if is_instance_valid(created):
				created.free()
			return ERR_INVALID_DATA
		_instance = created
	if _instance.is_queued_for_deletion() or not _is_valid_destination(parent, scene_root):
		_detach_failed_instance()
		return ERR_UNAVAILABLE
	var destination_transform: Transform3D = _world_transform
	if not _instance.top_level:
		destination_transform = parent.global_transform.affine_inverse() * _world_transform
	_instance.transform = destination_transform
	if not is_instance_valid(_instance) or _instance.is_queued_for_deletion() or not _is_valid_destination(parent, scene_root):
		_detach_failed_instance()
		return ERR_UNAVAILABLE
	parent.add_child(_instance, true)
	if (
		not is_instance_valid(_instance)
		or _instance.is_queued_for_deletion()
		or not _is_valid_destination(parent, scene_root)
		or _instance.get_parent() != parent
	):
		_detach_failed_instance()
		return ERR_CANT_CREATE
	_instance.owner = scene_root
	if not _is_attached_destination_valid(parent, scene_root):
		_detach_failed_instance()
		return ERR_CANT_CREATE
	# 入树和 owner 设置期间的同步回调可能改变父节点或实例变换。
	# 确认最终施加用户选定的世界变换；后续帧的工具脚本仍由项目控制。
	destination_transform = _world_transform
	if not _instance.top_level:
		destination_transform = parent.global_transform.affine_inverse() * _world_transform
	_instance.transform = destination_transform
	if (
		not _is_attached_destination_valid(parent, scene_root)
		or not _instance.global_transform.is_equal_approx(_world_transform)
	):
		_detach_failed_instance()
		return ERR_CANT_CREATE
	return OK


## 撤销仅移除本命令实例；不会重新选择节点或操作面板。
## [br]
## @api protected
## [br]
## @since unreleased
## [br]
## @return 实例或原父节点失效时返回错误。
func _undo_it() -> Error:
	var parent: Node3D = _get_parent_node()
	var scene_root: Node = _get_root_node()
	if not _belongs_to_original_root(parent, scene_root) or not is_instance_valid(_instance):
		return ERR_UNAVAILABLE
	if _instance.get_parent() != parent:
		return ERR_INVALID_DATA
	parent.remove_child(_instance)
	return OK


## 使用原编辑场景根选择原生 history。
## [br]
## @api protected
## [br]
## @since unreleased
## [br]
## @return 原场景根或 null。
func _get_undo_context() -> Object:
	return _get_root_node()


## 校验父节点与场景根属于同一编辑历史。
## [br]
## @api protected
## [br]
## @since unreleased
## [br]
## @return 实际发生结构修改的父节点。
func _get_undo_targets() -> Array[Object]:
	var parent: Node3D = _get_parent_node()
	return [parent] if parent != null else []


# --- 框架内部方法 ---

## 冻结首次创建所需的数据；历史不捕获任何面板或插件。
## [br]
## @api framework_internal
## [br]
## @since unreleased
## [br]
## @param source: 已选择的场景。
## [br]
## @param parent: 实例将加入的父节点。
## [br]
## @param scene_root: 用作 owner 和历史路由的编辑场景根。
## [br]
## @param world_transform: 确认时的目标世界变换。
func configure(
	source: PackedScene,
	parent: Node3D,
	scene_root: Node,
	world_transform: Transform3D
) -> void:
	if is_sealed():
		return
	_source = source
	_parent_ref = weakref(parent)
	_root_ref = weakref(scene_root)
	_world_transform = world_transform
	command_name = "Place 3D Scene"


## 获取已创建实例；确认失败或历史尚未执行时返回 null。
## [br]
## @api framework_internal
## [br]
## @since unreleased
## [br]
## @return 仍存活的创建实例。
func get_instance() -> Node3D:
	return _instance if is_instance_valid(_instance) else null


# --- 私有/辅助方法 ---

func _is_attached_destination_valid(parent: Node3D, scene_root: Node) -> bool:
	return (
		is_instance_valid(_instance)
		and not _instance.is_queued_for_deletion()
		and _is_valid_destination(parent, scene_root)
		and _instance.get_parent() == parent
		and _instance.owner == scene_root
	)


func _belongs_to_original_root(parent: Node3D, scene_root: Node) -> bool:
	return (
		is_instance_valid(parent)
		and is_instance_valid(scene_root)
		and not parent.is_queued_for_deletion()
		and not scene_root.is_queued_for_deletion()
		and (parent == scene_root or scene_root.is_ancestor_of(parent))
	)


func _detach_failed_instance() -> void:
	if is_instance_valid(_instance):
		var parent: Node = _instance.get_parent()
		if is_instance_valid(parent):
			parent.remove_child(_instance)


func _get_parent_node() -> Node3D:
	if _parent_ref == null:
		return null
	var value: Variant = _parent_ref.get_ref()
	if value is Node3D and is_instance_valid(value):
		var parent: Node3D = value
		return parent
	return null


func _get_root_node() -> Node:
	if _root_ref == null:
		return null
	var value: Variant = _root_ref.get_ref()
	if value is Node and is_instance_valid(value):
		var root: Node = value
		return root
	return null


func _is_valid_destination(parent: Node3D, scene_root: Node) -> bool:
	return (
		_belongs_to_original_root(parent, scene_root)
		and parent.is_inside_tree()
		and scene_root.is_inside_tree()
		and parent.global_transform.is_finite()
		and absf(parent.global_transform.basis.determinant()) > 0.00000001
	)
