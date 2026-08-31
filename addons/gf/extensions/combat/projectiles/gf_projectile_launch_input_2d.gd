## GFProjectileLaunchInput2D: 2D 发射请求的 typed 快照。
## [br]
## @api public
## [br]
## @category value_object
## [br]
## @since 11.0.0
class_name GFProjectileLaunchInput2D
extends Resource


# --- 枚举 ---

## 定义发射目标的封闭类型。
## [br]
## @api public
## [br]
## @since 11.0.0
enum TargetKind {
	## 未指定目标。
	NONE = 0,
	## 弱引用 Node2D 目标。
	NODE = 1,
	## 固定 world position 目标。
	POSITION = 2,
}


# --- 私有变量 ---

var _target_kind: TargetKind = TargetKind.NONE
var _target_ref: WeakRef = null
var _target_position: Vector2 = Vector2.ZERO
var _metadata: Dictionary = {}


# --- 公共方法 ---

## 清除目标。
## [br]
## @api public
## [br]
## @since 11.0.0
func set_target_none() -> void:
	_target_kind = TargetKind.NONE
	_target_ref = null
	_target_position = Vector2.ZERO


## 使用弱引用 Node2D 作为目标。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @param node: live 目标；null 或失效目标会退化为 NONE。
func set_target_node(node: Node2D) -> void:
	if node == null or not is_instance_valid(node):
		set_target_none()
		return
	_target_kind = TargetKind.NODE
	_target_ref = weakref(node)


## 使用固定 world position 作为目标。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @param position_value: 目标 world position。
func set_target_position(position_value: Vector2) -> void:
	_target_kind = TargetKind.POSITION
	_target_ref = null
	_target_position = position_value


## 返回当前目标类型。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @return: 封闭 `TargetKind` 值。
func get_target_kind() -> TargetKind:
	return _target_kind


## 返回当前 live node 目标。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @return: NODE 目标；未设置或已释放时返回 null。
func get_target_node() -> Node2D:
	if _target_kind != TargetKind.NODE or _target_ref == null:
		return null
	var value: Variant = _target_ref.get_ref()
	if value is Node2D:
		var node: Node2D = value
		if node.is_queued_for_deletion():
			return null
		return node
	return null


## 返回固定位置目标。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @return: POSITION target 值。
func get_target_position() -> Vector2:
	return _target_position


## 深复制调用方 metadata。
## [br]
## @api public
## [br]
## @since 11.0.0
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
## @since 11.0.0
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
## @since 11.0.0
## [br]
## @return: 新的 2D launch input。
func duplicate_input() -> GFProjectileLaunchInput2D:
	var result: GFProjectileLaunchInput2D = GFProjectileLaunchInput2D.new()
	match _target_kind:
		TargetKind.NODE:
			result.set_target_node(get_target_node())
		TargetKind.POSITION:
			result.set_target_position(_target_position)
		_:
			result.set_target_none()
	result.set_metadata(_metadata)
	return result
