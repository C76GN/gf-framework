@tool

## GFNodeStateMachine: 基于场景树的多状态组状态机。
##
## 支持直接子 GFNodeState 组成内部状态组，也支持多个 GFNodeStateGroup 并行工作。
## [br]
## @api public
## [br]
## @category runtime_service
## [br]
## @since 3.17.0
class_name GFNodeStateMachine
extends Node


# --- 信号 ---

## 状态组加入后发出。
## [br]
## @api public
## [br]
## @param group: 新加入的状态组。
signal state_group_added(group: GFNodeStateGroup)

## 状态组移除后发出。
## [br]
## @api public
## [br]
## @param group: 被移除的状态组。
signal state_group_removed(group: GFNodeStateGroup)

## 任意状态组切换状态后发出。
## [br]
## @api public
## [br]
## @param group: 发生状态切换的状态组。
## [br]
## @param old_state: 切换前的状态；没有旧状态时为 null。
## [br]
## @param new_state: 切换后的状态；状态组停止时可为 null。
signal state_changed(group: GFNodeStateGroup, old_state: GFNodeState, new_state: GFNodeState)

## 任意状态组中的状态处理状态事件后发出。
## [br]
## @api public
## [br]
## @param group: 处理事件的状态所属状态组。
## [br]
## @param event_id: 状态事件标识。
## [br]
## @param handler_state: 实际处理事件的状态节点。
## [br]
## @param payload: 状态事件载荷。
## [br]
## @schema payload: 状态事件载荷；具体结构由 event_id 和项目逻辑约定。
signal state_event_handled(group: GFNodeStateGroup, event_id: StringName, handler_state: GFNodeState, payload: Variant)


# --- 枚举 ---

## 节点状态机初始状态启动时机。
## [br]
## @api public
enum StartMode {
	## 状态机 ready 时启动，适合需要旧版启动顺序的项目。
	ON_READY,
	## 等待宿主节点 ready 后启动。
	AFTER_HOST_READY,
	## 只加载状态，不自动启动；由外部调用 start()。
	MANUAL,
}


# --- 常量 ---

## 直接子 GFNodeState 组成的内置状态组名称。
## [br]
## @api public
const INTERNAL_GROUP_NAME: StringName = &"_internal"

## 内部状态组节点使用的元数据键。
## [br]
## @api framework_internal
const META_INTERNAL_GROUP: StringName = &"_gf_node_state_machine_internal_group"
const _GF_ASYNC_CALL_SCRIPT = preload("res://addons/gf/kernel/core/gf_async_call.gd")


# --- 导出变量 ---

## 可选状态机配置资源。为空时继续使用本节点上的兼容导出项。
## [br]
## @api public
@export var config: GFNodeStateMachineConfig = null:
	set(value):
		config = value
		_queue_configuration_warning_update()

## 内部状态组初始状态名。
## [br]
## @api public
@export var initial_state: StringName = &"":
	set(value):
		initial_state = value
		_queue_configuration_warning_update()

## 内部状态组初始状态参数。
## [br]
## @api public
## [br]
## @schema initial_args: 内部状态组初始状态参数 Dictionary；键和值由初始状态的项目逻辑约定。
@export var initial_args: Dictionary = {}

## ready 时是否自动从子节点加载状态与状态组。
## [br]
## @api public
@export var reload_on_ready: bool = true

## 初始状态启动模式。
## [br]
## @api public
@export var start_mode: StartMode = StartMode.AFTER_HOST_READY:
	set(value):
		start_mode = value
		_queue_configuration_warning_update()

## 运行时重新从子节点加载时，是否尽量恢复各状态组的当前状态。
## [br]
## @api public
@export var preserve_current_state_on_reload: bool = true


# --- 私有变量 ---

var _groups: Dictionary = {}
var _internal_group: GFNodeStateGroup = null
var _group_keys_by_instance_id: Dictionary = {}
var _group_state_changed_callables: Dictionary = {}
var _group_state_event_handled_callables: Dictionary = {}
var _event_architectures: Array[WeakRef] = []
var _is_ready: bool = false
var _reload_queued: bool = false
var _is_reloading: bool = false
var _preserve_reload_state_active: bool = false
var _lifecycle_serial: int = 0
var _is_restoring_state_snapshot: bool = false
var _restore_blocked_operations: Array[StringName] = []
var _group_registry_revision: int = 0


# --- Godot 生命周期方法 ---

func _enter_tree() -> void:
	_lifecycle_serial += 1
	if not child_entered_tree.is_connected(_on_child_entered_tree):
		var _entered_connect_error: int = child_entered_tree.connect(_on_child_entered_tree)
	if not child_exiting_tree.is_connected(_on_child_exiting_tree):
		var _exiting_connect_error: int = child_exiting_tree.connect(_on_child_exiting_tree)
	_queue_configuration_warning_update()


func _ready() -> void:
	if Engine.is_editor_hint():
		_queue_configuration_warning_update()
		return

	_is_ready = true
	if reload_on_ready:
		reload_from_children()
	if start_mode == StartMode.AFTER_HOST_READY:
		_GF_ASYNC_CALL_SCRIPT.run_detached(Callable(self, &"_start_after_host_ready"))


func _exit_tree() -> void:
	_lifecycle_serial += 1
	_is_ready = false
	_reload_queued = false
	if child_entered_tree.is_connected(_on_child_entered_tree):
		child_entered_tree.disconnect(_on_child_entered_tree)
	if child_exiting_tree.is_connected(_on_child_exiting_tree):
		child_exiting_tree.disconnect(_on_child_exiting_tree)
	if Engine.is_editor_hint():
		return
	clear_state_groups()


# --- Godot 回调方法 ---

func _get_configuration_warnings() -> PackedStringArray:
	var report: GFValidationReport = GFNodeStateMachineValidator.validate_machine(self)
	return GFNodeStateMachineValidator.make_configuration_warnings(report)


# --- 公共方法 ---

## 通过路径切换状态。path 可为 "State" 或 "Group/State"。
## [br]
## @api public
## [br]
## @since 3.0.0
## [br]
## @param path: 资源路径或状态路径。
## [br]
## @param args: 状态切换时传递的可选参数。
## [br]
## @schema args: 状态切换参数 Dictionary；键和值由调用方约定。
## [br]
## @param stack_exit_policy: 折叠暂停栈时使用 GFNodeStateGroup.StackExitPolicy。
func transition_to(
	path: StringName,
	args: Dictionary = {},
	stack_exit_policy: int = GFNodeStateGroup.StackExitPolicy.REQUIRE_GUARDS
) -> void:
	if _reject_mutation_during_restore(&"transition_to"):
		return
	var text: String = String(path)
	var parts: PackedStringArray = text.split("/", false)
	if parts.size() == 1:
		transition_group_to(INTERNAL_GROUP_NAME, StringName(parts[0]), args, stack_exit_policy)
	elif parts.size() == 2:
		transition_group_to(StringName(parts[0]), StringName(parts[1]), args, stack_exit_policy)
	else:
		push_error("[GFNodeStateMachine] transition_to 失败：路径格式无效。")


## 切换指定状态组到指定状态。
## [br]
## @api public
## [br]
## @since 3.0.0
## [br]
## @param group_name: 能力组或状态组名称。
## [br]
## @param state_name: 目标状态名称。
## [br]
## @param args: 状态切换时传递的可选参数。
## [br]
## @schema args: 状态切换参数 Dictionary；键和值由调用方约定。
## [br]
## @param stack_exit_policy: 折叠暂停栈时使用 GFNodeStateGroup.StackExitPolicy。
func transition_group_to(
	group_name: StringName,
	state_name: StringName,
	args: Dictionary = {},
	stack_exit_policy: int = GFNodeStateGroup.StackExitPolicy.REQUIRE_GUARDS
) -> void:
	if _reject_mutation_during_restore(&"transition_group_to"):
		return
	var group: GFNodeStateGroup = get_state_group(group_name)
	if group == null:
		push_warning("[GFNodeStateMachine] 切换失败，未找到状态组：%s" % group_name)
		return
	group.transition_to(state_name, args, stack_exit_policy)


## 暂停当前内部状态并叠加进入一个子状态。path 可为 "State" 或 "Group/State"。
## [br]
## @api public
## [br]
## @param path: 资源路径或状态路径。
## [br]
## @param args: 状态切换时传递的可选参数。
## [br]
## @schema args: 状态切换参数 Dictionary；键和值由调用方约定。
func push_state(path: StringName, args: Dictionary = {}) -> void:
	if _reject_mutation_during_restore(&"push_state"):
		return
	var text: String = String(path)
	var parts: PackedStringArray = text.split("/", false)
	if parts.size() == 1:
		push_group_state(INTERNAL_GROUP_NAME, StringName(parts[0]), args)
	elif parts.size() == 2:
		push_group_state(StringName(parts[0]), StringName(parts[1]), args)
	else:
		push_error("[GFNodeStateMachine] push_state 失败：路径格式无效。")


## 暂停指定状态组当前状态并叠加进入一个子状态。
## [br]
## @api public
## [br]
## @param group_name: 能力组或状态组名称。
## [br]
## @param state_name: 目标状态名称。
## [br]
## @param args: 状态切换时传递的可选参数。
## [br]
## @schema args: 状态切换参数 Dictionary；键和值由调用方约定。
func push_group_state(group_name: StringName, state_name: StringName, args: Dictionary = {}) -> void:
	if _reject_mutation_during_restore(&"push_group_state"):
		return
	var group: GFNodeStateGroup = get_state_group(group_name)
	if group == null:
		push_warning("[GFNodeStateMachine] push_state 失败，未找到状态组：%s" % group_name)
		return
	group.push_state(state_name, args)


## 弹出指定状态组的栈式子状态。
## [br]
## @api public
## [br]
## @param group_name: 能力组或状态组名称。
## [br]
## @param args: 状态切换时传递的可选参数。
## [br]
## @schema args: 状态切换参数 Dictionary；键和值由调用方约定。
## [br]
## @return: 成功恢复上一层状态时返回 true。
func pop_state(group_name: StringName = INTERNAL_GROUP_NAME, args: Dictionary = {}) -> bool:
	if _reject_mutation_during_restore(&"pop_state"):
		return false
	var group: GFNodeStateGroup = get_state_group(group_name)
	if group == null:
		push_warning("[GFNodeStateMachine] pop_state 失败，未找到状态组：%s" % group_name)
		return false
	return group.pop_state(args)


## 启动所有已加载状态组的初始状态。若尚未加载状态，则会先从子节点加载。
## [br]
## @api public
## [br]
## @param args: 启动时传给初始状态的参数；为空时使用各状态组 initial_args。
## [br]
## @schema args: 启动参数 Dictionary；为空时使用各状态组 initial_args。
func start(args: Dictionary = {}) -> void:
	if _reject_mutation_during_restore(&"start"):
		return
	if _groups.is_empty():
		reload_from_children()

	for group: GFNodeStateGroup in _get_registered_groups():
		_start_group_node(group, args)


## 启动指定状态组的初始状态。若尚未加载状态，则会先从子节点加载。
## [br]
## @api public
## [br]
## @param group_name: 要启动的状态组名。
## [br]
## @param args: 启动时传给初始状态的参数；为空时使用该状态组 initial_args。
## [br]
## @schema args: 启动参数 Dictionary；为空时使用该状态组 initial_args。
func start_group(group_name: StringName = INTERNAL_GROUP_NAME, args: Dictionary = {}) -> void:
	if _reject_mutation_during_restore(&"start_group"):
		return
	if _groups.is_empty():
		reload_from_children()

	var group: GFNodeStateGroup = get_state_group(group_name)
	if group == null:
		push_warning("[GFNodeStateMachine] start_group 失败，未找到状态组：%s" % group_name)
		return

	_start_group_node(group, args)


## 添加状态组。
## [br]
## @api public
## [br]
## @param group: 所属状态组。
func add_state_group(group: GFNodeStateGroup) -> void:
	if _reject_mutation_during_restore(&"add_state_group"):
		return
	if not _is_node_state_group(group):
		return

	var key: StringName = group.get_group_name()
	if _groups.has(key):
		push_warning("[GFNodeStateMachine] 状态组已存在，已忽略重复添加：%s" % key)
		return

	_groups[key] = group
	_group_registry_revision += 1
	_group_keys_by_instance_id[group.get_instance_id()] = key
	var changed_callable: Callable = _on_group_current_state_changed.bind(group)
	_group_state_changed_callables[key] = changed_callable
	_connect_state_group_signals(group, changed_callable)
	group.initialize(self, _should_start_group_on_initialize())
	state_group_added.emit(group)


## 移除状态组。
## [br]
## @api public
## [br]
## @param group: 所属状态组。
## [br]
## @return: 成功移除已注册状态组时返回 true。
func remove_state_group(group: GFNodeStateGroup) -> bool:
	if _reject_mutation_during_restore(&"remove_state_group"):
		return false
	if not _is_node_state_group(group):
		return false

	var key: StringName = _get_registered_group_key(group)
	if not _groups.has(key):
		return false
	var changed_callable: Callable = _get_dictionary_callable(_group_state_changed_callables, key)
	_disconnect_state_group_signals(group, changed_callable)
	_erase_dictionary_key(_groups, key)
	_erase_dictionary_key(_group_keys_by_instance_id, group.get_instance_id())
	_erase_dictionary_key(_group_state_changed_callables, key)
	_group_registry_revision += 1
	group.detach_machine()
	state_group_removed.emit(group)
	return true


## 获取已注册状态组列表。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @return: 已注册状态组节点列表。
## [br]
## @schema return: Array[GFNodeStateGroup]，只读快照；修改状态组请使用 add_state_group() 与 remove_state_group()。
func get_state_groups() -> Array[GFNodeStateGroup]:
	return _get_registered_groups()


## 获取状态组。
## [br]
## @api public
## [br]
## @param group_name: 能力组或状态组名称。
## [br]
## @return: 注册名对应的状态组；不存在时返回 null。
func get_state_group(group_name: StringName) -> GFNodeStateGroup:
	return _variant_to_state_group(GFVariantData.get_option_value(_groups, group_name))


## 获取内部状态组当前状态。
## [br]
## @api public
## [br]
## @return: 内部状态组当前状态；未启动或不存在时返回 null。
func get_current_state() -> GFNodeState:
	var group: GFNodeStateGroup = get_state_group(INTERNAL_GROUP_NAME)
	if group == null:
		return null
	return group.get_current_state()


## 获取指定状态组当前状态。
## [br]
## @api public
## [br]
## @param group_name: 能力组或状态组名称。
## [br]
## @return: 当前状态；未找到状态组或未启动时返回 null。
func get_current_group_state(group_name: StringName = INTERNAL_GROUP_NAME) -> GFNodeState:
	var group: GFNodeStateGroup = get_state_group(group_name)
	if group == null:
		return null
	return group.get_current_state()


## 获取指定状态组当前状态名。
## [br]
## @api public
## [br]
## @param group_name: 能力组或状态组名称。
## [br]
## @return: 当前状态名；未找到状态组或未启动时返回空 StringName。
func get_current_state_name(group_name: StringName = INTERNAL_GROUP_NAME) -> StringName:
	var group: GFNodeStateGroup = get_state_group(group_name)
	if group == null:
		return &""
	return group.get_current_state_name()


## 获取指定状态组状态历史。
## [br]
## @api public
## [br]
## @param group_name: 能力组或状态组名称。
## [br]
## @return: 最近进入过的状态名列表。
## [br]
## @schema return: 状态历史 Array[StringName]，按进入顺序排列。
func get_state_history(group_name: StringName = INTERNAL_GROUP_NAME) -> Array[StringName]:
	var result: Array[StringName] = []
	var group: GFNodeStateGroup = get_state_group(group_name)
	if group == null:
		return result

	return group.get_state_history()


## 获取指定状态组暂停栈深度。
## [br]
## @api public
## [br]
## @param group_name: 能力组或状态组名称。
## [br]
## @return: 指定状态组的暂停栈深度；未找到状态组时返回 0。
func get_stack_depth(group_name: StringName = INTERNAL_GROUP_NAME) -> int:
	var group: GFNodeStateGroup = get_state_group(group_name)
	if group == null:
		return 0
	return group.get_stack_depth()


## 判断 path 指向的状态是否为当前状态或暂停栈中的状态。
## [br]
## @api public
## [br]
## @param path: 资源路径或状态路径。
## [br]
## @return: 指定状态位于当前状态或暂停栈中时返回 true。
func is_in_state(path: StringName) -> bool:
	var text: String = String(path)
	var parts: PackedStringArray = text.split("/", false)
	if parts.size() == 1:
		return _is_group_in_state(INTERNAL_GROUP_NAME, StringName(parts[0]))
	if parts.size() == 2:
		return _is_group_in_state(StringName(parts[0]), StringName(parts[1]))
	push_error("[GFNodeStateMachine] is_in_state 失败：路径格式无效。")
	return false


## 重启指定状态组当前状态。
## [br]
## @api public
## [br]
## @param group_name: 能力组或状态组名称。
## [br]
## @param args: 状态切换时传递的可选参数。
## [br]
## @schema args: 状态切换参数 Dictionary；键和值由调用方约定。
func restart_group(group_name: StringName = INTERNAL_GROUP_NAME, args: Dictionary = {}) -> void:
	if _reject_mutation_during_restore(&"restart_group"):
		return
	var group: GFNodeStateGroup = get_state_group(group_name)
	if group == null:
		push_warning("[GFNodeStateMachine] restart_group 失败，未找到状态组：%s" % group_name)
		return
	group.restart(args)


## 派发状态事件。group_name 为空时会按已注册状态组顺序广播到所有组。
## [br]
## @api public
## [br]
## @param event_id: 状态事件标识。
## [br]
## @param payload: 状态事件载荷。
## [br]
## @param group_name: 可选目标状态组名；为空表示所有状态组。
## [br]
## @schema payload: 状态事件载荷；具体结构由 event_id 和项目逻辑约定。
## [br]
## @return: 有状态处理该事件时返回 true。
func dispatch_state_event(event_id: StringName, payload: Variant = null, group_name: StringName = &"") -> bool:
	if _reject_mutation_during_restore(&"dispatch_state_event"):
		return false
	if group_name != &"":
		var group: GFNodeStateGroup = get_state_group(group_name)
		if group == null:
			return false
		return group.dispatch_state_event(event_id, payload)

	for group: GFNodeStateGroup in _get_registered_groups():
		if group.dispatch_state_event(event_id, payload):
			return true
	return false


## 获取节点状态机调试快照。
## [br]
## @api public
## [br]
## @since 3.0.0
## [br]
## @return: 包含所有状态组当前状态、历史、栈深度和黑板副本的字典。
## [br]
## @schema return: 调试快照 Dictionary，包含 schema_version、groups 和 internal_group 字段；groups 的键为状态组名，值为 GFNodeStateGroup.get_state_snapshot() 返回的状态组快照。
func get_state_snapshot() -> Dictionary:
	var groups: Dictionary = {}
	for group_key: Variant in _groups.keys():
		var group: GFNodeStateGroup = _variant_to_state_group(_groups[group_key])
		if group == null:
			continue
		groups[group_key] = group.get_state_snapshot()
	return {
		"schema_version": 1,
		"groups": groups,
		"internal_group": INTERNAL_GROUP_NAME,
	}


## 获取 JSON-safe 节点状态机调试快照。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param options: 传给 GFReportValueCodec 的编码选项。
## [br]
## @return 可安全 JSON.stringify() 的节点状态机调试快照。
## [br]
## @schema options: Dictionary with GFReportValueCodec options.
## [br]
## @schema return: Dictionary，包含 JSON-safe groups 和 internal_group 字段。
func get_json_compatible_state_snapshot(options: Dictionary = {}) -> Dictionary:
	var codec_options: Dictionary = options.duplicate(true)
	return GFVariantData.as_dictionary(GFReportValueCodec.to_json_compatible(get_state_snapshot(), codec_options))


## 从 get_state_snapshot() 的结果恢复所有已注册状态组。
## [br]
## 该入口只恢复状态机运行态，不创建缺失状态组或状态节点；调用方应先完成场景树装配或 reload_from_children()。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param snapshot: get_state_snapshot() 返回的状态机快照。
## [br]
## @return: 恢复报告。
## [br]
## @schema snapshot: Dictionary，包含 schema_version、groups 和 internal_group 字段。
## [br]
## @schema return: Dictionary，包含 report_schema_version、status、ok、restored、partial、groups、missing_group_snapshots、unrestored_group_snapshots、blocked_operations、group_registry_revision_before、group_registry_revision_after、registry_stable 和 rolled_back 字段。
func restore_state_snapshot(snapshot: Dictionary) -> Dictionary:
	if GFVariantData.get_option_int(snapshot, "schema_version", -1) != 1:
		var invalid_report: Dictionary = _make_machine_restore_report()
		invalid_report["error"] = "unsupported state machine snapshot schema_version."
		return invalid_report
	return _restore_state_snapshot(GFVariantData.get_option_dictionary(snapshot, "groups"))


## 获取当前状态机可用的架构实例。
## [br]
## @api public
## [br]
## @return: 架构实例；状态机未挂入可解析上下文时返回 null。
func get_architecture_or_null() -> GFArchitecture:
	return _get_architecture_or_null()


## 通过当前状态机上下文获取 Model。
## [br]
## @api public
## [br]
## @param model_type: 模型脚本类型。
## [br]
## @param require_ready: 为 true 时，仅返回已完成 ready 阶段的实例。
## [br]
## @return: 模型实例；不可用时返回 null。
func get_model(model_type: Script, require_ready: bool = false) -> Object:
	var architecture: GFArchitecture = _get_architecture_or_null()
	if architecture == null:
		return null
	return architecture.get_model(model_type, require_ready)


## 通过当前状态机上下文获取 System。
## [br]
## @api public
## [br]
## @param system_type: 系统脚本类型。
## [br]
## @param require_ready: 为 true 时，仅返回已完成 ready 阶段的实例。
## [br]
## @return: 系统实例；不可用时返回 null。
func get_system(system_type: Script, require_ready: bool = false) -> Object:
	var architecture: GFArchitecture = _get_architecture_or_null()
	if architecture == null:
		return null
	return architecture.get_system(system_type, require_ready)


## 通过当前状态机上下文获取 Utility。
## [br]
## @api public
## [br]
## @param utility_type: 工具脚本类型。
## [br]
## @param require_ready: 为 true 时，仅返回已完成 ready 阶段的实例。
## [br]
## @return: 工具实例；不可用时返回 null。
func get_utility(utility_type: Script, require_ready: bool = false) -> Object:
	var architecture: GFArchitecture = _get_architecture_or_null()
	if architecture == null:
		return null
	return architecture.get_utility(utility_type, require_ready)


## 仅从当前状态机所属架构获取 Model，不回退父级架构。
## [br]
## @api public
## [br]
## @param model_type: 模型脚本类型。
## [br]
## @param require_ready: 为 true 时，仅返回已完成 ready 阶段的实例。
## [br]
## @return: 当前架构中的模型实例；不可用时返回 null。
func get_local_model(model_type: Script, require_ready: bool = false) -> Object:
	var architecture: GFArchitecture = _get_architecture_or_null()
	if architecture == null:
		return null
	return architecture.get_local_model(model_type, require_ready)


## 仅从当前状态机所属架构获取 System，不回退父级架构。
## [br]
## @api public
## [br]
## @param system_type: 系统脚本类型。
## [br]
## @param require_ready: 为 true 时，仅返回已完成 ready 阶段的实例。
## [br]
## @return: 当前架构中的系统实例；不可用时返回 null。
func get_local_system(system_type: Script, require_ready: bool = false) -> Object:
	var architecture: GFArchitecture = _get_architecture_or_null()
	if architecture == null:
		return null
	return architecture.get_local_system(system_type, require_ready)


## 仅从当前状态机所属架构获取 Utility，不回退父级架构。
## [br]
## @api public
## [br]
## @param utility_type: 工具脚本类型。
## [br]
## @param require_ready: 为 true 时，仅返回已完成 ready 阶段的实例。
## [br]
## @return: 当前架构中的工具实例；不可用时返回 null。
func get_local_utility(utility_type: Script, require_ready: bool = false) -> Object:
	var architecture: GFArchitecture = _get_architecture_or_null()
	if architecture == null:
		return null
	return architecture.get_local_utility(utility_type, require_ready)


## 向当前状态机上下文发送命令。
## [br]
## @api public
## [br]
## @param command: 要发送的命令实例。
## [br]
## @return: 命令执行结果；无可用架构时返回 null。
## [br]
## @schema return: 命令返回值；具体结构由 GFCommand 实现决定。
func send_command(command: Object) -> Variant:
	var architecture: GFArchitecture = _get_architecture_or_null()
	if architecture == null:
		return null
	return architecture.send_command(command)


## 向当前状态机上下文发送查询。
## [br]
## @api public
## [br]
## @param query: 要发送的查询实例。
## [br]
## @return: 查询结果；无可用架构时返回 null。
## [br]
## @schema return: 查询返回值；具体结构由 GFQuery 实现决定。
func send_query(query: Object) -> Variant:
	var architecture: GFArchitecture = _get_architecture_or_null()
	if architecture == null:
		return null
	return architecture.send_query(query)


## 发送类型事件。
## [br]
## @api public
## [br]
## @param event_instance: 要分发的事件实例。
func send_event(event_instance: Object) -> void:
	var architecture: GFArchitecture = _get_architecture_or_null()
	if architecture != null:
		architecture.send_event(event_instance)


## 发送轻量级 StringName 事件。
## [br]
## @api public
## [br]
## @param event_id: StringName 事件标识符。
## [br]
## @param payload: 可选的事件附加数据。
## [br]
## @schema payload: 轻量事件载荷；具体结构由 event_id 和项目逻辑约定。
func send_simple_event(event_id: StringName, payload: Variant = null) -> void:
	var architecture: GFArchitecture = _get_architecture_or_null()
	if architecture != null:
		architecture.send_simple_event(event_id, payload)


## 注册带拥有者的类型事件监听器。
## [br]
## @api public
## [br]
## @since 3.0.0
## [br]
## @param listener_owner: 监听器拥有者。
## [br]
## @param event_type: 要监听的脚本类型。
## [br]
## @param listener: 事件监听器契约。
## [br]
## @param priority: 回调优先级，数值越大越先执行，默认为 0。
func register_event_owned(listener_owner: Object, event_type: Script, listener: GFEventListener, priority: int = 0) -> void:
	var architecture: GFArchitecture = _get_architecture_or_null()
	if architecture != null:
		architecture.register_event_owned(listener_owner, event_type, listener, priority)
		_remember_event_architecture(architecture)


## 注销类型事件监听器。
## [br]
## @api public
## [br]
## @since 5.0.0
## [br]
## @param event_type: 要注销的脚本类型。
## [br]
## @param listener: 要移除的事件监听器契约。
## [br]
## @param listener_owner: 注册监听时使用的拥有者；为空时只注销无 owner 监听。
func unregister_event(event_type: Script, listener: GFEventListener, listener_owner: Object = null) -> void:
	for architecture: GFArchitecture in _get_tracked_event_architectures():
		if listener_owner != null:
			architecture.unregister_event_owned(listener_owner, event_type, listener)
		else:
			architecture.unregister_event(event_type, listener)


## 注册带拥有者的可赋值类型事件监听器。
## [br]
## @api public
## [br]
## @since 3.0.0
## [br]
## @param listener_owner: 监听器拥有者。
## [br]
## @param base_event_type: 要监听的基类脚本类型。
## [br]
## @param listener: 事件监听器契约。
## [br]
## @param priority: 回调优先级，数值越大越先执行，默认为 0。
func register_assignable_event_owned(
	listener_owner: Object,
	base_event_type: Script,
	listener: GFEventListener,
	priority: int = 0
) -> void:
	var architecture: GFArchitecture = _get_architecture_or_null()
	if architecture != null:
		architecture.register_assignable_event_owned(listener_owner, base_event_type, listener, priority)
		_remember_event_architecture(architecture)


## 注销可赋值类型事件监听器。
## [br]
## @api public
## [br]
## @since 5.0.0
## [br]
## @param base_event_type: 注册时使用的基类脚本类型。
## [br]
## @param listener: 要移除的事件监听器契约。
## [br]
## @param listener_owner: 注册监听时使用的拥有者；为空时只注销无 owner 监听。
func unregister_assignable_event(base_event_type: Script, listener: GFEventListener, listener_owner: Object = null) -> void:
	for architecture: GFArchitecture in _get_tracked_event_architectures():
		if listener_owner != null:
			architecture.unregister_assignable_event_owned(listener_owner, base_event_type, listener)
		else:
			architecture.unregister_assignable_event(base_event_type, listener)


## 注册带拥有者的轻量级 StringName 事件监听器。
## [br]
## @api public
## [br]
## @since 3.0.0
## [br]
## @param listener_owner: 监听器拥有者。
## [br]
## @param event_id: StringName 事件标识符。
## [br]
## @param listener: 简单事件监听器契约。
func register_simple_event_owned(listener_owner: Object, event_id: StringName, listener: GFEventListener) -> void:
	var architecture: GFArchitecture = _get_architecture_or_null()
	if architecture != null:
		architecture.register_simple_event_owned(listener_owner, event_id, listener)
		_remember_event_architecture(architecture)


## 注销轻量级 StringName 事件监听器。
## [br]
## @api public
## [br]
## @since 5.0.0
## [br]
## @param event_id: StringName 事件标识符。
## [br]
## @param listener: 要移除的简单事件监听器契约。
## [br]
## @param listener_owner: 注册监听时使用的拥有者；为空时只注销无 owner 监听。
func unregister_simple_event(event_id: StringName, listener: GFEventListener, listener_owner: Object = null) -> void:
	for architecture: GFArchitecture in _get_tracked_event_architectures():
		if listener_owner != null:
			architecture.unregister_simple_event_owned(listener_owner, event_id, listener)
		else:
			architecture.unregister_simple_event(event_id, listener)


## 注销指定拥有者通过状态机事件代理注册过的全部监听器。
## [br]
## @api public
## [br]
## @param listener_owner: 要清理监听器的拥有者。
func unregister_owner_events(listener_owner: Object) -> void:
	for architecture: GFArchitecture in _get_tracked_event_architectures():
		architecture.unregister_owner_events(listener_owner)


## 从子节点重新加载状态和状态组。
## [br]
## @api public
func reload_from_children() -> void:
	if _reject_mutation_during_restore(&"reload_from_children"):
		return
	if Engine.is_editor_hint():
		_queue_configuration_warning_update()
		return

	var should_preserve_state: bool = preserve_current_state_on_reload and not _groups.is_empty()
	var state_snapshot: Dictionary = _capture_state_snapshot() if should_preserve_state else {}
	_preserve_reload_state_active = should_preserve_state
	_is_reloading = true
	clear_state_groups()
	_internal_group = GFNodeStateGroup.new()
	_internal_group.name = String(INTERNAL_GROUP_NAME)
	_internal_group.set_meta(META_INTERNAL_GROUP, true)
	_internal_group.group_name = INTERNAL_GROUP_NAME
	_internal_group.initial_state = _get_effective_initial_state()
	_internal_group.initial_args = _get_effective_initial_args()
	_internal_group.history_max_size = _get_effective_history_max_size()
	_internal_group.max_stack_depth = _get_effective_max_stack_depth()
	_internal_group.reload_states_on_ready = false
	add_child(_internal_group, true, Node.INTERNAL_MODE_BACK)

	for child: Node in get_children():
		if child == _internal_group or child.get_meta(META_INTERNAL_GROUP, false):
			continue
		if _is_node_state_group(child):
			var state_group: GFNodeStateGroup = _variant_to_state_group(child)
			add_state_group(state_group)
		elif _is_node_state(child):
			var state_node: GFNodeState = _variant_to_node_state(child)
			_internal_group.add_state(state_node)

	if not _internal_group.get_states().is_empty():
		add_state_group(_internal_group)
	else:
		_free_internal_group(_internal_group)
		_internal_group = null
	_is_reloading = false
	_preserve_reload_state_active = false
	if should_preserve_state:
		var _restore_report: Dictionary = _restore_state_snapshot(state_snapshot)


## 清空所有状态组。
## [br]
## @api public
## [br]
## @param free_groups: 清理状态组时是否释放节点。
func clear_state_groups(free_groups: bool = false) -> void:
	if _reject_mutation_during_restore(&"clear_state_groups"):
		return
	var old_internal_group: GFNodeStateGroup = _internal_group
	var groups: Array[GFNodeStateGroup] = []
	for group: GFNodeStateGroup in _get_registered_groups():
		groups.append(group)
	for group: GFNodeStateGroup in groups:
		var key: StringName = _get_registered_group_key(group)
		var changed_callable: Callable = _get_dictionary_callable(_group_state_changed_callables, key)
		_disconnect_state_group_signals(group, changed_callable)
	_groups.clear()
	_group_keys_by_instance_id.clear()
	_group_state_changed_callables.clear()
	_group_state_event_handled_callables.clear()
	for group: GFNodeStateGroup in groups:
		group.stop()
		group.detach_machine()
		state_group_removed.emit(group)
		if group == _internal_group:
			_free_internal_group(group)
		elif free_groups:
			_queue_free_detached(group)
	if not groups.is_empty() or old_internal_group != null:
		_group_registry_revision += 1
	if old_internal_group != null and is_instance_valid(old_internal_group) and not groups.has(old_internal_group):
		_free_internal_group(old_internal_group)
	_internal_group = null


# --- 私有/辅助方法 ---

func _reject_mutation_during_restore(operation: StringName) -> bool:
	if not _is_restoring_state_snapshot:
		return false
	_record_restore_blocked_operation(operation)
	return true


func _record_restore_blocked_operation(operation: StringName) -> void:
	if not _restore_blocked_operations.has(operation):
		_restore_blocked_operations.append(operation)


func _record_group_restore_blocked_operation(group: GFNodeStateGroup, operation: StringName) -> void:
	if not _is_restoring_state_snapshot:
		return
	var group_key: StringName = _get_registered_group_key(group)
	_record_restore_blocked_operation(StringName("%s.%s" % [String(group_key), String(operation)]))


func _begin_group_restore_guards(groups: Array[GFNodeStateGroup]) -> void:
	for group: GFNodeStateGroup in groups:
		if is_instance_valid(group):
			group.begin_machine_restore_guard()


func _end_group_restore_guards(groups: Array[GFNodeStateGroup]) -> void:
	for group: GFNodeStateGroup in groups:
		if is_instance_valid(group):
			group.end_machine_restore_guard()


func _capture_group_registry_identity() -> Dictionary:
	var identity: Dictionary = {}
	for group_key: Variant in _groups.keys():
		var group: GFNodeStateGroup = _variant_to_state_group(_groups[group_key])
		if group != null:
			identity[group_key] = group.get_instance_id()
	return identity


func _group_registry_matches(identity: Dictionary, expected_revision: int) -> bool:
	if _group_registry_revision != expected_revision or identity.size() != _groups.size():
		return false
	for group_key: Variant in identity.keys():
		var group: GFNodeStateGroup = _variant_to_state_group(GFVariantData.get_option_value(_groups, group_key))
		if group == null or group.get_instance_id() != GFVariantData.get_option_int(identity, group_key, -1):
			return false
	return true


func _get_architecture_or_null() -> GFArchitecture:
	var context: GFNodeContext = _find_nearest_context()
	if context != null:
		var context_architecture: GFArchitecture = context.get_architecture()
		if context_architecture != null:
			return context_architecture

	return GFAutoload.get_architecture_or_null()


func _find_nearest_context() -> GFNodeContext:
	var current_node: Node = self
	while current_node != null:
		if current_node is GFNodeContext:
			var context: GFNodeContext = current_node
			return context
		current_node = current_node.get_parent()
	return null


func _remember_event_architecture(architecture: GFArchitecture) -> void:
	if architecture == null or not is_instance_valid(architecture):
		return
	for architecture_ref: WeakRef in _event_architectures:
		if architecture_ref.get_ref() == architecture:
			return
	_event_architectures.append(weakref(architecture))


func _get_tracked_event_architectures() -> Array[GFArchitecture]:
	var result: Array[GFArchitecture] = []
	var live_architectures: Array[WeakRef] = []
	for architecture_ref: WeakRef in _event_architectures:
		var architecture: GFArchitecture = _variant_to_architecture(architecture_ref.get_ref())
		if architecture != null and is_instance_valid(architecture):
			result.append(architecture)
			live_architectures.append(architecture_ref)
	_event_architectures = live_architectures
	return result


func _variant_to_architecture(value: Variant) -> GFArchitecture:
	if value is GFArchitecture:
		var architecture: GFArchitecture = value
		return architecture
	return null


func _is_node_state(node: Node) -> bool:
	return node is GFNodeState


func _is_node_state_group(node: Node) -> bool:
	return node is GFNodeStateGroup


func _connect_state_group_signals(group: GFNodeStateGroup, changed_callable: Callable) -> void:
	var changed_signal: Signal = group.current_state_changed
	var transition_signal: Signal = group.requested_transition
	if changed_callable.is_valid() and not changed_signal.is_connected(changed_callable):
		var _changed_connect_error: int = changed_signal.connect(changed_callable)
	if not transition_signal.is_connected(transition_group_to):
		var _transition_connect_error: int = transition_signal.connect(transition_group_to)
	var key: StringName = _get_registered_group_key(group)
	var handled_signal: Signal = group.state_event_handled
	var handled_callable: Callable = _on_group_state_event_handled.bind(group)
	_group_state_event_handled_callables[key] = handled_callable
	if not handled_signal.is_connected(handled_callable):
		var _handled_connect_error: int = handled_signal.connect(handled_callable)


func _disconnect_state_group_signals(group: GFNodeStateGroup, changed_callable: Callable) -> void:
	var changed_signal: Signal = group.current_state_changed
	var transition_signal: Signal = group.requested_transition
	if changed_callable.is_valid() and changed_signal.is_connected(changed_callable):
		changed_signal.disconnect(changed_callable)
	if transition_signal.is_connected(transition_group_to):
		transition_signal.disconnect(transition_group_to)
	var key: StringName = _get_registered_group_key(group)
	var handled_signal: Signal = group.state_event_handled
	var handled_callable: Callable = _get_dictionary_callable(_group_state_event_handled_callables, key)
	if handled_signal.is_connected(handled_callable):
		handled_signal.disconnect(handled_callable)
	_erase_dictionary_key(_group_state_event_handled_callables, key)


func _start_group_node(group: GFNodeStateGroup, args: Dictionary) -> void:
	if group == null:
		return
	group.start(args)


func _should_start_group_on_initialize() -> bool:
	if _preserve_reload_state_active:
		return false
	match start_mode:
		StartMode.ON_READY:
			return true
		StartMode.AFTER_HOST_READY:
			return _is_host_ready()
		StartMode.MANUAL:
			return false
		_:
			return true


func _is_host_ready() -> bool:
	var host: Node = get_parent()
	return host == null or host.is_node_ready()


func _is_lifecycle_current(lifecycle_serial: int) -> bool:
	return _lifecycle_serial == lifecycle_serial and is_inside_tree()


func _start_after_host_ready() -> void:
	var current_serial: int = _lifecycle_serial
	var host: Node = get_parent()
	if host != null and not host.is_node_ready():
		await host.ready
	if not _is_lifecycle_current(current_serial):
		return
	if start_mode != StartMode.AFTER_HOST_READY:
		return

	start()


func _on_group_current_state_changed(
	old_state: GFNodeState,
	new_state: GFNodeState,
	group: GFNodeStateGroup
) -> void:
	state_changed.emit(group, old_state, new_state)


func _on_group_state_event_handled(
	event_id: StringName,
	handler_state: GFNodeState,
	payload: Variant,
	group: GFNodeStateGroup
) -> void:
	state_event_handled.emit(group, event_id, handler_state, payload)


func _queue_reload_from_children() -> void:
	if _reject_mutation_during_restore(&"queue_reload_from_children"):
		return
	if not _is_ready or not reload_on_ready or _reload_queued or _is_reloading:
		return

	_reload_queued = true
	call_deferred("_reload_from_children_deferred")


func _free_internal_group(group: GFNodeStateGroup) -> void:
	if group == null or not is_instance_valid(group):
		return
	group.clear_states(false)
	var parent: Node = group.get_parent()
	if parent != null:
		parent.remove_child(group)
	group.free()


func _queue_free_detached(node: Node) -> void:
	if not is_instance_valid(node):
		return
	var parent: Node = node.get_parent()
	if parent != null:
		parent.remove_child(node)
	if not node.is_queued_for_deletion():
		node.queue_free()


func _is_group_in_state(group_name: StringName, state_name: StringName) -> bool:
	var group: GFNodeStateGroup = get_state_group(group_name)
	if group == null:
		return false
	return group.is_in_state(state_name)


func _get_effective_initial_state() -> StringName:
	if config != null:
		return config.initial_state
	return initial_state


func _get_effective_initial_args() -> Dictionary:
	if config != null:
		return config.initial_args
	return initial_args


func _get_effective_history_max_size() -> int:
	if config != null:
		return maxi(config.history_max_size, 1)
	return 32


func _get_effective_max_stack_depth() -> int:
	if config != null:
		return maxi(config.max_stack_depth, 1)
	return 8


func _queue_configuration_warning_update() -> void:
	if not Engine.is_editor_hint():
		return
	call_deferred("update_configuration_warnings")


func _reload_from_children_deferred() -> void:
	_reload_queued = false
	if Engine.is_editor_hint():
		_queue_configuration_warning_update()
		return
	if _is_ready and reload_on_ready:
		reload_from_children()


func _on_child_entered_tree(child: Node) -> void:
	if Engine.is_editor_hint():
		if _should_reload_for_child(child):
			_queue_configuration_warning_update()
		return

	if _should_reload_for_child(child):
		_queue_reload_from_children()


func _on_child_exiting_tree(child: Node) -> void:
	if Engine.is_editor_hint():
		if _should_reload_for_child(child):
			_queue_configuration_warning_update()
		return

	if _should_reload_for_child(child):
		_queue_reload_from_children()


func _should_reload_for_child(child: Node) -> bool:
	if child.get_meta(META_INTERNAL_GROUP, false):
		return false
	return _is_node_state(child) or _is_node_state_group(child)


func _get_registered_groups() -> Array[GFNodeStateGroup]:
	var result: Array[GFNodeStateGroup] = []
	for group_variant: Variant in _groups.values():
		var group: GFNodeStateGroup = _variant_to_state_group(group_variant)
		if group != null:
			result.append(group)
	return result


func _get_registered_group_key(group: GFNodeStateGroup) -> StringName:
	if group == null:
		return &""
	var key_value: Variant = GFVariantData.get_option_value(
		_group_keys_by_instance_id,
		group.get_instance_id(),
		group.get_group_name()
	)
	return GFVariantData.to_string_name(key_value)


func _get_dictionary_callable(source: Dictionary, key: Variant) -> Callable:
	return _variant_to_callable(GFVariantData.get_option_value(source, key, Callable()))


func _erase_dictionary_key(source: Dictionary, key: Variant) -> void:
	var _erased: bool = source.erase(key)


func _variant_to_callable(value: Variant) -> Callable:
	if value is Callable:
		return value
	return Callable()


func _variant_to_node_state(value: Variant) -> GFNodeState:
	if value is GFNodeState:
		return value
	return null


func _variant_to_state_group(value: Variant) -> GFNodeStateGroup:
	if value is GFNodeStateGroup:
		return value
	return null


func _capture_state_snapshot() -> Dictionary:
	var result: Dictionary = {}
	for group_key: Variant in _groups.keys():
		var group: GFNodeStateGroup = _variant_to_state_group(_groups[group_key])
		if group == null:
			continue
		result[group_key] = group.get_state_snapshot()
	return result


func _make_machine_restore_report() -> Dictionary:
	return {
		"report_schema_version": 2,
		"status": "failed",
		"ok": false,
		"restored": false,
		"partial": false,
		"error": "",
		"groups": {},
		"missing_group_snapshots": [],
		"unrestored_group_snapshots": [],
		"blocked_operations": [],
		"group_registry_revision_before": _group_registry_revision,
		"group_registry_revision_after": _group_registry_revision,
		"registry_stable": true,
		"rolled_back": false,
	}


func _restore_state_snapshot(snapshot: Dictionary) -> Dictionary:
	var report: Dictionary = _make_machine_restore_report()
	if _is_restoring_state_snapshot:
		_record_restore_blocked_operation(&"restore_state_snapshot")
		report["error"] = "state machine restore already in progress."
		report["blocked_operations"] = _restore_blocked_operations.duplicate()
		return report

	var group_keys: Array = _groups.keys()
	var guarded_groups: Array[GFNodeStateGroup] = _get_registered_groups()
	var registry_identity: Dictionary = _capture_group_registry_identity()
	var registry_revision_before: int = _group_registry_revision
	report["group_registry_revision_before"] = registry_revision_before
	var group_reports: Dictionary = {}
	var missing_group_snapshots: Array[StringName] = []
	var unrestored_group_snapshots: Array[StringName] = []
	for snapshot_group_key: Variant in snapshot.keys():
		if not _groups.has(snapshot_group_key):
			unrestored_group_snapshots.append(GFVariantData.to_string_name(snapshot_group_key))

	var validation_errors: Dictionary = {}
	for group_key: Variant in group_keys:
		var group: GFNodeStateGroup = _variant_to_state_group(GFVariantData.get_option_value(_groups, group_key))
		if group == null:
			validation_errors[group_key] = { "valid": false, "error": "state group is unavailable." }
			continue
		var group_snapshot: Dictionary = GFVariantData.get_option_dictionary(snapshot, group_key)
		if group_snapshot.is_empty():
			missing_group_snapshots.append(GFVariantData.to_string_name(group_key))
			continue
		var validation: Dictionary = group.validate_state_snapshot(group_snapshot)
		if not GFVariantData.get_option_bool(validation, "valid"):
			validation_errors[group_key] = validation
	if not validation_errors.is_empty():
		report["error"] = "one or more state group snapshots are invalid."
		report["groups"] = validation_errors
		report["missing_group_snapshots"] = missing_group_snapshots
		report["unrestored_group_snapshots"] = unrestored_group_snapshots
		return report

	var rollback_snapshots: Dictionary = _capture_state_snapshot()
	var restore_failed: bool = false
	var group_restore_failed: bool = false
	_restore_blocked_operations.clear()
	_is_restoring_state_snapshot = true
	_begin_group_restore_guards(guarded_groups)
	for group_key: Variant in group_keys:
		var group: GFNodeStateGroup = _variant_to_state_group(GFVariantData.get_option_value(_groups, group_key))
		if group == null:
			restore_failed = true
			group_restore_failed = true
			break
		var group_snapshot: Dictionary = GFVariantData.get_option_dictionary(snapshot, group_key)
		if group_snapshot.is_empty():
			continue
		var group_report: Dictionary = group.restore_state_snapshot(group_snapshot)
		group_reports[group_key] = group_report
		if not GFVariantData.get_option_bool(group_report, "ok"):
			restore_failed = true
			group_restore_failed = true
			break

	var registry_stable: bool = _group_registry_matches(registry_identity, registry_revision_before)
	if not registry_stable or not _restore_blocked_operations.is_empty():
		restore_failed = true
	if restore_failed:
		var rollback_succeeded: bool = true
		for rollback_group_key: Variant in group_keys:
			var rollback_group: GFNodeStateGroup = _variant_to_state_group(
				GFVariantData.get_option_value(_groups, rollback_group_key)
			)
			if rollback_group == null:
				rollback_succeeded = false
				continue
			var rollback_report: Dictionary = rollback_group.restore_state_snapshot(
				GFVariantData.get_option_dictionary(rollback_snapshots, rollback_group_key)
			)
			if not GFVariantData.get_option_bool(rollback_report, "ok"):
				rollback_succeeded = false
		if not registry_stable:
			report["error"] = "state machine group registry changed during restore."
		elif not _restore_blocked_operations.is_empty():
			report["error"] = "state machine restore blocked reentrant mutations."
		elif group_restore_failed:
			report["error"] = "state machine group restore failed."
		else:
			report["error"] = "state machine restore failed."
		report["rolled_back"] = (
			rollback_succeeded
			and _group_registry_matches(registry_identity, registry_revision_before)
		)
	else:
		var partial: bool = not missing_group_snapshots.is_empty() or not unrestored_group_snapshots.is_empty()
		for group_report_variant: Variant in group_reports.values():
			var group_report: Dictionary = GFVariantData.as_dictionary(group_report_variant)
			if GFVariantData.get_option_bool(group_report, "partial"):
				partial = true
		report["ok"] = true
		report["restored"] = true
		report["partial"] = partial
		report["status"] = "partial" if partial else "success"

	_end_group_restore_guards(guarded_groups)
	_is_restoring_state_snapshot = false
	report["groups"] = group_reports
	report["missing_group_snapshots"] = missing_group_snapshots
	report["unrestored_group_snapshots"] = unrestored_group_snapshots
	report["blocked_operations"] = _restore_blocked_operations.duplicate()
	report["group_registry_revision_after"] = _group_registry_revision
	report["registry_stable"] = _group_registry_matches(registry_identity, registry_revision_before)
	return report
