## GFCapabilityUtility: 对象能力组件管理器。
##
## 提供面向任意 Object / Node 的能力挂载、查询、移除、启停、索引查询与依赖补齐能力。
## 能力组合是可选扩展，不改变核心分层容器。
## [br]
## @api public
## [br]
## @category runtime_service
## [br]
## @since 3.17.0
class_name GFCapabilityUtility
extends GFUtility


# --- 信号 ---

## 当能力成功挂载到对象后发出。
## [br]
## @api public
## [br]
## @param receiver: 能力接收对象。
## [br]
## @param capability_type: 实际注册的能力脚本类型。
## [br]
## @param capability: 已挂载的能力实例。
signal capability_added(receiver: Object, capability_type: Script, capability: Object)

## 当能力从对象移除前发出。
## [br]
## @api public
## [br]
## @param receiver: 能力接收对象。
## [br]
## @param capability_type: 实际注册的能力脚本类型。
## [br]
## @param capability: 将被移除的能力实例。
signal capability_removed(receiver: Object, capability_type: Script, capability: Object)

## 当能力启停状态变化后发出。
## [br]
## @api public
## [br]
## @param receiver: 能力接收对象。
## [br]
## @param capability_type: 实际注册的能力脚本类型。
## [br]
## @param capability: 状态变化的能力实例。
## [br]
## @param active: 新的启用状态。
signal capability_active_changed(receiver: Object, capability_type: Script, capability: Object, active: bool)


# --- 枚举 ---

## 移除能力时自动补齐依赖的清理策略。
## [br]
## @api public
enum DependencyRemovalPolicy {
	## 保留依赖能力，适合依赖能力需要在主能力移除后继续存在的场景。
	KEEP_DEPENDENCIES,
	## 移除仅由当前能力自动补齐且未被显式添加的依赖能力。
	REMOVE_AUTO_DEPENDENCIES,
}


# --- 常量 ---

const _META_CAPABILITY_TYPES: StringName = &"_gf_capability_types"
const _META_CAPABILITY_ACTIVE: StringName = &"_gf_capability_active"
const _META_CAPABILITY_INSTANCE_PREFIX: String = "_gf_capability_"

## 识别旧场景或编辑器工具创建的能力容器节点的元数据键。
## [br]
## @api framework_internal
const META_CAPABILITY_CONTAINER: StringName = &"_gf_capability_container"
const _META_CAPABILITY_DEPENDENCIES: StringName = &"_gf_capability_dependencies"
const _META_CAPABILITY_DEPENDENCY_OF: StringName = &"_gf_capability_dependency_of"
const _META_CAPABILITY_TOP_LEVEL_TYPES: StringName = &"_gf_capability_top_level_types"
const _META_CAPABILITY_OWNED_TYPES: StringName = &"_gf_capability_owned_types"
const _META_ORIGINAL_PROCESS_MODE: StringName = &"_gf_capability_original_process_mode"

## 能力对象可选实现：返回运行时依赖的能力类型列表。
## [br]
## @api public
const HOOK_GET_REQUIRED_CAPABILITIES: StringName = &"get_required_capabilities"

## 能力对象可选实现：返回自动依赖能力的移除策略。
## [br]
## @api public
const HOOK_GET_DEPENDENCY_REMOVAL_POLICY: StringName = &"get_dependency_removal_policy"

## 能力对象可选实现：挂载到 receiver 后调用。
## [br]
## @api public
const HOOK_ON_ADDED: StringName = &"on_gf_capability_added"

## 能力对象可选实现：从 receiver 移除前调用。
## [br]
## @api public
const HOOK_ON_REMOVED: StringName = &"on_gf_capability_removed"

## 能力对象可选实现：启停状态变化后调用。
## [br]
## @api public
const HOOK_ON_ACTIVE_CHANGED: StringName = &"on_gf_capability_active_changed"
const _GF_CAPABILITY_CONTAINER_SCRIPT = preload("res://addons/gf/extensions/capability/nodes/gf_capability_container.gd")
const _INSTANCE_GUARD: Script = preload("res://addons/gf/kernel/core/gf_instance_guard.gd")
const _SCRIPT_TYPE_INSPECTOR: Script = preload("res://addons/gf/kernel/core/gf_script_type_inspector.gd")


# --- 公共变量 ---

## tick() 自动清理失效 receiver 时每次最多检查的数量，避免大型索引在单帧产生尖峰。
## 主动调用 prune_invalid_receivers() 仍会执行全量清理。
## [br]
## @api public
var prune_invalid_receivers_per_tick: int = 128:
	set(value):
		prune_invalid_receivers_per_tick = maxi(value, 1)


# --- 私有变量 ---

var _creation_stack: Array[String] = []
var _receiver_refs: Dictionary = {}
var _capability_receivers: Dictionary = {}
var _receiver_groups: Dictionary = {}
var _receiver_group_names: Dictionary = {}
var _scene_container_sync_receivers: Dictionary = {}
var _elapsed_since_prune: float = 0.0
var _prune_receiver_cursor: int = 0


# --- GF 生命周期方法 ---

## 初始化能力管理器的运行时游标。
## [br]
## @api public
func init() -> void:
	_elapsed_since_prune = 0.0
	_prune_receiver_cursor = 0


## 注销已索引 receiver 上的能力并清理分组状态。
##
## 由本 Utility 创建或 PackedScene 实例化的能力会随架构销毁释放；外部传入或场景中已有的能力只注销，不抢占其节点所有权。
## [br]
## @api public
func dispose() -> void:
	_dispose_registered_capabilities()
	_creation_stack.clear()
	_receiver_refs.clear()
	_capability_receivers.clear()
	_receiver_groups.clear()
	_receiver_group_names.clear()
	_scene_container_sync_receivers.clear()
	_elapsed_since_prune = 0.0
	_prune_receiver_cursor = 0


## 推进运行时逻辑。
## [br]
## @api public
## [br]
## @param delta: 本帧时间增量（秒）。
func tick(delta: float) -> void:
	if delta < 0.0:
		return

	_elapsed_since_prune += delta
	if _elapsed_since_prune < 1.0:
		return

	_elapsed_since_prune = 0.0
	_prune_invalid_receivers_step(prune_invalid_receivers_per_tick)


# --- 公共方法 ---

## 检查对象是否拥有指定能力。
## [br]
## @api public
## [br]
## @param receiver: 能力接收对象。
## [br]
## @param capability_type: 要查询、添加或移除的能力脚本类型。
## [br]
## @return: 拥有该能力或其唯一子类能力时返回 true。
func has_capability(receiver: Object, capability_type: Script) -> bool:
	return get_capability(receiver, capability_type) != null


## 获取对象上的指定能力。
## 未命中精确类型时，会尝试寻找唯一的子类能力。
## [br]
## @api public
## [br]
## @param receiver: 能力接收对象。
## [br]
## @param capability_type: 要查询、添加或移除的能力脚本类型。
## [br]
## @return: 匹配的能力实例；未命中或匹配不唯一时返回 null。
func get_capability(receiver: Object, capability_type: Script) -> Object:
	var record: Dictionary = _find_capability_record(receiver, capability_type)
	if record.is_empty():
		return null
	return _get_object_value(GFVariantData.get_option_value(record, "instance"))


## 获取对象当前拥有的所有能力类型。
## [br]
## @api public
## [br]
## @param receiver: 能力接收对象。
## [br]
## @return: 当前注册的能力脚本类型列表。
## [br]
## @schema return: Array[Script]，元素为 receiver 上当前注册的能力脚本类型。
func get_capability_types(receiver: Object) -> Array[Script]:
	if not is_instance_valid(receiver):
		return _empty_script_array()

	return _get_capability_type_list(receiver).duplicate()


## 获取所有拥有指定能力的 receiver。
## [br]
## @api public
## [br]
## @param capability_type: 要查询的能力脚本类型。
## [br]
## @param include_subclasses: 为 true 时同时匹配指定能力的子类能力。
## [br]
## @return: 当前拥有该能力的 receiver 列表。
## [br]
## @schema return: Array[Object]，元素为当前仍有效的能力接收对象。
func get_receivers_with(capability_type: Script, include_subclasses: bool = true) -> Array[Object]:
	if capability_type == null:
		return _empty_object_array()

	_prune_invalid_receivers()
	var result: Array[Object] = []
	var seen_ids: Dictionary = {}
	for registered_type: Script in _get_indexed_capability_types(capability_type, include_subclasses):
		var receiver_ids: Dictionary = _get_dictionary_ref(_capability_receivers, registered_type)
		for receiver_id: int in receiver_ids:
			if seen_ids.has(receiver_id):
				continue
			var receiver: Object = _get_receiver_from_id(receiver_id)
			if receiver != null and _get_capability_instance(receiver, registered_type) != null:
				seen_ids[receiver_id] = true
				result.append(receiver)
	return result


## 主动清理已经失效的 receiver 弱引用与反向索引。
## [br]
## @api public
func prune_invalid_receivers() -> void:
	_prune_invalid_receivers()


## 获取当前已挂载的指定能力实例列表。
## [br]
## @api public
## [br]
## @param capability_type: 要查询的能力脚本类型。
## [br]
## @param include_subclasses: 为 true 时同时返回指定能力的子类能力实例。
## [br]
## @return: 匹配的能力实例列表。
## [br]
## @schema return: Array[Object]，元素为当前仍有效的能力实例。
func get_capabilities(capability_type: Script, include_subclasses: bool = true) -> Array[Object]:
	if capability_type == null:
		return _empty_object_array()

	_prune_invalid_receivers()
	var result: Array[Object] = []
	var seen_ids: Dictionary = {}
	for registered_type: Script in _get_indexed_capability_types(capability_type, include_subclasses):
		var receiver_ids: Dictionary = _get_dictionary_ref(_capability_receivers, registered_type)
		for receiver_id: int in receiver_ids:
			var receiver: Object = _get_receiver_from_id(receiver_id)
			if receiver == null:
				continue
			var capability: Object = _get_capability_instance(receiver, registered_type)
			if capability != null and not seen_ids.has(capability.get_instance_id()):
				seen_ids[capability.get_instance_id()] = true
				result.append(capability)
	return result


## 把 receiver 加入一个能力查询分组。
## [br]
## @api public
## [br]
## @param receiver: 能力接收对象。
## [br]
## @param group_name: 能力组或状态组名称。
func add_receiver_to_group(receiver: Object, group_name: StringName) -> void:
	if not is_instance_valid(receiver) or group_name == &"":
		return

	var receiver_id: int = _track_receiver(receiver)
	var group_receivers: Dictionary = _get_group_receiver_ids(group_name)
	group_receivers[receiver_id] = true

	if not _receiver_group_names.has(receiver_id):
		_receiver_group_names[receiver_id] = {}
	var group_names: Dictionary = GFVariantData.as_dictionary(_receiver_group_names[receiver_id])
	group_names[group_name] = true


## 从一个能力查询分组移除 receiver。
## [br]
## @api public
## [br]
## @param receiver: 能力接收对象。
## [br]
## @param group_name: 能力组或状态组名称。
func remove_receiver_from_group(receiver: Object, group_name: StringName) -> void:
	if not is_instance_valid(receiver) or group_name == &"":
		return

	var receiver_id: int = receiver.get_instance_id()
	if _receiver_groups.has(group_name):
		var group_receivers: Dictionary = GFVariantData.as_dictionary(_receiver_groups[group_name])
		_erase_dictionary_key(group_receivers, receiver_id)
		if group_receivers.is_empty():
			_erase_dictionary_key(_receiver_groups, group_name)

	if _receiver_group_names.has(receiver_id):
		var group_names: Dictionary = GFVariantData.as_dictionary(_receiver_group_names[receiver_id])
		_erase_dictionary_key(group_names, group_name)
		if group_names.is_empty():
			_erase_dictionary_key(_receiver_group_names, receiver_id)


## 获取 receiver 当前所属的能力查询分组。
## [br]
## @api public
## [br]
## @param receiver: 能力接收对象。
## [br]
## @return: receiver 当前所属的分组名称。
## [br]
## @schema return: Array[StringName]，元素为能力查询分组名称。
func get_receiver_groups(receiver: Object) -> Array[StringName]:
	if not is_instance_valid(receiver):
		return _empty_string_name_array()

	var receiver_id: int = receiver.get_instance_id()
	if not _receiver_group_names.has(receiver_id):
		return _empty_string_name_array()

	var result: Array[StringName] = []
	for group_name: StringName in GFVariantData.as_dictionary(_receiver_group_names[receiver_id]):
		_append_string_name_item(result, group_name)
	return result


## 获取指定分组内的 receiver。
## [br]
## @api public
## [br]
## @param group_name: 能力组或状态组名称。
## [br]
## @return: 分组内仍有效的 receiver 列表。
## [br]
## @schema return: Array[Object]，元素为当前仍有效的能力接收对象。
func get_receivers_in_group(group_name: StringName) -> Array[Object]:
	if group_name == &"":
		return _empty_object_array()

	_prune_invalid_receivers()
	var result: Array[Object] = []
	var group_receivers: Dictionary = _get_dictionary_ref(_receiver_groups, group_name)
	for receiver_id: int in group_receivers:
		var receiver: Object = _get_receiver_from_id(receiver_id)
		if receiver != null:
			result.append(receiver)
	return result


## 获取指定分组内拥有某个能力的 receiver。
## [br]
## @api public
## [br]
## @param group_name: 能力组或状态组名称。
## [br]
## @param capability_type: 要查询、添加或移除的能力脚本类型。
## [br]
## @param include_subclasses: 为 true 时同时匹配指定类型的子类。
## [br]
## @return: 分组内拥有该能力的 receiver 列表。
## [br]
## @schema return: Array[Object]，元素为当前仍有效的能力接收对象。
func get_receivers_in_group_with(
	group_name: StringName,
	capability_type: Script,
	include_subclasses: bool = true
) -> Array[Object]:
	if group_name == &"" or capability_type == null:
		return _empty_object_array()

	_prune_invalid_receivers()
	var result: Array[Object] = []
	var group_receivers: Dictionary = _get_dictionary_ref(_receiver_groups, group_name)
	for receiver: Object in get_receivers_with(capability_type, include_subclasses):
		if group_receivers.has(receiver.get_instance_id()):
			result.append(receiver)
	return result


## 给对象挂载指定能力类型。
## provider 可为 Callable、PackedScene、Object；为空时使用 capability_type.new()。
## [br]
## @api public
## [br]
## @param receiver: 能力接收对象。
## [br]
## @param capability_type: 要查询、添加或移除的能力脚本类型。
## [br]
## @param provider: 用于创建能力实例的 provider。
## [br]
## @return: 已挂载或复用的能力实例；失败时返回 null。
## [br]
## @schema provider: Variant，可为 null、Callable、PackedScene 或 Object 能力实例。
func add_capability(receiver: Object, capability_type: Script, provider: Variant = null) -> Object:
	return _add_capability(receiver, capability_type, provider, true)


## 给对象挂载指定能力类型，并标记为自动依赖能力。
## [br]
## @api public
## [br]
## @param receiver: 能力接收对象。
## [br]
## @param capability_type: 要查询、添加或移除的能力脚本类型。
## [br]
## @param provider: 用于创建能力实例的 provider。
## [br]
## @return: 已挂载或复用的能力实例；失败时返回 null。
## [br]
## @schema provider: Variant，可为 null、Callable、PackedScene 或 Object 能力实例。
func add_required_capability(receiver: Object, capability_type: Script, provider: Variant = null) -> Object:
	return _add_capability(receiver, capability_type, provider, false)


## 给对象挂载一个已经存在的能力实例。
##
## 该入口不会接管传入实例的所有权；架构销毁时只注销能力记录。需要由 Utility 创建并接管节点释放时，请使用 add_capability() 或 add_scene_capability()。
## [br]
## @api public
## [br]
## @param receiver: 能力接收对象。
## [br]
## @param capability: 要挂载的能力实例。
## [br]
## @param as_type: 能力实例注册时使用的类型；为 null 时使用实例脚本类型。
## [br]
## @return: 已挂载或复用的能力实例；失败时返回 null。
func add_capability_instance(receiver: Object, capability: Object, as_type: Script = null) -> Object:
	return _add_capability_instance(receiver, capability, as_type, false)


## 实例化 PackedScene 并作为能力挂载。
## [br]
## @api public
## [br]
## @param receiver: 能力接收对象。
## [br]
## @param scene: 要实例化的能力场景资源。
## [br]
## @param as_type: 能力实例注册时使用的类型；为 null 时使用实例脚本类型。
## [br]
## @return: 已挂载的能力节点；失败时返回 null。
func add_scene_capability(receiver: Node, scene: PackedScene, as_type: Script = null) -> Object:
	if not is_instance_valid(receiver):
		push_error("[GFCapabilityUtility] add_scene_capability 失败：receiver 无效。")
		return null
	if not is_instance_valid(scene):
		push_error("[GFCapabilityUtility] add_scene_capability 失败：scene 无效。")
		return null

	var node: Node = _get_node_value(scene.instantiate())
	if node == null:
		push_error("[GFCapabilityUtility] add_scene_capability 失败：scene 根节点必须是 Node。")
		return null

	var registered: Object = _add_capability_instance(receiver, node, as_type, true)
	if registered != node:
		_free_unregistered_capability(node)
	return registered


## 设置对象上指定能力的启停状态。
## [br]
## @api public
## [br]
## @param receiver: 能力接收对象。
## [br]
## @param capability_type: 要查询、添加或移除的能力脚本类型。
## [br]
## @param active: 要设置的激活状态。
func set_capability_active(receiver: Object, capability_type: Script, active: bool) -> void:
	var record: Dictionary = _find_capability_record(receiver, capability_type)
	if record.is_empty():
		return

	var registered_type: Script = _get_script_value(GFVariantData.get_option_value(record, "type"))
	var capability: Object = _get_object_value(GFVariantData.get_option_value(record, "instance"))
	if capability == null:
		return

	if _read_capability_active(capability) == active:
		return

	_apply_capability_active_state(receiver, capability, active, true)
	capability_active_changed.emit(receiver, registered_type, capability, active)


## 查询对象上指定能力当前是否启用。
## [br]
## @api public
## [br]
## @param receiver: 能力接收对象。
## [br]
## @param capability_type: 要查询、添加或移除的能力脚本类型。
## [br]
## @return: 能力存在且处于启用状态时返回 true。
func is_capability_active(receiver: Object, capability_type: Script) -> bool:
	var record: Dictionary = _find_capability_record(receiver, capability_type)
	if record.is_empty():
		return false

	var capability: Object = _get_object_value(GFVariantData.get_option_value(record, "instance"))
	if capability == null:
		return false
	return _read_capability_active(capability)


## 从对象移除指定能力。
## [br]
## @api public
## [br]
## @param receiver: 能力接收对象。
## [br]
## @param capability_type: 要查询、添加或移除的能力脚本类型。
func remove_capability(receiver: Object, capability_type: Script) -> void:
	_remove_capability(receiver, capability_type, true)


## 从对象注销指定能力，但不释放能力实例。
## [br]
## @api public
## [br]
## @param receiver: 能力接收对象。
## [br]
## @param capability_type: 要查询、添加或移除的能力脚本类型。
func unregister_capability(receiver: Object, capability_type: Script) -> void:
	_remove_capability(receiver, capability_type, false)


## 清空对象上的所有能力。
## [br]
## @api public
## [br]
## @param receiver: 能力接收对象。
func clear_capabilities(receiver: Object) -> void:
	if not is_instance_valid(receiver):
		return

	var capability_types: Array[Script] = get_capability_types(receiver)
	for capability_type: Script in capability_types:
		remove_capability(receiver, capability_type)


## 清空 receiver 所属的所有能力查询分组。
## [br]
## @api public
## [br]
## @param receiver: 能力接收对象。
func clear_receiver_groups(receiver: Object) -> void:
	if not is_instance_valid(receiver):
		return

	var group_names: Array[StringName] = get_receiver_groups(receiver)
	for group_name: StringName in group_names:
		remove_receiver_from_group(receiver, group_name)


## 把能力组合 Recipe 应用到 receiver。
## [br]
## @api public
## [br]
## @param receiver: 能力接收对象。
## [br]
## @param recipe: 能力组合资源。
## [br]
## @param options: 可选参数，支持 skip_groups、validate_after_apply 与 transactional。
## [br]
## @return 应用报告。
## [br]
## @schema options: Dictionary，可包含 skip_groups、validate_after_apply、transactional 布尔选项。
## [br]
## @schema return: Dictionary，包含 ok、recipe_id、added、reused、failed、groups、dependency_validation 与 rolled_back。
func apply_recipe(receiver: Object, recipe: GFCapabilityRecipe, options: Dictionary = {}) -> Dictionary:
	var result: Dictionary = {
		"ok": true,
		"recipe_id": recipe.recipe_id if recipe != null else &"",
		"added": [],
		"reused": [],
		"failed": [],
		"groups": [],
		"dependency_validation": {},
		"rolled_back": false,
	}
	if not is_instance_valid(receiver):
		result["ok"] = false
		_append_report_array_item(result, "failed", {
			"kind": "invalid_receiver",
			"message": "Receiver is invalid.",
		})
		return result
	if recipe == null:
		result["ok"] = false
		_append_report_array_item(result, "failed", {
			"kind": "invalid_recipe",
			"message": "Recipe is null.",
		})
		return result

	var transactional: bool = GFVariantData.get_option_bool(options, "transactional", true)
	var added_types: Array[Script] = []
	var newly_added_groups: Array[StringName] = []
	var reused_active_states: Dictionary = {}
	if not GFVariantData.get_option_bool(options, "skip_groups", false):
		for group_name: StringName in recipe.groups:
			if group_name == &"":
				continue
			var had_group: bool = get_receiver_groups(receiver).has(group_name)
			add_receiver_to_group(receiver, group_name)
			if not had_group:
				newly_added_groups.append(group_name)
			_append_report_array_item(result, "groups", group_name)

	for index: int in range(recipe.entries.size()):
		var entry: GFCapabilityRecipeEntry = recipe.entries[index]
		_apply_recipe_entry(receiver, entry, index, result, added_types, reused_active_states)
		if transactional and not GFVariantData.get_option_array(result, "failed").is_empty():
			break

	if GFVariantData.get_option_bool(options, "validate_after_apply", true):
		var validation: Dictionary = validate_receiver_dependencies(receiver)
		result["dependency_validation"] = validation
		if not GFVariantData.get_option_bool(validation, "ok", false):
			result["ok"] = false

	if not GFVariantData.get_option_array(result, "failed").is_empty():
		result["ok"] = false
	if transactional and not GFVariantData.get_option_bool(result, "ok", false):
		_rollback_recipe_apply(receiver, added_types, newly_added_groups, reused_active_states)
		result["rolled_back"] = true
	return result


## 移除 Recipe 描述的能力和可选分组。
## [br]
## @api public
## [br]
## @param receiver: 能力接收对象。
## [br]
## @param recipe: 能力组合资源。
## [br]
## @param remove_groups: 是否同步移除 Recipe groups。
## [br]
## @return 移除报告。
## [br]
## @schema return: Dictionary，包含 ok、recipe_id、removed、skipped 和 groups_removed。
func remove_recipe(receiver: Object, recipe: GFCapabilityRecipe, remove_groups: bool = true) -> Dictionary:
	var result: Dictionary = {
		"ok": true,
		"recipe_id": recipe.recipe_id if recipe != null else &"",
		"removed": [],
		"skipped": [],
		"groups_removed": [],
	}
	if not is_instance_valid(receiver) or recipe == null:
		result["ok"] = false
		return result

	for index: int in range(recipe.entries.size() - 1, -1, -1):
		var entry: GFCapabilityRecipeEntry = recipe.entries[index]
		var capability_type: Script = _resolve_recipe_entry_type(receiver, entry)
		if capability_type == null:
			_append_report_array_item(result, "skipped", {
				"index": index,
				"kind": "unknown_type",
			})
			continue
		if not has_capability(receiver, capability_type):
			_append_report_array_item(result, "skipped", {
				"index": index,
				"type": _get_script_key(capability_type),
				"kind": "missing_capability",
			})
			continue

		remove_capability(receiver, capability_type)
		_append_report_array_item(result, "removed", {
			"index": index,
			"type": _get_script_key(capability_type),
		})

	if remove_groups:
		for group_name: StringName in recipe.groups:
			if group_name == &"":
				continue
			remove_receiver_from_group(receiver, group_name)
			_append_report_array_item(result, "groups_removed", group_name)
	return result


## 检查 receiver 上能力依赖是否完整。
## [br]
## @api public
## [br]
## @param receiver: 目标对象。
## [br]
## @return 统一检查结果，包含 ok 与 missing_dependencies。
## [br]
## @schema return: Dictionary，包含 ok 与 missing_dependencies；missing_dependencies 为缺失依赖记录数组。
func validate_receiver_dependencies(receiver: Object) -> Dictionary:
	var report: Dictionary = inspect_receiver(receiver)
	return {
		"ok": GFVariantData.get_option_bool(report, "ok", false),
		"missing_dependencies": GFVariantData.get_option_array(report, "missing_dependencies"),
	}


## 获取 receiver 能力诊断报告。
## [br]
## @api public
## [br]
## @param receiver: 目标对象。
## [br]
## @return 能力、依赖、缺失项和分组信息。
## [br]
## @schema return: Dictionary，包含 ok、error、receiver_id、capability_count、capabilities、missing_dependencies 和 groups。
func inspect_receiver(receiver: Object) -> Dictionary:
	if not is_instance_valid(receiver):
		return {
			"ok": false,
			"error": "Receiver is invalid.",
			"receiver_id": -1,
			"capability_count": 0,
			"capabilities": [],
			"missing_dependencies": [],
			"groups": [],
		}

	var capability_reports: Array[Dictionary] = []
	var missing_dependencies: Array[Dictionary] = []
	for capability_type: Script in get_capability_types(receiver):
		var capability: Object = _get_capability_instance(receiver, capability_type)
		if capability == null:
			continue

		var required_types: Array[Script] = _get_required_capabilities(capability)
		var missing_for_capability: Array[Dictionary] = []
		for required_type: Script in required_types:
			if get_capability(receiver, required_type) != null:
				continue
			var missing_entry: Dictionary = {
				"capability": _get_script_key(capability_type),
				"required": _get_script_key(required_type),
			}
			missing_for_capability.append(missing_entry)
			missing_dependencies.append(missing_entry)

		capability_reports.append({
			"type": _get_script_key(capability_type),
			"active": _read_capability_active(capability),
			"top_level": _is_capability_top_level(receiver, capability_type),
			"required": _script_array_to_keys(required_types),
			"registered_dependencies": _script_array_to_keys(_get_dependency_types(receiver, capability_type)),
			"dependency_of": _script_array_to_keys(_get_dependency_owner_types(receiver, capability_type)),
			"missing_dependencies": missing_for_capability,
		})

	return {
		"ok": missing_dependencies.is_empty(),
		"error": "",
		"receiver_id": receiver.get_instance_id(),
		"capability_count": capability_reports.size(),
		"capabilities": capability_reports,
		"missing_dependencies": missing_dependencies,
		"groups": get_receiver_groups(receiver),
	}


# --- 私有/辅助方法 ---

func _get_script_array_value(value: Variant) -> Array[Script]:
	var result: Array[Script] = []
	if value is Array:
		for item: Variant in GFVariantData.as_array(value):
			if item is Script:
				_append_script_item(result, _get_script_value(item))
	return result


func _empty_script_array() -> Array[Script]:
	var result: Array[Script] = []
	return result


func _empty_object_array() -> Array[Object]:
	var result: Array[Object] = []
	return result


func _empty_string_name_array() -> Array[StringName]:
	var result: Array[StringName] = []
	return result


func _get_dictionary_ref(source: Dictionary, key: Variant) -> Dictionary:
	return GFVariantData.as_dictionary(GFVariantData.get_option_value(source, key, {}))


func _to_process_mode(value: int) -> Node.ProcessMode:
	match value:
		Node.PROCESS_MODE_PAUSABLE:
			return Node.PROCESS_MODE_PAUSABLE
		Node.PROCESS_MODE_WHEN_PAUSED:
			return Node.PROCESS_MODE_WHEN_PAUSED
		Node.PROCESS_MODE_ALWAYS:
			return Node.PROCESS_MODE_ALWAYS
		Node.PROCESS_MODE_DISABLED:
			return Node.PROCESS_MODE_DISABLED
		_:
			return Node.PROCESS_MODE_INHERIT


func _get_object_value(value: Variant) -> Object:
	if value is Object:
		return value
	return null


func _get_node_value(value: Variant) -> Node:
	if value is Node:
		return value
	return null


func _get_script_value(value: Variant) -> Script:
	if value is Script:
		return value
	return null


func _get_weak_ref_value(value: Variant) -> WeakRef:
	if value is WeakRef:
		return value
	return null


func _get_callable_value(value: Variant) -> Callable:
	if value is Callable:
		return value
	return Callable()


func _get_packed_scene_value(value: Variant) -> PackedScene:
	if value is PackedScene:
		return value
	return null


func _erase_dictionary_key(target: Dictionary, key: Variant) -> void:
	var removed: bool = target.erase(key)
	if removed:
		return


func _append_report_array_item(report: Dictionary, key: String, value: Variant) -> void:
	var items: Array = GFVariantData.as_array(GFVariantData.get_option_value(report, key, []))
	items.append(value)
	report[key] = items


func _append_script_item(target: Array[Script], value: Script) -> void:
	target.append(value)


func _append_string_name_item(target: Array[StringName], value: StringName) -> void:
	target.append(value)


func _append_object_item(target: Array[Object], value: Object) -> void:
	target.append(value)


func _append_dictionary_item(target: Array[Dictionary], value: Dictionary) -> void:
	target.append(value)


func _append_packed_string(target: PackedStringArray, value: String) -> void:
	var appended: bool = target.append(value)
	if appended:
		return


func _script_extends_or_equals(script: Script, base_script: Script) -> bool:
	return GFVariantData.to_bool(_SCRIPT_TYPE_INSPECTOR.call("script_extends_or_equals", script, base_script))


func _get_live_object_value(value: Variant) -> Object:
	return _get_object_value(_INSTANCE_GUARD.call("_get_live_object", value))


func _get_live_object_from_ref(receiver_ref: WeakRef) -> Object:
	return _get_object_value(_INSTANCE_GUARD.call("_get_live_object_from_ref", receiver_ref))


func _get_live_node_from_instance_id(instance_id: int) -> Node:
	return _get_node_value(_INSTANCE_GUARD.call("_get_live_node_from_id", instance_id))


func _dispose_registered_capabilities() -> void:
	var receiver_ids: Array = _receiver_refs.keys()
	for receiver_id_variant: Variant in receiver_ids:
		var receiver_id: int = GFVariantData.to_int(receiver_id_variant)
		var receiver: Object = _get_receiver_from_id(receiver_id)
		if receiver == null:
			continue
		_dispose_receiver_capabilities(receiver)


func _dispose_receiver_capabilities(receiver: Object) -> void:
	if not is_instance_valid(receiver):
		return

	var capability_types: Array[Script] = _get_capability_type_list(receiver).duplicate()
	for capability_type: Script in capability_types:
		var record: Dictionary = _find_capability_record(receiver, capability_type, false)
		if record.is_empty():
			continue

		var registered_type: Script = _get_script_value(GFVariantData.get_option_value(record, "type"))
		var capability: Object = _get_object_value(GFVariantData.get_option_value(record, "instance"))
		var owns_instance: bool = _owns_capability_instance(receiver, registered_type)
		_call_removed_hook(receiver, capability)
		_set_capability_receiver(capability, null)
		_remove_capability_record(receiver, registered_type)
		_remove_dependency_links(receiver, registered_type)
		capability_removed.emit(receiver, registered_type, capability)
		if owns_instance:
			_free_registered_capability(capability)

	_clear_empty_capability_metadata(receiver)


func _remove_capability(receiver: Object, capability_type: Script, free_instance: bool) -> void:
	var record: Dictionary = _find_capability_record(receiver, capability_type)
	if record.is_empty():
		return

	var registered_type: Script = _get_script_value(GFVariantData.get_option_value(record, "type"))
	var capability: Object = _get_object_value(GFVariantData.get_option_value(record, "instance"))
	var dependency_types: Array[Script] = _get_dependency_types(receiver, registered_type)
	var dependency_removal_policy: int = _get_dependency_removal_policy(capability)
	_call_removed_hook(receiver, capability)
	_set_capability_receiver(capability, null)
	_remove_capability_record(receiver, registered_type)
	_remove_dependency_links(receiver, registered_type)
	capability_removed.emit(receiver, registered_type, capability)
	if free_instance:
		_free_registered_capability(capability)
	if dependency_removal_policy == DependencyRemovalPolicy.REMOVE_AUTO_DEPENDENCIES:
		_remove_unused_auto_dependencies(receiver, dependency_types)


func _apply_recipe_entry(
	receiver: Object,
	entry: GFCapabilityRecipeEntry,
	index: int,
	result: Dictionary,
	added_types: Array[Script],
	reused_active_states: Dictionary
) -> void:
	if entry == null:
		_append_recipe_failure(result, index, "null_entry", "Recipe entry is null.")
		return
	if not entry.is_valid_entry():
		_append_recipe_failure(result, index, "invalid_entry", "Recipe entry requires capability_type or scene.")
		return

	var before_types: Array[Script] = _get_capability_type_list(receiver).duplicate()
	var capability_type: Script = entry.capability_type
	var capability: Object = null
	if entry.scene != null:
		if not (receiver is Node):
			_append_recipe_failure(result, index, "scene_requires_node", "Scene capability requires a Node receiver.")
			return
		var receiver_node: Node = receiver
		capability = add_scene_capability(receiver_node, entry.scene, capability_type)
	else:
		capability = add_capability(receiver, capability_type)

	if capability == null:
		_append_recipe_failure(result, index, "add_failed", "Capability could not be added.")
		return

	if capability_type == null:
		capability_type = _get_script_value(capability.get_script())
	var had_capability: bool = capability_type != null and before_types.has(capability_type)
	if had_capability and not reused_active_states.has(capability_type):
		reused_active_states[capability_type] = is_capability_active(receiver, capability_type)
	if capability_type != null:
		set_capability_active(receiver, capability_type, entry.active)

	var entry_report: Dictionary = {
		"index": index,
		"type": _get_script_key(capability_type),
		"active": entry.active,
		"metadata": entry.metadata.duplicate(true),
	}
	if had_capability:
		_append_report_array_item(result, "reused", entry_report)
	else:
		if capability_type != null and not added_types.has(capability_type):
			added_types.append(capability_type)
		_append_report_array_item(result, "added", entry_report)


func _rollback_recipe_apply(
	receiver: Object,
	added_types: Array[Script],
	newly_added_groups: Array[StringName],
	reused_active_states: Dictionary
) -> void:
	for index: int in range(added_types.size() - 1, -1, -1):
		var capability_type: Script = added_types[index]
		if capability_type != null and has_capability(receiver, capability_type):
			remove_capability(receiver, capability_type)
	for capability_type_variant: Variant in reused_active_states.keys():
		var capability_type: Script = _get_script_value(capability_type_variant)
		if capability_type != null and has_capability(receiver, capability_type):
			set_capability_active(receiver, capability_type, GFVariantData.to_bool(reused_active_states[capability_type_variant]))
	for group_name: StringName in newly_added_groups:
		remove_receiver_from_group(receiver, group_name)


func _append_recipe_failure(result: Dictionary, index: int, kind: String, message: String) -> void:
	_append_report_array_item(result, "failed", {
		"index": index,
		"kind": kind,
		"message": message,
	})


func _resolve_recipe_entry_type(receiver: Object, entry: GFCapabilityRecipeEntry) -> Script:
	if entry == null:
		return null
	if entry.capability_type != null:
		return entry.capability_type
	if not is_instance_valid(receiver):
		return null
	if entry.scene == null:
		return null
	return _get_packed_scene_root_script(entry.scene)


func _get_packed_scene_root_script(scene: PackedScene) -> Script:
	if scene == null:
		return null

	var state: SceneState = scene.get_state()
	if state == null:
		return null

	for node_index: int in range(state.get_node_count()):
		if not state.get_node_path(node_index, true).is_empty():
			continue

		for property_index: int in range(state.get_node_property_count(node_index)):
			if state.get_node_property_name(node_index, property_index) == &"script":
				return _get_script_value(state.get_node_property_value(node_index, property_index))
	return null


func _add_capability(receiver: Object, capability_type: Script, provider: Variant = null, is_top_level: bool = true) -> Object:
	if not _validate_receiver_and_type(receiver, capability_type, "add_capability"):
		return null

	var existing: Object = get_capability(receiver, capability_type)
	if existing != null:
		if is_top_level:
			_mark_capability_top_level(receiver, capability_type, true)
		return existing

	var creation_key: String = _get_creation_key(receiver, capability_type)
	if _creation_stack.has(creation_key):
		push_error("[GFCapabilityUtility] 检测到循环能力依赖：%s" % _describe_creation_stack(creation_key))
		return null

	_creation_stack.append(creation_key)
	var owns_instance: bool = _should_own_created_capability(provider)
	var capability: Object = _create_capability(capability_type, provider)
	if capability == null:
		_creation_stack.pop_back()
		return null

	var dependency_result: Dictionary = _ensure_required_capabilities(receiver, capability)
	if not GFVariantData.get_option_bool(dependency_result, "ok", false):
		_rollback_created_dependencies(receiver, GFVariantData.get_option_array(dependency_result, "created_types"))
		if owns_instance:
			_free_unregistered_capability(capability)
		_creation_stack.pop_back()
		return null

	_register_capability(receiver, capability_type, capability, is_top_level, owns_instance)
	for dependency_type: Script in _get_script_array_value(GFVariantData.get_option_value(dependency_result, "types", [])):
		_record_dependency(receiver, capability_type, dependency_type)
	_creation_stack.pop_back()
	return capability


func _add_capability_instance(
	receiver: Object,
	capability: Object,
	as_type: Script = null,
	owns_instance: bool = false
) -> Object:
	if not is_instance_valid(receiver):
		push_error("[GFCapabilityUtility] add_capability_instance 失败：receiver 无效。")
		return null
	if not is_instance_valid(capability):
		push_error("[GFCapabilityUtility] add_capability_instance 失败：capability 无效。")
		return null

	var capability_type: Script = as_type
	if capability_type == null:
		capability_type = _get_script_value(capability.get_script())
	if capability_type == null:
		push_error("[GFCapabilityUtility] add_capability_instance 失败：能力实例缺少脚本类型。")
		return null

	if not _can_attach_capability_instance(receiver, capability):
		return null

	var existing_record: Dictionary = _find_capability_record(receiver, capability_type, false)
	var existing: Object = _get_object_value(GFVariantData.get_option_value(existing_record, "instance"))
	if existing != null:
		if existing == capability:
			_mark_capability_top_level(receiver, capability_type, true)
			return capability
		push_warning("[GFCapabilityUtility] add_capability_instance：目标对象已拥有该能力，已忽略新实例。")
		_mark_capability_top_level(receiver, capability_type, true)
		return existing

	var dependency_result: Dictionary = _ensure_required_capabilities(receiver, capability)
	if not GFVariantData.get_option_bool(dependency_result, "ok", false):
		_rollback_created_dependencies(receiver, GFVariantData.get_option_array(dependency_result, "created_types"))
		return null

	_register_capability(receiver, capability_type, capability, true, owns_instance)
	for dependency_type: Script in _get_script_array_value(GFVariantData.get_option_value(dependency_result, "types", [])):
		_record_dependency(receiver, capability_type, dependency_type)
	return capability


func _validate_receiver_and_type(receiver: Object, capability_type: Script, context: String) -> bool:
	if not is_instance_valid(receiver):
		push_error("[GFCapabilityUtility] %s 失败：receiver 无效。" % context)
		return false
	if capability_type == null:
		push_error("[GFCapabilityUtility] %s 失败：capability_type 为空。" % context)
		return false
	return true


func _create_capability(capability_type: Script, provider: Variant) -> Object:
	if provider is Callable:
		var callable_provider: Callable = _get_callable_value(provider)
		var value: Variant = callable_provider.call()
		if value is Object:
			return _get_object_value(value)
		push_error("[GFCapabilityUtility] provider Callable 必须返回 Object。")
		return null

	if provider is PackedScene:
		var scene_provider: PackedScene = _get_packed_scene_value(provider)
		var node: Node = _get_node_value(scene_provider.instantiate())
		if node == null:
			push_error("[GFCapabilityUtility] provider PackedScene 的根节点必须是 Node。")
		return node

	if provider is Object:
		return _get_object_value(provider)

	if not capability_type.can_instantiate():
		push_error("[GFCapabilityUtility] 能力类型不可实例化：%s" % _get_script_key(capability_type))
		return null

	return _get_object_value(capability_type.call("new"))


func _should_own_created_capability(provider: Variant) -> bool:
	return provider == null or provider is Callable or provider is PackedScene


func _ensure_required_capabilities(receiver: Object, capability: Object) -> Dictionary:
	var required_types: Array[Script] = _get_required_capabilities(capability)
	var resolved_types: Array[Script] = []
	var created_types: Array[Script] = []
	for required_type: Script in required_types:
		if required_type == null:
			continue
		if get_capability(receiver, required_type) != null:
			resolved_types.append(required_type)
			continue

		var before_types: Array[Script] = _get_capability_type_list(receiver).duplicate()
		var required_capability: Object = add_required_capability(receiver, required_type)
		if required_capability == null:
			return {
				"ok": false,
				"types": resolved_types,
				"created_types": created_types,
			}
		_append_unique_scripts(created_types, _get_created_capability_types(before_types, _get_capability_type_list(receiver)))
		resolved_types.append(required_type)
	return {
		"ok": true,
		"types": resolved_types,
		"created_types": created_types,
	}


func _get_required_capabilities(capability: Object) -> Array[Script]:
	if capability == null or not capability.has_method(HOOK_GET_REQUIRED_CAPABILITIES):
		return _empty_script_array()

	var raw_value: Variant = capability.call(HOOK_GET_REQUIRED_CAPABILITIES)
	var result: Array[Script] = []
	if raw_value is Array:
		var required_items: Array = GFVariantData.as_array(raw_value)
		for item: Variant in required_items:
			if item is Script:
				_append_script_item(result, _get_script_value(item))
			elif item != null:
				push_warning("[GFCapabilityUtility] get_required_capabilities() 包含非 Script 项，已跳过。")
	return result


func _can_attach_capability_instance(receiver: Object, capability: Object) -> bool:
	if capability == null or not ("receiver" in capability):
		return true

	var existing_receiver: Object = _get_live_object_value(GFObjectPropertyTools.read_property(capability, NodePath("receiver")))
	if existing_receiver == null or existing_receiver == receiver:
		return true

	push_error("[GFCapabilityUtility] 同一个能力实例不能挂载到多个 receiver。")
	return false


func _register_capability(
	receiver: Object,
	capability_type: Script,
	capability: Object,
	is_top_level: bool,
	owns_instance: bool
) -> void:
	var types: Array[Script] = _get_capability_type_list(receiver)
	types.append(capability_type)
	_mark_capability_top_level(receiver, capability_type, is_top_level)
	_mark_capability_owned(receiver, capability_type, owns_instance)
	_set_capability_instance(receiver, capability_type, capability)
	_track_capability_index(receiver, capability_type)
	_set_capability_receiver(capability, receiver)
	_inject_if_needed(capability)
	_attach_node_capability(receiver, capability)
	_apply_capability_active_state(receiver, capability, _read_capability_active(capability), false)
	_call_added_hook(receiver, capability)
	capability_added.emit(receiver, capability_type, capability)


func _get_capability_type_list(receiver: Object) -> Array[Script]:
	if not receiver.has_meta(_META_CAPABILITY_TYPES):
		receiver.set_meta(_META_CAPABILITY_TYPES, _empty_script_array())

	var types: Array[Script] = _get_script_array_value(receiver.get_meta(_META_CAPABILITY_TYPES))
	receiver.set_meta(_META_CAPABILITY_TYPES, types)
	return types


func _remove_capability_type_from_meta(receiver: Object, capability_type: Script) -> void:
	if not receiver.has_meta(_META_CAPABILITY_TYPES):
		return
	var types: Array = GFVariantData.as_array(receiver.get_meta(_META_CAPABILITY_TYPES))
	types.erase(capability_type)


func _mark_capability_top_level(
	receiver: Object,
	capability_type: Script,
	is_top_level: bool,
	remove_entry: bool = false
) -> void:
	if not is_instance_valid(receiver) or capability_type == null:
		return

	var top_level_types: Dictionary = _get_top_level_type_map(receiver)
	if remove_entry:
		_erase_dictionary_key(top_level_types, capability_type)
		return
	if is_top_level or not top_level_types.has(capability_type):
		top_level_types[capability_type] = is_top_level


func _is_capability_top_level(receiver: Object, capability_type: Script) -> bool:
	if not is_instance_valid(receiver) or capability_type == null:
		return false

	var top_level_types: Dictionary = _get_top_level_type_map(receiver)
	return GFVariantData.get_option_bool(top_level_types, capability_type, true)


func _get_top_level_type_map(receiver: Object) -> Dictionary:
	if not receiver.has_meta(_META_CAPABILITY_TOP_LEVEL_TYPES):
		receiver.set_meta(_META_CAPABILITY_TOP_LEVEL_TYPES, {})
	return GFVariantData.as_dictionary(receiver.get_meta(_META_CAPABILITY_TOP_LEVEL_TYPES))


func _mark_capability_owned(
	receiver: Object,
	capability_type: Script,
	owns_instance: bool,
	remove_entry: bool = false
) -> void:
	if not is_instance_valid(receiver) or capability_type == null:
		return

	var owned_types: Dictionary = _get_owned_type_map(receiver)
	if remove_entry:
		_erase_dictionary_key(owned_types, capability_type)
		return
	if owns_instance or not owned_types.has(capability_type):
		owned_types[capability_type] = owns_instance


func _owns_capability_instance(receiver: Object, capability_type: Script) -> bool:
	if not is_instance_valid(receiver) or capability_type == null:
		return false

	var owned_types: Dictionary = _get_owned_type_map(receiver)
	return GFVariantData.get_option_bool(owned_types, capability_type, false)


func _get_owned_type_map(receiver: Object) -> Dictionary:
	if not receiver.has_meta(_META_CAPABILITY_OWNED_TYPES):
		receiver.set_meta(_META_CAPABILITY_OWNED_TYPES, {})
	return GFVariantData.as_dictionary(receiver.get_meta(_META_CAPABILITY_OWNED_TYPES))


func _clear_empty_capability_metadata(receiver: Object) -> void:
	if not is_instance_valid(receiver):
		return

	if receiver.has_meta(_META_CAPABILITY_TYPES) and GFVariantData.as_array(receiver.get_meta(_META_CAPABILITY_TYPES)).is_empty():
		receiver.remove_meta(_META_CAPABILITY_TYPES)
	if receiver.has_meta(_META_CAPABILITY_TOP_LEVEL_TYPES) and GFVariantData.as_dictionary(receiver.get_meta(_META_CAPABILITY_TOP_LEVEL_TYPES)).is_empty():
		receiver.remove_meta(_META_CAPABILITY_TOP_LEVEL_TYPES)
	if receiver.has_meta(_META_CAPABILITY_OWNED_TYPES) and GFVariantData.as_dictionary(receiver.get_meta(_META_CAPABILITY_OWNED_TYPES)).is_empty():
		receiver.remove_meta(_META_CAPABILITY_OWNED_TYPES)
	if receiver.has_meta(_META_CAPABILITY_DEPENDENCIES) and GFVariantData.as_dictionary(receiver.get_meta(_META_CAPABILITY_DEPENDENCIES)).is_empty():
		receiver.remove_meta(_META_CAPABILITY_DEPENDENCIES)
	if receiver.has_meta(_META_CAPABILITY_DEPENDENCY_OF) and GFVariantData.as_dictionary(receiver.get_meta(_META_CAPABILITY_DEPENDENCY_OF)).is_empty():
		receiver.remove_meta(_META_CAPABILITY_DEPENDENCY_OF)


func _record_dependency(receiver: Object, owner_type: Script, dependency_type: Script) -> void:
	if not is_instance_valid(receiver) or owner_type == null or dependency_type == null:
		return
	if owner_type == dependency_type:
		return

	var dependencies: Dictionary = _get_dependency_map(receiver)
	if not dependencies.has(owner_type):
		dependencies[owner_type] = {}
	var owner_dependencies: Dictionary = GFVariantData.as_dictionary(dependencies[owner_type])
	owner_dependencies[dependency_type] = true

	var dependency_of: Dictionary = _get_dependency_of_map(receiver)
	if not dependency_of.has(dependency_type):
		dependency_of[dependency_type] = {}
	var dependency_owners: Dictionary = GFVariantData.as_dictionary(dependency_of[dependency_type])
	dependency_owners[owner_type] = true


func _get_dependency_types(receiver: Object, owner_type: Script) -> Array[Script]:
	if not is_instance_valid(receiver) or owner_type == null:
		return _empty_script_array()

	var dependencies: Dictionary = _get_dependency_map(receiver)
	var owner_dependencies: Dictionary = _get_dictionary_ref(dependencies, owner_type)
	var result: Array[Script] = []
	for dependency_type: Script in owner_dependencies:
		result.append(dependency_type)
	return result


func _get_dependency_owner_types(receiver: Object, dependency_type: Script) -> Array[Script]:
	if not is_instance_valid(receiver) or dependency_type == null:
		return _empty_script_array()

	var dependency_of: Dictionary = _get_dependency_of_map(receiver)
	var dependency_owners: Dictionary = _get_dictionary_ref(dependency_of, dependency_type)
	var result: Array[Script] = []
	for owner_type: Script in dependency_owners:
		result.append(owner_type)
	return result


func _remove_dependency_links(receiver: Object, removed_type: Script) -> void:
	if not is_instance_valid(receiver) or removed_type == null:
		return

	var dependencies: Dictionary = _get_dependency_map(receiver)
	var dependency_of: Dictionary = _get_dependency_of_map(receiver)
	var removed_dependencies: Dictionary = _get_dictionary_ref(dependencies, removed_type)
	for dependency_type: Script in removed_dependencies:
		var dependency_owners: Dictionary = _get_dictionary_ref(dependency_of, dependency_type)
		_erase_dictionary_key(dependency_owners, removed_type)
		if dependency_owners.is_empty():
			_erase_dictionary_key(dependency_of, dependency_type)
	_erase_dictionary_key(dependencies, removed_type)

	var owners: Dictionary = _get_dictionary_ref(dependency_of, removed_type)
	for owner_type: Script in owners:
		var owner_dependencies: Dictionary = _get_dictionary_ref(dependencies, owner_type)
		_erase_dictionary_key(owner_dependencies, removed_type)
		if owner_dependencies.is_empty():
			_erase_dictionary_key(dependencies, owner_type)
	_erase_dictionary_key(dependency_of, removed_type)


func _remove_unused_auto_dependencies(receiver: Object, dependency_types: Array[Script]) -> void:
	if not is_instance_valid(receiver):
		return

	for dependency_type: Script in dependency_types:
		if not has_capability(receiver, dependency_type):
			continue
		if _is_capability_top_level(receiver, dependency_type):
			continue
		if not _get_dependency_owner_types(receiver, dependency_type).is_empty():
			continue
		remove_capability(receiver, dependency_type)


func _rollback_created_dependencies(receiver: Object, created_types: Array) -> void:
	if not is_instance_valid(receiver):
		return

	for index: int in range(created_types.size() - 1, -1, -1):
		var dependency_type: Script = _get_script_value(created_types[index])
		if dependency_type == null:
			continue
		if not has_capability(receiver, dependency_type):
			continue
		if _is_capability_top_level(receiver, dependency_type):
			continue
		if not _get_dependency_owner_types(receiver, dependency_type).is_empty():
			continue
		remove_capability(receiver, dependency_type)


func _get_created_capability_types(before_types: Array, after_types: Array[Script]) -> Array[Script]:
	var result: Array[Script] = []
	for capability_type: Script in after_types:
		if not before_types.has(capability_type):
			result.append(capability_type)
	return result


func _append_unique_scripts(target: Array[Script], source: Array[Script]) -> void:
	for script: Script in source:
		if script != null and not target.has(script):
			target.append(script)


func _get_dependency_map(receiver: Object) -> Dictionary:
	if not receiver.has_meta(_META_CAPABILITY_DEPENDENCIES):
		receiver.set_meta(_META_CAPABILITY_DEPENDENCIES, {})
	return GFVariantData.as_dictionary(receiver.get_meta(_META_CAPABILITY_DEPENDENCIES))


func _get_dependency_of_map(receiver: Object) -> Dictionary:
	if not receiver.has_meta(_META_CAPABILITY_DEPENDENCY_OF):
		receiver.set_meta(_META_CAPABILITY_DEPENDENCY_OF, {})
	return GFVariantData.as_dictionary(receiver.get_meta(_META_CAPABILITY_DEPENDENCY_OF))


func _find_capability_record(receiver: Object, capability_type: Script, sync_scene_containers: bool = true) -> Dictionary:
	if not _validate_receiver_and_type(receiver, capability_type, "get_capability"):
		return {}

	if sync_scene_containers:
		_sync_scene_capability_containers(receiver)

	var exact_instance: Object = _get_capability_instance(receiver, capability_type)
	if exact_instance != null:
		return {
			"type": capability_type,
			"instance": exact_instance,
	}

	var matches: Array[Dictionary] = []
	for registered_type: Script in _get_capability_type_list(receiver):
		if _script_extends_or_equals(registered_type, capability_type):
			var instance: Object = _get_capability_instance(receiver, registered_type)
			if instance != null:
				matches.append({
					"type": registered_type,
					"instance": instance,
				})

	if matches.size() == 1:
		return matches[0]
	if matches.size() > 1:
		push_warning("[GFCapabilityUtility] get_capability(%s) 匹配到多个能力，请使用更具体类型查询。" % _get_script_key(capability_type))

	return {}


func _set_capability_instance(receiver: Object, capability_type: Script, capability: Object) -> void:
	receiver.set_meta(_get_capability_meta_name(capability_type), capability)


func _get_capability_instance(receiver: Object, capability_type: Script) -> Object:
	if receiver == null or capability_type == null:
		return null

	var meta_name: StringName = _get_capability_meta_name(capability_type)
	if not receiver.has_meta(meta_name):
		return null

	var capability: Object = _get_live_object_value(receiver.get_meta(meta_name))
	if capability != null:
		return capability

	receiver.remove_meta(meta_name)
	_remove_capability_type_from_meta(receiver, capability_type)
	_remove_capability_index(receiver.get_instance_id(), capability_type)
	return null


func _remove_capability_record(receiver: Object, capability_type: Script) -> void:
	_remove_capability_type_from_meta(receiver, capability_type)
	_mark_capability_top_level(receiver, capability_type, false, true)
	_mark_capability_owned(receiver, capability_type, false, true)
	_remove_capability_index(receiver.get_instance_id(), capability_type)
	var meta_name: StringName = _get_capability_meta_name(capability_type)
	if receiver.has_meta(meta_name):
		receiver.remove_meta(meta_name)


func _attach_node_capability(receiver: Object, capability: Object) -> void:
	if not (receiver is Node) or not (capability is Node):
		return

	var receiver_node: Node = receiver
	var capability_node: Node = capability
	var existing_parent: Node = capability_node.get_parent()
	if _is_existing_receiver_container(receiver_node, existing_parent):
		return

	var container: Node = _get_or_create_container(receiver_node, capability_node)
	if capability_node.get_parent() == container:
		return

	if capability_node.get_parent() != null:
		capability_node.reparent(container, false)
	else:
		_add_child_to_container(container, capability_node)


func _sync_scene_capability_containers(receiver: Object) -> void:
	if not (receiver is Node):
		return

	var receiver_node: Node = receiver
	if not is_instance_valid(receiver_node):
		return

	var receiver_id: int = receiver_node.get_instance_id()
	if _scene_container_sync_receivers.has(receiver_id):
		return

	_scene_container_sync_receivers[receiver_id] = true
	for container: Node in _get_receiver_capability_containers(receiver_node):
		_register_container_child_capabilities(receiver_node, container)
	_erase_dictionary_key(_scene_container_sync_receivers, receiver_id)


func _get_receiver_capability_containers(receiver: Node) -> Array[Node]:
	var result: Array[Node] = []
	for child_variant: Variant in receiver.get_children(true):
		var child: Node = _get_node_value(child_variant)
		if _is_capability_container(child):
			result.append(child)
	return result


func _register_container_child_capabilities(receiver: Node, container: Node) -> void:
	for child_variant: Variant in container.get_children():
		var child: Node = _get_node_value(child_variant)
		if child == null or _is_capability_container(child):
			continue

		var child_script: Script = _get_script_value(child.get_script())
		if child_script == null:
			continue

		var registered: Object = add_capability_instance(receiver, child, child_script)
		if registered == null:
			continue


func _get_or_create_container(receiver: Node, capability: Node) -> Node:
	for child_variant: Variant in receiver.get_children(true):
		var child: Node = _get_node_value(child_variant)
		if _is_capability_container(child) and _container_matches_capability(child, capability):
			return child

	var container: Node = _create_container_node(receiver, capability)
	container.set_meta(META_CAPABILITY_CONTAINER, true)
	_try_attach_capability_container_script(container)
	_add_child_to_receiver(receiver, container)
	return container


func _create_container_node(receiver: Node, capability: Node) -> Node:
	var container: Node
	if receiver is Node3D and capability is Node3D:
		container = Node3D.new()
		container.name = "GFCapabilityContainer3D"
	elif receiver is Node2D and capability is Node2D:
		container = Node2D.new()
		container.name = "GFCapabilityContainer2D"
	elif receiver is Control and capability is Control:
		container = Control.new()
		container.name = "GFCapabilityContainerControl"
		var control_container: Control = container
		_configure_control_container(control_container)
	else:
		container = Node.new()
		container.name = "GFCapabilityContainer"
	return container


func _try_attach_capability_container_script(container: Node) -> void:
	var container_script: Script = _GF_CAPABILITY_CONTAINER_SCRIPT
	if container_script == null or not container_script.can_instantiate():
		push_warning("[GFCapabilityUtility] 能力容器脚本不可用，已改用元数据标记容器。")
		return

	var base_type: String = String(container_script.get_instance_base_type())
	if not base_type.is_empty() and not container.is_class(base_type):
		push_warning("[GFCapabilityUtility] 能力容器节点类型与脚本基类不匹配，已改用元数据标记容器。")
		return

	container.set_script(container_script)


func _configure_control_container(container: Control) -> void:
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE as Control.MouseFilter
	container.set_anchors_preset(Control.PRESET_FULL_RECT)
	container.offset_left = 0.0
	container.offset_top = 0.0
	container.offset_right = 0.0
	container.offset_bottom = 0.0


func _container_matches_capability(container: Node, capability: Node) -> bool:
	if capability is Node3D:
		return container is Node3D
	if capability is Node2D:
		return container is Node2D
	if capability is Control:
		return container is Control
	return not (container is Node2D) and not (container is Node3D) and not (container is Control)


func _is_existing_receiver_container(receiver: Node, container: Node) -> bool:
	return (
		receiver != null
		and container != null
		and container.get_parent() == receiver
		and _is_capability_container(container)
	)


func _is_capability_container(node: Node) -> bool:
	if node == null:
		return false

	return (
		node is GFCapabilityContainer
		or GFVariantData.to_bool(node.get_meta(META_CAPABILITY_CONTAINER, false))
		or _is_capability_container_name(node.name)
	)


func _is_capability_container_name(node_name: StringName) -> bool:
	return String(node_name).begins_with("GFCapabilityContainer")


func _add_child_to_receiver(receiver: Node, child: Node) -> void:
	if receiver.is_inside_tree() and not receiver.is_node_ready():
		_add_child_deferred.call_deferred(receiver.get_instance_id(), child.get_instance_id(), Node.INTERNAL_MODE_BACK)
	else:
		receiver.add_child(child, true, Node.INTERNAL_MODE_BACK)


func _add_child_to_container(container: Node, child: Node) -> void:
	if container.is_inside_tree() and not container.is_node_ready():
		_add_child_deferred.call_deferred(container.get_instance_id(), child.get_instance_id(), Node.INTERNAL_MODE_BACK)
	else:
		container.add_child(child, true, Node.INTERNAL_MODE_BACK)


func _read_capability_active(capability: Object) -> bool:
	if capability == null:
		return false
	if "active" in capability:
		return GFVariantData.to_bool(GFObjectPropertyTools.read_property(capability, NodePath("active")))
	if capability.has_meta(_META_CAPABILITY_ACTIVE):
		return GFVariantData.to_bool(capability.get_meta(_META_CAPABILITY_ACTIVE))
	return true


func _apply_capability_active_state(receiver: Object, capability: Object, active: bool, notify_hook: bool) -> void:
	if capability == null:
		return

	if "active" in capability:
		capability.set("active", active)
	capability.set_meta(_META_CAPABILITY_ACTIVE, active)
	if capability is Node:
		var capability_node: Node = capability
		_set_node_tree_active_state(capability_node, active)
	if notify_hook:
		_call_active_changed_hook(receiver, capability, active)


func _set_node_tree_active_state(node: Node, active: bool) -> void:
	_set_node_active_state(node, active)
	for child_variant: Variant in node.get_children():
		var child: Node = _get_node_value(child_variant)
		if child == null:
			continue
		_set_node_tree_active_state(child, active)


func _set_node_active_state(node: Node, active: bool) -> void:
	if active:
		if node.has_meta(_META_ORIGINAL_PROCESS_MODE):
			var original_process_mode: Node.ProcessMode = _to_process_mode(GFVariantData.to_int(node.get_meta(_META_ORIGINAL_PROCESS_MODE)))
			if node.process_mode == Node.PROCESS_MODE_DISABLED:
				node.process_mode = original_process_mode
			node.remove_meta(_META_ORIGINAL_PROCESS_MODE)
		return

	if not node.has_meta(_META_ORIGINAL_PROCESS_MODE):
		node.set_meta(_META_ORIGINAL_PROCESS_MODE, node.process_mode)
	node.process_mode = Node.PROCESS_MODE_DISABLED as Node.ProcessMode


func _track_capability_index(receiver: Object, capability_type: Script) -> void:
	var receiver_id: int = _track_receiver(receiver)
	var receiver_ids: Dictionary = _get_capability_receiver_ids(capability_type)
	receiver_ids[receiver_id] = true


func _track_receiver(receiver: Object) -> int:
	var receiver_id: int = receiver.get_instance_id()
	_receiver_refs[receiver_id] = weakref(receiver)
	return receiver_id


func _remove_capability_index(receiver_id: int, capability_type: Script) -> void:
	if not _capability_receivers.has(capability_type):
		return

	var receiver_ids: Dictionary = GFVariantData.as_dictionary(_capability_receivers[capability_type])
	_erase_dictionary_key(receiver_ids, receiver_id)
	if receiver_ids.is_empty():
		_erase_dictionary_key(_capability_receivers, capability_type)


func _get_capability_receiver_ids(capability_type: Script) -> Dictionary:
	if not _capability_receivers.has(capability_type):
		_capability_receivers[capability_type] = {}
	return GFVariantData.as_dictionary(_capability_receivers[capability_type])


func _get_group_receiver_ids(group_name: StringName) -> Dictionary:
	if not _receiver_groups.has(group_name):
		_receiver_groups[group_name] = {}
	return GFVariantData.as_dictionary(_receiver_groups[group_name])


func _get_indexed_capability_types(capability_type: Script, include_subclasses: bool) -> Array[Script]:
	var result: Array[Script] = []
	for registered_type: Script in _capability_receivers:
		if registered_type == capability_type:
			result.append(registered_type)
		elif include_subclasses and _script_extends_or_equals(registered_type, capability_type):
			result.append(registered_type)
	return result


func _get_receiver_from_id(receiver_id: int) -> Object:
	var receiver_ref: WeakRef = _get_weak_ref_value(GFVariantData.get_option_value(_receiver_refs, receiver_id))
	if receiver_ref == null:
		return null

	var receiver: Object = _get_live_object_from_ref(receiver_ref)
	if receiver != null:
		return receiver
	_remove_receiver_index(receiver_id)
	return null


func _prune_invalid_receivers() -> void:
	var receiver_ids: Array = _receiver_refs.keys()
	for receiver_id: int in receiver_ids:
		var receiver: Object = _get_receiver_from_id(receiver_id)
		if receiver != null:
			continue
	_prune_receiver_cursor = 0


func _prune_invalid_receivers_step(max_count: int) -> void:
	var receiver_ids: Array = _receiver_refs.keys()
	if receiver_ids.is_empty():
		_prune_receiver_cursor = 0
		return

	if _prune_receiver_cursor >= receiver_ids.size():
		_prune_receiver_cursor = 0

	var checked_count: int = 0
	while checked_count < max_count:
		if _prune_receiver_cursor >= receiver_ids.size():
			_prune_receiver_cursor = 0
			break

		var receiver_id: int = GFVariantData.to_int(receiver_ids[_prune_receiver_cursor])
		var receiver: Object = _get_receiver_from_id(receiver_id)
		if receiver != null:
			pass
		_prune_receiver_cursor += 1
		checked_count += 1


func _remove_receiver_index(receiver_id: int) -> void:
	_erase_dictionary_key(_receiver_refs, receiver_id)

	for capability_type: Script in _capability_receivers.keys():
		var receiver_ids: Dictionary = GFVariantData.as_dictionary(_capability_receivers[capability_type])
		_erase_dictionary_key(receiver_ids, receiver_id)
		if receiver_ids.is_empty():
			_erase_dictionary_key(_capability_receivers, capability_type)

	for group_name: StringName in _receiver_groups.keys():
		var group_receivers: Dictionary = GFVariantData.as_dictionary(_receiver_groups[group_name])
		_erase_dictionary_key(group_receivers, receiver_id)
		if group_receivers.is_empty():
			_erase_dictionary_key(_receiver_groups, group_name)

	_erase_dictionary_key(_receiver_group_names, receiver_id)


func _inject_if_needed(capability: Object) -> void:
	var architecture: GFArchitecture = _get_architecture_or_null()
	if capability == null or architecture == null:
		return

	_inject_object_if_needed(capability, architecture)
	if capability is Node:
		var capability_node: Node = capability
		_inject_node_children_if_needed(capability_node, architecture)


func _inject_node_children_if_needed(node: Node, architecture: GFArchitecture) -> void:
	for child_variant: Variant in node.get_children(true):
		var child: Node = _get_node_value(child_variant)
		if child == null:
			continue
		_inject_object_if_needed(child, architecture)
		_inject_node_children_if_needed(child, architecture)


func _inject_object_if_needed(instance: Object, architecture: GFArchitecture) -> void:
	if instance == null or architecture == null:
		return

	if instance.has_method("inject_dependencies"):
		instance.call("inject_dependencies", architecture)
	if instance.has_method("inject"):
		instance.call("inject", architecture)


func _call_added_hook(receiver: Object, capability: Object) -> void:
	if capability != null and capability.has_method(HOOK_ON_ADDED):
		capability.call(HOOK_ON_ADDED, receiver)


func _set_capability_receiver(capability: Object, receiver: Object) -> void:
	if capability != null and "receiver" in capability:
		capability.set("receiver", receiver)


func _get_dependency_removal_policy(capability: Object) -> int:
	if capability == null or not capability.has_method(HOOK_GET_DEPENDENCY_REMOVAL_POLICY):
		return DependencyRemovalPolicy.REMOVE_AUTO_DEPENDENCIES

	var raw_policy: Variant = capability.call(HOOK_GET_DEPENDENCY_REMOVAL_POLICY)
	if typeof(raw_policy) != TYPE_INT:
		push_warning("[GFCapabilityUtility] get_dependency_removal_policy() 必须返回 int，已使用默认策略。")
		return DependencyRemovalPolicy.REMOVE_AUTO_DEPENDENCIES

	var policy: int = GFVariantData.to_int(raw_policy)
	if (
		policy != DependencyRemovalPolicy.KEEP_DEPENDENCIES
		and policy != DependencyRemovalPolicy.REMOVE_AUTO_DEPENDENCIES
	):
		push_warning("[GFCapabilityUtility] 未知依赖移除策略：%s，已使用默认策略。" % policy)
		return DependencyRemovalPolicy.REMOVE_AUTO_DEPENDENCIES
	return policy


func _call_removed_hook(receiver: Object, capability: Object) -> void:
	if capability != null and capability.has_method(HOOK_ON_REMOVED):
		capability.call(HOOK_ON_REMOVED, receiver)


func _call_active_changed_hook(receiver: Object, capability: Object, active: bool) -> void:
	if capability != null and capability.has_method(HOOK_ON_ACTIVE_CHANGED):
		capability.call(HOOK_ON_ACTIVE_CHANGED, receiver, active)


func _free_unregistered_capability(capability: Object) -> void:
	_free_capability(capability, false)


func _free_registered_capability(capability: Object) -> void:
	_free_capability(capability, true)


func _free_capability(capability: Object, detach_node: bool) -> void:
	if not is_instance_valid(capability):
		return

	if capability is Node:
		var node: Node = capability
		var parent: Node = node.get_parent()
		if (
			detach_node
			and parent != null
			and parent.is_inside_tree()
			and not parent.is_queued_for_deletion()
			and not node.is_queued_for_deletion()
		):
			_detach_capability_node(parent, node)
		if not node.is_queued_for_deletion():
			node.queue_free()
	elif capability is RefCounted:
		pass
	else:
		capability.free()


func _detach_capability_node(parent: Node, node: Node) -> void:
	if parent.is_inside_tree() and not parent.is_node_ready():
		_remove_child_deferred.call_deferred(parent.get_instance_id(), node.get_instance_id())
		_free_empty_generated_container_deferred.call_deferred(parent.get_instance_id())
		return

	parent.remove_child(node)
	_free_empty_generated_container(parent)


func _free_empty_generated_container(container: Node) -> void:
	if container == null:
		return
	if container.is_queued_for_deletion():
		return
	if not GFVariantData.to_bool(container.get_meta(META_CAPABILITY_CONTAINER, false)):
		return
	if container.get_child_count(true) > 0:
		return

	var parent: Node = container.get_parent()
	if parent != null:
		if parent.is_queued_for_deletion():
			return
		if parent.is_inside_tree() and not parent.is_node_ready():
			_remove_child_deferred.call_deferred(parent.get_instance_id(), container.get_instance_id())
			container.queue_free()
			return
		parent.remove_child(container)
	container.queue_free()


func _add_child_deferred(parent_id: int, child_id: int, internal_mode: int) -> void:
	var parent: Node = _get_live_node_from_id(parent_id)
	var child: Node = _get_live_node_from_id(child_id)
	if (
		parent == null
		or child == null
		or parent.is_queued_for_deletion()
		or child.is_queued_for_deletion()
		or child.get_parent() != null
	):
		return

	parent.add_child(child, true, internal_mode)


func _remove_child_deferred(parent_id: int, child_id: int) -> void:
	var parent: Node = _get_live_node_from_id(parent_id)
	var child: Node = _get_live_node_from_id(child_id)
	if parent == null or child == null or parent.is_queued_for_deletion():
		return
	if child.get_parent() != parent:
		return

	parent.remove_child(child)


func _free_empty_generated_container_deferred(container_id: int) -> void:
	var container: Node = _get_live_node_from_id(container_id)
	if container == null:
		return

	_free_empty_generated_container(container)


func _get_live_node_from_id(instance_id: int) -> Node:
	return _get_live_node_from_instance_id(instance_id)


func _get_capability_meta_name(capability_type: Script) -> StringName:
	return StringName(_META_CAPABILITY_INSTANCE_PREFIX + _get_script_key(capability_type).md5_text())


func _get_script_key(script: Script) -> String:
	if script == null:
		return "<null>"

	var global_name: StringName = script.get_global_name()
	if global_name != &"":
		return String(global_name)
	if not script.resource_path.is_empty():
		return script.resource_path
	return str(script.get_instance_id())


func _script_array_to_keys(scripts: Array[Script]) -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	for script: Script in scripts:
		_append_packed_string(result, _get_script_key(script))
	result.sort()
	return result


func _get_creation_key(receiver: Object, capability_type: Script) -> String:
	return "%s:%s" % [receiver.get_instance_id(), _get_script_key(capability_type)]


func _describe_creation_stack(next_key: String) -> String:
	var display_stack: Array[String] = _creation_stack.duplicate()
	display_stack.append(next_key)
	return " -> ".join(display_stack)
