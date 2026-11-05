## GFFlowNodeExecution: 一次节点执行的写入资格。节点完成、流程取消或同一节点再次执行时，旧回调无法写入后续执行。
## [br]
## @api public
## [br]
## @category runtime_handle
## [br]
## @since unreleased
class_name GFFlowNodeExecution
extends RefCounted


# --- 私有变量 ---

## 此执行正在使用的帧内节点数据。封闭时解除引用。
## [br]
## @api private
var _state: Dictionary = {}

## 允许在同步执行和受等待的 Signal 结束前更新。
## [br]
## @api private
var _active: bool = true

## 区分未覆盖和显式空分支。
## [br]
## @api private
var _has_override: bool = false

## 本次执行选择的后继，不与同一节点的下次执行共享。
## [br]
## @api private
var _next_ids: PackedStringArray = PackedStringArray()

## 待当前节点完成时进入的子图，子图退出后回到父帧的后继队列。
## [br]
## @api private
var _child_graph: GFFlowGraph = null


# --- Godot 生命周期方法 ---

func _init(node_state: Dictionary = {}) -> void:
	_state = node_state


# --- 公共方法 ---

## 查询这个执行句柄是否仍可写。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return: 可写时返回 true。
func is_active() -> bool:
	return _active


## 写入当前帧中本节点的进度。集合在边界复制，旧执行的更新返回失败。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param key: 节点进度键。
## [br]
## @param value: 项目进度值。
## [br]
## @return: 成功写入时返回 true。
## [br]
## @schema value: 原始 Variant；容器复制，项目 Object 仍为引用。
func set_runtime_value(key: StringName, value: Variant) -> bool:
	if not _active or key == &"":
		return false
	_state[key] = GFVariantData.duplicate_variant(value)
	return true


## 读取当前节点在本帧内的运行进度。返回集合副本。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param key: 节点进度键。
## [br]
## @param default_value: 未命中或执行结束时的默认值。
## [br]
## @return: 节点的运行进度。
## [br]
## @schema default_value: 任意项目值。
## [br]
## @schema return: 进度值或默认值。
func get_runtime_value(key: StringName, default_value: Variant = null) -> Variant:
	if not _active:
		return default_value
	return GFVariantData.duplicate_variant(_state.get(key, default_value))


## 清空当前节点在此帧中的进度。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return: 执行仍有效时返回 true。
func clear_runtime_state() -> bool:
	if not _active:
		return false
	_state.clear()
	return true


## 选择本节点的后继。传入空列表表示停止本分支。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param node_ids: 本次执行选择的后继标识。
## [br]
## @return: 选择已接纳时返回 true。
func set_next_nodes(node_ids: PackedStringArray) -> bool:
	if not _active:
		return false
	_has_override = true
	_next_ids = node_ids.duplicate()
	return true


## 请求在节点结束后先执行子图。子图有独立帧；同一次节点执行只接纳一个调用。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param graph: 要进入的新子图帧。
## [br]
## @return: 请求已接纳时返回 true。
func call_subgraph(graph: GFFlowGraph) -> bool:
	if (
		not _active
		or _child_graph != null
		or graph == null
	):
		return false
	_child_graph = graph
	return true


# --- 框架内部方法 ---

## 读取调度覆盖标识，以保留显式空分支。
## [br]
## @api framework_internal
## [br]
## @since unreleased
## [br]
## @return: 节点已覆盖后继时返回 true。
func has_next_nodes_override() -> bool:
	return _has_override


## 读取已选后继的独立副本。
## [br]
## @api framework_internal
## [br]
## @since unreleased
## [br]
## @return: 本节点覆盖的后继 ID。
func get_next_node_ids() -> PackedStringArray:
	return _next_ids.duplicate()


## 取走已注册的子图调用，使结束的句柄不继续持有图资源。
## [br]
## @api framework_internal
## [br]
## @since unreleased
## [br]
## @return: 请求调用的图，未请求时为 null。
func take_child_graph() -> GFFlowGraph:
	var child: GFFlowGraph = _child_graph
	_child_graph = null
	return child


## 收回本次执行的写权限并断开帧内进度引用。
## [br]
## @api framework_internal
## [br]
## @since unreleased
func close() -> void:
	_active = false
	_state = {}
	_child_graph = null
