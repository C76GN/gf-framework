## GFProjectileLaunchInput3D: 3D 发射请求的 typed 快照。
## [br]
## @api public
## [br]
## @category value_object
## [br]
## @since unreleased
class_name GFProjectileLaunchInput3D
extends Resource


# --- 枚举 ---

## 定义发射目标的封闭类型。
## [br]
## @api public
## [br]
## @since unreleased
enum TargetKind {
	## 未指定目标。
	NONE = 0,
	## 弱引用 Node3D 目标。
	NODE = 1,
	## 固定 world position 目标。
	POSITION = 2,
}


# --- 私有变量 ---

var _target_kind: TargetKind = TargetKind.NONE
var _target_ref: WeakRef = null
var _target_position: Vector3 = Vector3.ZERO
var _metadata: Dictionary = {}


# --- 公共方法 ---

## 清除目标。
## [br]
## @api public
## [br]
## @since unreleased
func set_target_none() -> void:
	_target_kind = TargetKind.NONE
	_target_ref = null
	_target_position = Vector3.ZERO


## 使用弱引用 Node3D 作为目标。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param node: live 目标；null 或失效目标会退化为 NONE。
func set_target_node(node: Node3D) -> void:
	if node == null or not is_instance_valid(node):
		set_target_none()
		return
	_target_kind = TargetKind.NODE
	_target_ref = weakref(node)


## 使用固定 world position 作为目标。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param position_value: 目标 world position。
func set_target_position(position_value: Vector3) -> void:
	_target_kind = TargetKind.POSITION
	_target_ref = null
	_target_position = position_value


## 返回当前目标类型。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return: 封闭 `TargetKind` 值。
func get_target_kind() -> TargetKind:
	return _target_kind


## 返回当前 live node 目标。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return: NODE 目标；未设置或已释放时返回 null。
func get_target_node() -> Node3D:
	if _target_kind != TargetKind.NODE or _target_ref == null:
		return null
	var value: Variant = _target_ref.get_ref()
	if value is Node3D:
		var node: Node3D = value
		if node.is_queued_for_deletion():
			return null
		return node
	return null


## 返回固定位置目标。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return: POSITION target 值。
func get_target_position() -> Vector3:
	return _target_position


## 深复制调用方 metadata。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param metadata: 项目自定义发射 metadata。
## [br]
## @schema metadata: Dictionary，可包含项目字段；框架不写入 motion/session 私有状态。
func set_metadata(metadata: Dictionary) -> void:
	_metadata = metadata.duplicate(true)


## 返回 metadata 深副本。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return: 可由调用方修改的 metadata 副本。
## [br]
## @schema return: Dictionary，与内部快照完全分离的项目 metadata。
func get_metadata() -> Dictionary:
	return _metadata.duplicate(true)


## 创建 target 与 metadata 均独立的 typed 副本。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return: 新的 3D launch input。
func duplicate_input() -> GFProjectileLaunchInput3D:
	var result: GFProjectileLaunchInput3D = GFProjectileLaunchInput3D.new()
	match _target_kind:
		TargetKind.NODE:
			result.set_target_node(get_target_node())
		TargetKind.POSITION:
			result.set_target_position(_target_position)
		_:
			result.set_target_none()
	result.set_metadata(_metadata)
	return result
