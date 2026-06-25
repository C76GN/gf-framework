extends GutTest


# --- 常量 ---

const GF_CAPABILITY_INSPECTOR_PLUGIN_PATH: String = "res://addons/gf/extensions/capability/editor/gf_capability_inspector_plugin.gd"
const GF_CONTROL_CAPABILITY_SCRIPT_PATH: String = "res://addons/gf/extensions/capability/nodes/gf_control_capability.gd"


# --- 辅助类 ---

class HealthCapability extends GFCapability:
	var added_receiver: Object = null
	var removed_receiver: Object = null

	func on_gf_capability_added(target: Object) -> void:
		super.on_gf_capability_added(target)
		added_receiver = target

	func on_gf_capability_removed(target: Object) -> void:
		removed_receiver = target
		super.on_gf_capability_removed(target)


class DamageCapability extends GFCapability:
	func _init() -> void:
		required_capabilities = [HealthCapability]


class NoSuperDamageCapability extends GFCapability:
	var receiver_during_added: Object = null
	var receiver_during_removed: Object = null
	var health_during_added: Object = null

	func _init() -> void:
		required_capabilities = [HealthCapability]

	func on_gf_capability_added(_target: Object) -> void:
		receiver_during_added = receiver
		health_during_added = get_capability(HealthCapability)

	func on_gf_capability_removed(_target: Object) -> void:
		receiver_during_removed = receiver


class KeepDependencyDamageCapability extends DamageCapability:
	func get_dependency_removal_policy() -> int:
		return GFCapabilityUtility.DependencyRemovalPolicy.KEEP_DEPENDENCIES


class RollbackRootCapability extends GFCapability:
	func _init() -> void:
		required_capabilities = [HealthCapability, RollbackCycleCapability]


class RollbackCycleCapability extends GFCapability:
	func _init() -> void:
		required_capabilities = [RollbackRootCapability]


class DynamicDependencyCapability extends GFCapability:
	func get_required_capabilities() -> Array[Script]:
		return [HealthCapability]


class InjectedCapability extends GFCapability:
	var injected_architecture: GFArchitecture = null

	func inject_dependencies(architecture: GFArchitecture) -> void:
		super.inject_dependencies(architecture)
		injected_architecture = architecture


class ActiveCapability extends GFCapability:
	var active_events: Array[bool] = []

	func on_gf_capability_active_changed(_target: Object, is_active: bool) -> void:
		active_events.append(is_active)


class ActiveNodeCapability extends GFNodeCapability:
	var active_events: Array[bool] = []

	func on_gf_capability_active_changed(_target: Object, is_active: bool) -> void:
		active_events.append(is_active)


class ExportDependencyCapability extends GFNodeCapability:
	pass


class RequiredByPropertyCapability extends GFNodeCapability:
	var get_required_capabilities_called: bool = false

	func get_required_capabilities() -> Array[Script]:
		get_required_capabilities_called = true
		return []


class Spatial2DCapability extends GFNode2DCapability:
	var added_receiver: Object = null

	func on_gf_capability_added(target: Object) -> void:
		super.on_gf_capability_added(target)
		added_receiver = target


class Spatial3DCapability extends GFNode3DCapability:
	var added_receiver: Object = null

	func on_gf_capability_added(target: Object) -> void:
		super.on_gf_capability_added(target)
		added_receiver = target


class InjectedChildNode extends Node:
	var injected_architecture: GFArchitecture = null

	func inject_dependencies(architecture: GFArchitecture) -> void:
		injected_architecture = architecture


class Node2DCapability extends Node2D:
	var added_receiver: Object = null

	func on_gf_capability_added(target: Object) -> void:
		added_receiver = target


class CapabilityNode extends Node:
	var added_receiver: Object = null
	var removed_receiver: Object = null

	func on_gf_capability_added(target: Object) -> void:
		added_receiver = target

	func on_gf_capability_removed(target: Object) -> void:
		removed_receiver = target


class CountingCapabilityNode extends CapabilityNode:
	static var created_nodes: Array[Node] = []

	func _init() -> void:
		created_nodes.append(self)


class EnterTreeAddReceiver extends Node:
	var utility: GFCapabilityUtility = null
	var capability_type: Script = null
	var added_capability: Object = null

	func _enter_tree() -> void:
		if utility != null and capability_type != null:
			added_capability = utility.add_capability(self, capability_type)


class EnterTreeRemoveContainer extends Node:
	var utility: GFCapabilityUtility = null
	var receiver: Node = null
	var capability: Node = null

	func _enter_tree() -> void:
		if utility == null or receiver == null or capability == null:
			return
		var capability_script: Script = _capability_script()
		var _add_capability_instance_result: Object = utility.add_capability_instance(receiver, capability, capability_script)
		utility.remove_capability(receiver, capability_script)

	func _capability_script() -> Script:
		var script_value: Variant = capability.get_script()
		if script_value is Script:
			return script_value
		return null


class BaseCapability extends GFCapability:
	pass


class ConcreteCapabilityA extends BaseCapability:
	pass


class ConcreteCapabilityB extends BaseCapability:
	pass


# --- 私有变量 ---

var _arch: GFArchitecture
var _utility: GFCapabilityUtility


# --- Godot 生命周期方法 ---

func before_each() -> void:
	_arch = GFArchitecture.new()
	_utility = GFCapabilityUtility.new()
	await _arch.register_utility_instance(_utility)
	await Gf.set_architecture(_arch)


func after_each() -> void:
	if Gf.has_architecture():
		Gf.get_architecture().dispose()
		Gf._architecture = null


# --- 测试用例 ---

func test_add_and_get_capability() -> void:
	var receiver: RefCounted = RefCounted.new()

	var capability: HealthCapability = _utility.add_capability(receiver, HealthCapability)

	assert_not_null(capability, "应能挂载能力。")
	assert_true(_utility.has_capability(receiver, HealthCapability), "has_capability 应能识别已挂载能力。")
	assert_eq(_utility.get_capability(receiver, HealthCapability), capability, "get_capability 应返回同一能力实例。")
	assert_eq(capability.added_receiver, receiver, "挂载后应调用 added hook。")


func test_same_capability_instance_cannot_attach_to_multiple_receivers() -> void:
	var receiver_a: RefCounted = RefCounted.new()
	var receiver_b: RefCounted = RefCounted.new()
	var capability: HealthCapability = HealthCapability.new()

	var first: Object = _utility.add_capability_instance(receiver_a, capability, HealthCapability)
	var second: Object = _utility.add_capability_instance(receiver_b, capability, HealthCapability)

	assert_eq(first, capability, "能力实例应能挂载到第一个 receiver。")
	assert_null(second, "同一个能力实例不应挂载到第二个 receiver。")
	assert_false(_utility.has_capability(receiver_b, HealthCapability), "第二个 receiver 不应留下能力记录。")
	assert_push_error("[GFCapabilityUtility] 同一个能力实例不能挂载到多个 receiver。")


func test_add_capability_instance_rejects_mismatched_declared_type() -> void:
	var receiver: RefCounted = RefCounted.new()
	var capability: HealthCapability = HealthCapability.new()

	var result: Object = _utility.add_capability_instance(receiver, capability, DamageCapability)

	assert_null(result, "能力实例脚本不继承声明类型时应拒绝注册。")
	assert_false(_utility.has_capability(receiver, DamageCapability), "错误声明类型不应污染 receiver。")
	assert_false(_utility.has_capability(receiver, HealthCapability), "失败后不应按实例原始类型注册。")
	assert_null(capability.receiver, "失败注册不应写入 receiver。")
	assert_push_error("[GFCapabilityUtility] add_capability_instance 失败：能力实例脚本")


func test_add_capability_provider_rejects_mismatched_instance_type() -> void:
	var receiver: RefCounted = RefCounted.new()
	var capability: HealthCapability = HealthCapability.new()

	var result: Object = _utility.add_capability(receiver, DamageCapability, capability)

	assert_null(result, "provider 返回错误脚本类型时应拒绝注册。")
	assert_false(_utility.has_capability(receiver, DamageCapability), "错误 provider 不应按声明类型注册。")
	assert_false(_utility.has_capability(receiver, HealthCapability), "错误 provider 不应按实例类型回退注册。")
	assert_null(capability.receiver, "失败 provider 不应写入 receiver。")
	assert_push_error("[GFCapabilityUtility] add_capability 失败：能力实例脚本")


func test_required_capabilities_are_created_first() -> void:
	var receiver: RefCounted = RefCounted.new()

	var damage: DamageCapability = _utility.add_capability(receiver, DamageCapability)
	var health: HealthCapability = _utility.get_capability(receiver, HealthCapability)

	assert_not_null(damage, "主能力应挂载成功。")
	assert_not_null(health, "依赖能力应自动补齐。")
	assert_eq(damage.get_capability(HealthCapability), health, "能力基类应能访问同一 receiver 上的依赖能力。")


func test_dynamic_required_capability_hook_is_supported_at_runtime() -> void:
	var receiver: RefCounted = RefCounted.new()

	var capability: DynamicDependencyCapability = _utility.add_capability(receiver, DynamicDependencyCapability)
	var health: HealthCapability = _utility.get_capability(receiver, HealthCapability)

	assert_not_null(capability, "运行时动态依赖 Hook 应仍可挂载主能力。")
	assert_not_null(health, "运行时动态依赖 Hook 应能补齐依赖。")


func test_required_capability_export_property_is_used_by_default_hook() -> void:
	var receiver: Node = Node.new()
	add_child(receiver)
	var capability: ExportDependencyCapability = ExportDependencyCapability.new()
	capability.required_capabilities = [HealthCapability]

	var _add_capability_instance_result_264: Variant = _utility.add_capability_instance(receiver, capability, ExportDependencyCapability)
	var health: HealthCapability = _utility.get_capability(receiver, HealthCapability)

	assert_not_null(health, "默认依赖 Hook 应读取 required_capabilities 导出属性。")

	receiver.queue_free()
	await get_tree().process_frame


func test_capability_receiver_does_not_depend_on_super_hook_call() -> void:
	var receiver: RefCounted = RefCounted.new()

	var damage: NoSuperDamageCapability = _utility.add_capability(receiver, NoSuperDamageCapability)
	var health: HealthCapability = _utility.get_capability(receiver, HealthCapability)

	assert_not_null(damage, "未调用 super 的能力也应能挂载。")
	assert_not_null(health, "未调用 super 的能力也应先补齐依赖能力。")
	assert_eq(damage.receiver, receiver, "框架应主动维护能力 receiver。")
	assert_eq(damage.receiver_during_added, receiver, "added hook 内应能读取当前 receiver。")
	assert_eq(damage.health_during_added, health, "added hook 内应能通过 get_capability() 读取依赖能力。")

	_utility.remove_capability(receiver, NoSuperDamageCapability)

	assert_eq(damage.receiver_during_removed, receiver, "removed hook 内应仍能读取移除前 receiver。")
	assert_null(damage.receiver, "移除后框架应清空 receiver，即使 Hook 未调用 super。")


func test_auto_dependency_cleanup_removes_unused_auto_dependency() -> void:
	var receiver: RefCounted = RefCounted.new()

	var _add_capability_result_294: Variant = _utility.add_capability(receiver, DamageCapability)
	_utility.remove_capability(receiver, DamageCapability)

	assert_false(_utility.has_capability(receiver, DamageCapability), "主能力应被移除。")
	assert_false(_utility.has_capability(receiver, HealthCapability), "仅由主能力自动补齐的依赖应被清理。")


func test_auto_dependency_cleanup_keeps_explicit_dependency() -> void:
	var receiver: RefCounted = RefCounted.new()
	var _add_capability_result_303: Variant = _utility.add_capability(receiver, HealthCapability)

	var _add_capability_result_305: Variant = _utility.add_capability(receiver, DamageCapability)
	_utility.remove_capability(receiver, DamageCapability)

	assert_true(_utility.has_capability(receiver, HealthCapability), "用户显式添加的依赖能力不应被级联清理。")


func test_keep_dependency_policy_preserves_auto_dependency() -> void:
	var receiver: RefCounted = RefCounted.new()

	var _add_capability_result_314: Variant = _utility.add_capability(receiver, KeepDependencyDamageCapability)
	_utility.remove_capability(receiver, KeepDependencyDamageCapability)

	assert_false(_utility.has_capability(receiver, KeepDependencyDamageCapability), "主能力应被移除。")
	assert_true(_utility.has_capability(receiver, HealthCapability), "显式 KEEP_DEPENDENCIES 应保留自动补齐的依赖。")


func test_dependency_creation_failure_rolls_back_auto_created_dependencies() -> void:
	var receiver: RefCounted = RefCounted.new()

	var capability: Object = _utility.add_capability(receiver, RollbackRootCapability)

	assert_null(capability, "依赖链创建失败时主能力不应挂载。")
	assert_false(_utility.has_capability(receiver, HealthCapability), "失败前自动补齐的依赖应被回滚。")
	assert_false(_utility.has_capability(receiver, RollbackCycleCapability), "失败的循环依赖能力不应残留。")
	assert_push_error("[GFCapabilityUtility] 检测到循环能力依赖：")


func test_capability_receives_architecture_injection() -> void:
	var receiver: RefCounted = RefCounted.new()

	var capability: InjectedCapability = _utility.add_capability(receiver, InjectedCapability)

	assert_eq(capability.injected_architecture, _arch, "能力应收到当前架构注入。")


func test_node_capability_child_tree_receives_architecture_injection() -> void:
	var receiver: Node = Node.new()
	add_child(receiver)
	var capability: ActiveNodeCapability = ActiveNodeCapability.new()
	var child: InjectedChildNode = InjectedChildNode.new()
	capability.add_child(child)

	var _add_capability_instance_result_347: Variant = _utility.add_capability_instance(receiver, capability, ActiveNodeCapability)

	assert_eq(child.injected_architecture, _arch, "场景能力子节点也应收到当前架构注入。")

	receiver.queue_free()
	await get_tree().process_frame


func test_remove_capability_calls_hook_and_clears_storage() -> void:
	var receiver: RefCounted = RefCounted.new()
	var capability: HealthCapability = _utility.add_capability(receiver, HealthCapability)

	_utility.remove_capability(receiver, HealthCapability)

	assert_eq(capability.removed_receiver, receiver, "移除前应调用 removed hook。")
	assert_false(_utility.has_capability(receiver, HealthCapability), "移除后不应再查询到能力。")


func test_get_capability_prunes_freed_meta_instance_without_cast_error() -> void:
	var receiver: Node = Node.new()
	add_child(receiver)
	var capability: CapabilityNode = CapabilityNode.new()
	var capability_types: Array[Script] = _utility._get_capability_type_list(receiver)
	capability_types.append(CapabilityNode)
	receiver.set_meta(_utility._get_capability_meta_name(CapabilityNode), capability)
	capability.free()

	assert_null(_utility.get_capability(receiver, CapabilityNode), "能力元数据里的已释放实例应被清理。")
	assert_false(receiver.has_meta(_utility._get_capability_meta_name(CapabilityNode)), "清理后 receiver 不应保留失效能力元数据。")
	assert_false(capability_types.has(CapabilityNode), "清理后能力类型列表不应保留失效能力类型。")

	receiver.queue_free()
	await get_tree().process_frame


func test_unregister_capability_keeps_instance_detached_from_lifecycle() -> void:
	var receiver: RefCounted = RefCounted.new()
	var capability: HealthCapability = _utility.add_capability(receiver, HealthCapability)

	_utility.unregister_capability(receiver, HealthCapability)

	assert_false(_utility.has_capability(receiver, HealthCapability), "注销后不应再查询到能力。")
	assert_eq(capability.removed_receiver, receiver, "注销前应调用 removed hook。")
	assert_null(capability.receiver, "注销后应清空能力 receiver。")


func test_node_capability_is_attached_to_container() -> void:
	var receiver: Node = Node.new()
	add_child(receiver)

	var capability: CapabilityNode = _utility.add_capability(receiver, CapabilityNode)
	await get_tree().process_frame

	assert_not_null(capability, "Node 能力应创建成功。")
	assert_eq(capability.get_parent().name, "GFCapabilityContainer", "Node 能力应被挂入能力容器。")
	assert_eq(capability.get_parent().get_parent(), receiver, "能力容器应挂在 receiver 下。")
	assert_eq(capability.added_receiver, receiver, "Node 能力也应收到 added hook。")

	receiver.queue_free()
	await get_tree().process_frame


func test_removing_last_node_capability_cleans_generated_container() -> void:
	var receiver: Node = Node.new()
	add_child(receiver)

	var capability: CapabilityNode = _utility.add_capability(receiver, CapabilityNode)
	await get_tree().process_frame
	var container: Node = capability.get_parent()

	_utility.remove_capability(receiver, CapabilityNode)
	await get_tree().process_frame

	assert_false(_utility.has_capability(receiver, CapabilityNode), "移除 Node 能力后 receiver 不应保留能力。")
	assert_false(is_instance_valid(container), "自动生成的空能力容器应被释放。")

	receiver.queue_free()
	await get_tree().process_frame


func test_remove_node_capability_during_enter_tree_tolerates_receiver_free() -> void:
	var receiver: Node = Node.new()
	var container: EnterTreeRemoveContainer = EnterTreeRemoveContainer.new()
	container.name = "GFCapabilityContainer"
	var capability: CapabilityNode = CapabilityNode.new()
	container.utility = _utility
	container.receiver = receiver
	container.capability = capability
	container.add_child(capability)
	receiver.add_child(container)

	add_child(receiver)
	receiver.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame

	assert_false(is_instance_valid(receiver), "同帧移除能力并释放 receiver 后不应留下 receiver。")
	assert_push_error_count(0, "延迟移除能力节点时不应对已释放父节点调用 remove_child。")


func test_node2d_capability_uses_node2d_container() -> void:
	var receiver: Node2D = Node2D.new()
	add_child(receiver)

	var capability: Node2DCapability = _utility.add_capability(receiver, Node2DCapability)
	await get_tree().process_frame

	assert_not_null(capability, "Node2D 能力应创建成功。")
	assert_true(capability.get_parent() is Node2D, "Node2D 能力应挂入 Node2D 容器以保留空间继承。")
	assert_eq(capability.get_parent().get_parent(), receiver, "Node2D 能力容器应挂在 receiver 下。")
	assert_eq(capability.added_receiver, receiver, "Node2D 能力应收到 added hook。")

	receiver.queue_free()
	await get_tree().process_frame


func test_node2d_capability_base_uses_node2d_container_and_helpers() -> void:
	var receiver: Node2D = Node2D.new()
	add_child(receiver)

	var capability: Spatial2DCapability = _utility.add_capability(receiver, Spatial2DCapability)
	await get_tree().process_frame

	assert_not_null(capability, "GFNode2DCapability 子类应创建成功。")
	assert_true(capability is Node2D, "GFNode2DCapability 子类应保留 Node2D 类型。")
	assert_true(capability.get_parent() is Node2D, "GFNode2DCapability 应挂入 Node2D 容器。")
	assert_eq(capability.receiver, receiver, "GFNode2DCapability 应记录 receiver。")
	assert_eq(capability.added_receiver, receiver, "GFNode2DCapability 应收到 added hook。")
	assert_eq(capability.get_utility(GFCapabilityUtility), _utility, "GFNode2DCapability 应保留架构 helper。")

	receiver.queue_free()
	await get_tree().process_frame


func test_node3d_capability_base_uses_node3d_container() -> void:
	var receiver: Node3D = Node3D.new()
	add_child(receiver)

	var capability: Spatial3DCapability = _utility.add_capability(receiver, Spatial3DCapability)
	await get_tree().process_frame

	assert_not_null(capability, "GFNode3DCapability 子类应创建成功。")
	assert_true(capability is Node3D, "GFNode3DCapability 子类应保留 Node3D 类型。")
	assert_true(capability.get_parent() is Node3D, "GFNode3DCapability 应挂入 Node3D 容器。")
	assert_eq(capability.receiver, receiver, "GFNode3DCapability 应记录 receiver。")
	assert_eq(capability.added_receiver, receiver, "GFNode3DCapability 应收到 added hook。")

	receiver.queue_free()
	await get_tree().process_frame


func test_control_capability_base_uses_control_container() -> void:
	var receiver: Node = _new_control_node()
	assert_not_null(receiver, "应能创建 Control receiver。")
	if receiver == null:
		return
	add_child(receiver)
	var capability_type: Script = _load_script(GF_CONTROL_CAPABILITY_SCRIPT_PATH)

	assert_not_null(capability_type, "应能加载 GFControlCapability 脚本。")
	var capability: Object = _utility.add_capability(receiver, capability_type)
	await get_tree().process_frame
	var control_capability: Node = _get_node_value(capability)

	assert_not_null(control_capability, "GFControlCapability 应创建为 Control。")
	if control_capability != null:
		assert_true(control_capability.is_class("Control"), "GFControlCapability 应保留 Control 类型。")
		assert_true(control_capability.get_parent().is_class("Control"), "GFControlCapability 应挂入 Control 容器。")
		assert_eq(control_capability.get_parent().get_parent(), receiver, "GFControlCapability 容器应挂在 receiver 下。")
		assert_eq(_object_value(control_capability.call(&"get", &"receiver")), receiver, "GFControlCapability 应记录 receiver。")

	receiver.queue_free()
	await get_tree().process_frame


func test_scene_container_registers_child_capabilities() -> void:
	var receiver: Node = Node.new()
	var container: Node = Node.new()
	container.set_script(GFCapabilityContainer)
	var child_capability: CapabilityNode = CapabilityNode.new()
	container.add_child(child_capability)
	receiver.add_child(container)
	add_child(receiver)
	await get_tree().process_frame
	await get_tree().process_frame

	assert_eq(_utility.get_capability(receiver, CapabilityNode), child_capability, "场景容器应把子节点注册为父节点能力。")
	assert_eq(child_capability.added_receiver, receiver, "容器注册也应触发 added hook。")

	receiver.queue_free()
	await get_tree().process_frame


func test_scene_container_registers_child_capabilities_before_ready_frame() -> void:
	var receiver: Node = Node.new()
	var container: Node = Node.new()
	container.set_script(GFCapabilityContainer)
	var child_capability: CapabilityNode = CapabilityNode.new()
	container.add_child(child_capability)
	receiver.add_child(container)

	add_child(receiver)

	assert_eq(_utility.get_capability(receiver, CapabilityNode), child_capability, "场景容器进树时应立即注册子节点能力。")
	assert_eq(child_capability.added_receiver, receiver, "立即注册也应触发 added hook。")

	receiver.queue_free()
	await get_tree().process_frame


func test_scene_spatial_container_keeps_existing_plain_node_capability() -> void:
	var receiver: Node2D = Node2D.new()
	var container: Node2D = Node2D.new()
	container.name = "GFCapabilityContainer2D"
	container.set_meta(GFCapabilityUtility.META_CAPABILITY_CONTAINER, true)
	container.set_script(GFCapabilityContainer)
	var child_capability: CapabilityNode = CapabilityNode.new()
	container.add_child(child_capability)
	receiver.add_child(container)

	add_child(receiver)

	assert_eq(_utility.get_capability(receiver, CapabilityNode), child_capability, "空间容器中已有的普通 Node 能力也应注册。")
	assert_eq(child_capability.get_parent(), container, "场景中已摆放的能力不应在进树注册时被重挂到新容器。")

	await get_tree().process_frame

	receiver.queue_free()
	await get_tree().process_frame


func test_meta_only_spatial_container_lazily_registers_child_capability_on_query() -> void:
	var receiver: Node2D = Node2D.new()
	var container: Node2D = Node2D.new()
	container.name = "GFCapabilityContainer2D"
	container.set_meta(GFCapabilityUtility.META_CAPABILITY_CONTAINER, true)
	var child_capability: Node2DCapability = Node2DCapability.new()
	container.add_child(child_capability)
	receiver.add_child(container)
	add_child(receiver)

	assert_eq(_utility.get_capability(receiver, Node2DCapability), child_capability, "只有元数据标记的 2D 容器也应在查询时同步注册子能力。")
	assert_eq(child_capability.added_receiver, receiver, "懒同步注册也应触发 added hook。")

	receiver.queue_free()
	await get_tree().process_frame


func test_named_spatial_container_lazily_registers_plain_node_child_capability_on_query() -> void:
	var receiver: Node2D = Node2D.new()
	var container: Node2D = Node2D.new()
	container.name = "GFCapabilityContainer2D"
	var child_capability: CapabilityNode = CapabilityNode.new()
	container.add_child(child_capability)
	receiver.add_child(container)
	add_child(receiver)

	assert_eq(_utility.get_capability(receiver, CapabilityNode), child_capability, "旧场景中仅保留容器命名的 2D 容器也应能同步注册普通 Node 能力。")
	assert_eq(child_capability.get_parent(), container, "查询同步不应把已摆放能力重挂到其他容器。")

	receiver.queue_free()
	await get_tree().process_frame


func test_add_capability_during_receiver_enter_tree_defers_container_attachment() -> void:
	var receiver: EnterTreeAddReceiver = EnterTreeAddReceiver.new()
	receiver.utility = _utility
	receiver.capability_type = CapabilityNode

	add_child(receiver)

	assert_not_null(receiver.added_capability, "receiver _enter_tree 中添加能力应立即返回实例。")
	assert_eq(_utility.get_capability(receiver, CapabilityNode), receiver.added_capability, "即使容器延迟挂树，能力也应立即可查询。")

	await get_tree().process_frame

	var capability: CapabilityNode = receiver.added_capability
	assert_not_null(capability.get_parent(), "延迟后能力应挂入容器。")
	assert_eq(capability.get_parent().get_parent(), receiver, "延迟创建的容器应挂在 receiver 下。")

	receiver.queue_free()
	await get_tree().process_frame


func test_scene_container_unregisters_children_when_removed() -> void:
	var receiver: Node = Node.new()
	var container: Node = Node.new()
	container.set_script(GFCapabilityContainer)
	var child_capability: CapabilityNode = CapabilityNode.new()
	container.add_child(child_capability)
	receiver.add_child(container)
	add_child(receiver)
	await get_tree().process_frame
	await get_tree().process_frame

	receiver.remove_child(container)
	await get_tree().process_frame

	assert_false(_utility.has_capability(receiver, CapabilityNode), "场景容器离树时应注销已注册子能力。")
	assert_true(is_instance_valid(child_capability), "容器离树只注销登记，不应释放原场景子能力。")
	assert_false(child_capability.is_queued_for_deletion(), "容器离树不应把原场景子能力标记为释放。")
	assert_eq(child_capability.get_parent(), container, "容器离树后子能力仍应留在原容器场景结构中。")

	container.queue_free()
	receiver.queue_free()
	await get_tree().process_frame


func test_add_scene_capability_frees_ignored_duplicate_instance() -> void:
	var receiver: Node = Node.new()
	add_child(receiver)
	var existing: CountingCapabilityNode = CountingCapabilityNode.new()
	CountingCapabilityNode.created_nodes.clear()
	var _add_capability_instance_result_660: Variant = _utility.add_capability_instance(receiver, existing, CountingCapabilityNode)
	var scene: PackedScene = _make_counting_capability_scene()

	var result: Object = _utility.add_scene_capability(receiver, scene, CountingCapabilityNode)
	var duplicate_node: CountingCapabilityNode = CountingCapabilityNode.created_nodes.back()

	assert_eq(result, existing, "重复挂载场景能力时应返回已有实例。")
	assert_true(duplicate_node.is_queued_for_deletion(), "被忽略的新场景能力实例应被释放。")

	receiver.queue_free()
	await get_tree().process_frame


func test_add_scene_capability_rejects_mismatched_declared_type_and_frees_instance() -> void:
	var receiver: Node = Node.new()
	add_child(receiver)
	var scene: PackedScene = _make_counting_capability_scene()

	var result: Object = _utility.add_scene_capability(receiver, scene, HealthCapability)
	var created_node: CountingCapabilityNode = CountingCapabilityNode.created_nodes.back()

	assert_null(result, "场景根节点脚本不继承声明类型时应拒绝注册。")
	assert_false(_utility.has_capability(receiver, HealthCapability), "错误场景能力不应污染 receiver。")
	assert_true(created_node.is_queued_for_deletion(), "被拒绝的场景能力实例应被释放。")
	assert_push_error("[GFCapabilityUtility] add_capability_instance 失败：能力实例脚本")

	receiver.queue_free()
	await get_tree().process_frame


func test_dispose_clears_ref_counted_capability_state() -> void:
	var receiver: RefCounted = RefCounted.new()
	var capability: HealthCapability = _utility.add_capability(receiver, HealthCapability)

	_utility.dispose()

	assert_eq(capability.removed_receiver, receiver, "dispose 应触发 removed hook。")
	assert_null(capability.receiver, "dispose 后能力不应继续指向 receiver。")
	assert_false(receiver.has_meta(_utility._get_capability_meta_name(HealthCapability)), "dispose 应清理 receiver 上的能力实例元数据。")


func test_dispose_releases_owned_runtime_node_capability() -> void:
	var receiver: Node = Node.new()
	add_child(receiver)
	var capability: CapabilityNode = _utility.add_capability(receiver, CapabilityNode)
	await get_tree().process_frame
	var container: Node = capability.get_parent()

	_utility.dispose()

	assert_eq(capability.removed_receiver, receiver, "dispose 应触发 Node 能力 removed hook。")
	assert_true(capability.is_queued_for_deletion(), "Utility 创建的 Node 能力应在 dispose 中进入释放队列。")
	await get_tree().process_frame

	assert_false(is_instance_valid(capability), "Utility 创建的 Node 能力应随 dispose 释放。")
	assert_false(is_instance_valid(container), "Utility 创建的空能力容器应随 dispose 释放。")
	assert_false(receiver.has_meta(_utility._get_capability_meta_name(CapabilityNode)), "dispose 应清理 receiver 上的 Node 能力元数据。")

	receiver.queue_free()
	await get_tree().process_frame


func test_dispose_unregisters_external_scene_capability_without_freeing_node() -> void:
	var receiver: Node = Node.new()
	var container: Node = Node.new()
	container.set_script(GFCapabilityContainer)
	var child_capability: CapabilityNode = CapabilityNode.new()
	container.add_child(child_capability)
	receiver.add_child(container)
	add_child(receiver)
	await get_tree().process_frame
	await get_tree().process_frame

	assert_eq(_utility.get_capability(receiver, CapabilityNode), child_capability, "场景中已有的能力应先注册成功。")

	_utility.dispose()
	await get_tree().process_frame

	assert_eq(child_capability.removed_receiver, receiver, "dispose 应注销外部场景能力。")
	assert_true(is_instance_valid(child_capability), "外部场景能力不应被 Utility dispose 释放。")
	assert_eq(child_capability.get_parent(), container, "外部场景能力应留在原容器中。")
	assert_false(receiver.has_meta(_utility._get_capability_meta_name(CapabilityNode)), "dispose 应清理 receiver 上的外部能力元数据。")

	receiver.queue_free()
	await get_tree().process_frame


func test_base_type_lookup_requires_unique_match() -> void:
	var receiver: RefCounted = RefCounted.new()
	var capability_a: ConcreteCapabilityA = _utility.add_capability(receiver, ConcreteCapabilityA)

	assert_eq(_utility.get_capability(receiver, BaseCapability), capability_a, "单个子类能力可通过基类查询。")

	var _add_capability_result_736: Variant = _utility.add_capability(receiver, ConcreteCapabilityB)
	var ambiguous: Variant = _utility.get_capability(receiver, BaseCapability)

	assert_push_warning("[GFCapabilityUtility] get_capability(")
	assert_true(ambiguous == null, "多个子类能力匹配同一基类时应返回 null。")


func test_capability_active_state_updates_property_and_hook() -> void:
	var receiver: RefCounted = RefCounted.new()
	var capability: ActiveCapability = _utility.add_capability(receiver, ActiveCapability)

	_utility.set_capability_active(receiver, ActiveCapability, false)

	assert_false(capability.active, "停用能力后 active 属性应同步。")
	assert_false(_utility.is_capability_active(receiver, ActiveCapability), "Utility 应能查询到停用状态。")
	assert_eq(capability.active_events, [false], "停用能力时应触发 active hook。")

	_utility.set_capability_active(receiver, ActiveCapability, true)

	assert_true(capability.active, "重新启用后 active 属性应恢复。")
	assert_eq(capability.active_events, [false, true], "重新启用时应再次触发 active hook。")


func test_node_capability_active_state_disables_processing() -> void:
	var receiver: Node = Node.new()
	add_child(receiver)

	var capability: ActiveNodeCapability = _utility.add_capability(receiver, ActiveNodeCapability)
	await get_tree().process_frame

	var original_process_mode: int = capability.process_mode
	_utility.set_capability_active(receiver, ActiveNodeCapability, false)

	assert_false(capability.active, "Node 能力停用后 active 属性应同步。")
	assert_eq(capability.process_mode, Node.PROCESS_MODE_DISABLED, "Node 能力停用后应停止处理。")
	assert_eq(capability.active_events, [false], "Node 能力停用时应触发 active hook。")

	_utility.set_capability_active(receiver, ActiveNodeCapability, true)

	assert_true(capability.active, "Node 能力重新启用后 active 属性应恢复。")
	assert_eq(capability.process_mode, original_process_mode, "Node 能力重新启用后应恢复原 process_mode。")

	receiver.queue_free()
	await get_tree().process_frame


func test_node_capability_active_restore_preserves_runtime_process_mode_change() -> void:
	var receiver: Node = Node.new()
	add_child(receiver)

	var capability: ActiveNodeCapability = _utility.add_capability(receiver, ActiveNodeCapability)
	await get_tree().process_frame

	_utility.set_capability_active(receiver, ActiveNodeCapability, false)
	capability.process_mode = Node.PROCESS_MODE_ALWAYS as Node.ProcessMode
	_utility.set_capability_active(receiver, ActiveNodeCapability, true)

	assert_eq(capability.process_mode, Node.PROCESS_MODE_ALWAYS, "停用期间项目层修改 process_mode 时，重新启用不应覆盖该修改。")

	receiver.queue_free()
	await get_tree().process_frame


func test_capability_reverse_index_and_groups() -> void:
	var receiver_a: RefCounted = RefCounted.new()
	var receiver_b: RefCounted = RefCounted.new()
	var capability_a: ConcreteCapabilityA = _utility.add_capability(receiver_a, ConcreteCapabilityA)
	var capability_b: ConcreteCapabilityB = _utility.add_capability(receiver_b, ConcreteCapabilityB)

	_utility.add_receiver_to_group(receiver_a, &"targets")
	_utility.add_receiver_to_group(receiver_b, &"targets")
	_utility.add_receiver_to_group(receiver_b, &"bosses")

	var receivers: Array[Object] = _utility.get_receivers_with(BaseCapability)
	var capabilities: Array[Object] = _utility.get_capabilities(BaseCapability)
	var target_receivers: Array[Object] = _utility.get_receivers_in_group(&"targets")
	var boss_base_receivers: Array[Object] = _utility.get_receivers_in_group_with(&"bosses", BaseCapability)

	assert_true(receivers.has(receiver_a), "基类反向查询应包含第一个 receiver。")
	assert_true(receivers.has(receiver_b), "基类反向查询应包含第二个 receiver。")
	assert_true(capabilities.has(capability_a), "能力实例查询应包含第一个能力。")
	assert_true(capabilities.has(capability_b), "能力实例查询应包含第二个能力。")
	assert_true(target_receivers.has(receiver_a), "分组查询应包含第一个 receiver。")
	assert_true(target_receivers.has(receiver_b), "分组查询应包含第二个 receiver。")
	assert_eq(boss_base_receivers, [receiver_b], "分组能力交集查询应只返回匹配 receiver。")


func test_capability_multi_condition_query_filters_required_rejected_and_group() -> void:
	var receiver_a: RefCounted = RefCounted.new()
	var receiver_b: RefCounted = RefCounted.new()
	var receiver_c: RefCounted = RefCounted.new()
	var _add_concrete_a_result: Object = _utility.add_capability(receiver_a, ConcreteCapabilityA)
	var _add_health_a_result: Object = _utility.add_capability(receiver_a, HealthCapability)
	var _add_concrete_b_result: Object = _utility.add_capability(receiver_b, ConcreteCapabilityB)
	var _add_damage_b_result: Object = _utility.add_capability(receiver_b, DamageCapability)
	var _add_health_c_result: Object = _utility.add_capability(receiver_c, HealthCapability)

	_utility.add_receiver_to_group(receiver_a, &"targets")
	_utility.add_receiver_to_group(receiver_b, &"targets")
	_utility.add_receiver_to_group(receiver_c, &"targets")

	var base_with_health_without_damage: Array[Object] = _utility.get_receivers_matching_capabilities(
		[BaseCapability, HealthCapability],
		[DamageCapability]
	)
	var target_without_base: Array[Object] = _utility.get_receivers_matching_capabilities(
		[],
		[BaseCapability],
		true,
		&"targets"
	)
	var exact_base_only: Array[Object] = _utility.get_receivers_matching_capabilities(
		[BaseCapability],
		[],
		false
	)

	assert_eq(base_with_health_without_damage, [receiver_a], "多条件查询应要求全部 required，并排除任一 rejected。")
	assert_eq(target_without_base, [receiver_c], "空 required 时应能在分组内按 rejected 能力筛选。")
	assert_true(exact_base_only.is_empty(), "关闭子类匹配时，基类条件不应匹配已注册子类能力。")


func test_capability_query_candidate_planner_intersects_group_and_required_index() -> void:
	var group_only_a: RefCounted = RefCounted.new()
	var group_only_b: RefCounted = RefCounted.new()
	var health_outside_group: RefCounted = RefCounted.new()
	var health_inside_group: RefCounted = RefCounted.new()
	var _add_health_outside_result: Object = _utility.add_capability(health_outside_group, HealthCapability)
	var _add_health_inside_result: Object = _utility.add_capability(health_inside_group, HealthCapability)

	_utility.add_receiver_to_group(group_only_a, &"targets")
	_utility.add_receiver_to_group(group_only_b, &"targets")
	_utility.add_receiver_to_group(health_inside_group, &"targets")

	var candidate_ids: Array = _utility._get_capability_query_candidate_ids(
		[HealthCapability],
		true,
		&"targets"
	)
	var receivers: Array[Object] = _utility.get_receivers_matching_capabilities(
		[HealthCapability],
		[],
		true,
		&"targets"
	)

	assert_eq(candidate_ids.size(), 1, "同时指定分组和 required 能力时，应取索引交集作为候选。")
	if not candidate_ids.is_empty():
		assert_eq(GFVariantData.to_int(candidate_ids[0]), health_inside_group.get_instance_id(), "候选集不应包含分组外 receiver。")
	assert_eq(receivers, [health_inside_group], "优化后的候选集仍应返回同一查询结果。")


func test_capability_query_resource_filters_receivers_and_matches_single_receiver() -> void:
	var receiver_a: RefCounted = RefCounted.new()
	var receiver_b: RefCounted = RefCounted.new()
	var _add_concrete_a_result: Object = _utility.add_capability(receiver_a, ConcreteCapabilityA)
	var _add_health_a_result: Object = _utility.add_capability(receiver_a, HealthCapability)
	var _add_concrete_b_result: Object = _utility.add_capability(receiver_b, ConcreteCapabilityB)
	var _add_damage_b_result: Object = _utility.add_capability(receiver_b, DamageCapability)

	_utility.add_receiver_to_group(receiver_a, &"targets")
	_utility.add_receiver_to_group(receiver_b, &"targets")

	var query: GFCapabilityQuery = GFCapabilityQuery.new()
	query.required_capability_types = [BaseCapability, HealthCapability]
	query.rejected_capability_types = [DamageCapability]
	query.group_name = &"targets"
	query.metadata = { "owner": "test" }

	var receivers: Array[Object] = _utility.get_receivers_matching_query(query)
	var duplicated_query: GFCapabilityQuery = query.duplicate_query()

	assert_eq(receivers, [receiver_a], "资源化查询应复用 required/rejected/group 条件。")
	assert_true(query.matches_receiver(_utility, receiver_a), "匹配 receiver 应返回 true。")
	assert_false(query.matches_receiver(_utility, receiver_b), "包含 rejected 能力的 receiver 应返回 false。")
	assert_eq(duplicated_query.group_name, &"targets", "查询拷贝应保留分组。")
	assert_eq(GFVariantData.get_option_string(duplicated_query.metadata, "owner"), "test", "查询拷贝应保留 metadata。")


func test_prune_invalid_receivers_removes_stale_indices() -> void:
	var receiver: Object = Object.new()
	var _add_capability_result_825: Variant = _utility.add_capability(receiver, HealthCapability)
	var receiver_id: int = receiver.get_instance_id()

	receiver.free()
	_utility.prune_invalid_receivers()

	assert_false(_utility._receiver_refs.has(receiver_id), "主动清理应移除已释放 receiver 的弱引用。")


func test_tick_prune_invalid_receivers_uses_budget() -> void:
	var receiver_a: Object = Object.new()
	var receiver_b: Object = Object.new()
	var _add_capability_result_837: Variant = _utility.add_capability(receiver_a, HealthCapability)
	var _add_capability_result_838: Variant = _utility.add_capability(receiver_b, HealthCapability)
	_utility.prune_invalid_receivers_per_tick = 1

	receiver_a.free()
	receiver_b.free()
	_utility.tick(1.0)

	assert_eq(_utility._receiver_refs.size(), 1, "tick 自动清理应遵守单次预算。")

	_utility.tick(1.0)

	assert_eq(_utility._receiver_refs.size(), 0, "后续 tick 应继续从游标位置清理剩余失效 receiver。")


func test_property_bag_capability_stores_typed_values() -> void:
	var receiver: RefCounted = RefCounted.new()
	var bag: GFPropertyBagCapability = _property_bag(_utility.add_capability(receiver, GFPropertyBagCapability))

	bag.set_property_value(&"count", 3)
	bag.set_property_value(&"title", "hello")
	bag.set_property_value(&"offset", Vector2(2.0, 4.0))

	assert_eq(bag.get_int(&"count"), 3, "属性包应能按 int 读取。")
	assert_eq(bag.get_string(&"title"), "hello", "属性包应能按 String 读取。")
	assert_eq(bag.get_vector2(&"offset"), Vector2(2.0, 4.0), "属性包应能按 Vector2 读取。")
	assert_true(bag.remove_property_value(&"title"), "属性包应能移除已有属性。")
	assert_false(bag.has_property_value(&"title"), "移除后属性不应继续存在。")


func test_property_bag_typed_getters_return_default_on_type_mismatch() -> void:
	var receiver: RefCounted = RefCounted.new()
	var bag: GFPropertyBagCapability = _property_bag(_utility.add_capability(receiver, GFPropertyBagCapability))
	bag.set_property_value(&"count", "3")
	bag.set_property_value(&"enabled", 1)

	assert_eq(bag.get_int(&"count", 7), 7, "int getter 遇到字符串时应返回默认值。")
	assert_false(bag.get_bool(&"enabled", false), "bool getter 遇到数字时应返回默认值。")


func test_inspect_receiver_reports_dependencies_and_groups() -> void:
	var receiver: RefCounted = RefCounted.new()
	_utility.add_receiver_to_group(receiver, &"targets")
	var _add_capability_result_880: Variant = _utility.add_capability(receiver, DamageCapability)

	var report: Dictionary = _utility.inspect_receiver(receiver)
	var validation: Dictionary = _utility.validate_receiver_dependencies(receiver)
	var dependency_report: Dictionary = _find_capability_report_with_dependencies(report)

	assert_true(GFVariantData.get_option_bool(report, "ok"), "自动补齐依赖后 receiver 诊断应为 ok。")
	assert_true(GFVariantData.get_option_bool(validation, "ok"), "依赖校验应复用诊断结果。")
	assert_eq(GFVariantData.get_option_int(report, "capability_count"), 2, "诊断应包含主能力和自动补齐的依赖能力。")
	assert_true(GFVariantData.get_option_array(report, "groups").has(&"targets"), "诊断应包含 receiver 分组。")
	assert_false(dependency_report.is_empty(), "诊断应标出拥有依赖的能力。")
	assert_eq(GFVariantData.get_option_packed_string_array(dependency_report, "registered_dependencies").size(), 1, "主能力应记录一个已注册依赖。")


func test_inspect_invalid_receiver_returns_error_report() -> void:
	var report: Dictionary = _utility.inspect_receiver(null)

	assert_false(GFVariantData.get_option_bool(report, "ok"), "无效 receiver 的诊断应失败。")
	assert_eq(GFVariantData.get_option_int(report, "receiver_id"), -1, "无效 receiver 应返回哨兵 id。")
	assert_eq(GFVariantData.get_option_string(report, "error"), "Receiver is invalid.", "无效 receiver 应返回错误原因。")


func test_capability_recipe_applies_entries_and_groups() -> void:
	var receiver: RefCounted = RefCounted.new()
	var recipe: GFCapabilityRecipe = GFCapabilityRecipe.new()
	recipe.recipe_id = &"test_recipe"
	recipe.groups = [&"targets"]
	var entry: GFCapabilityRecipeEntry = GFCapabilityRecipeEntry.new()
	entry.capability_type = ActiveCapability
	entry.active = false
	recipe.entries = [entry]

	var result: Dictionary = _utility.apply_recipe(receiver, recipe)

	assert_true(GFVariantData.get_option_bool(result, "ok"), "有效 Recipe 应应用成功。")
	assert_true(_utility.has_capability(receiver, ActiveCapability), "Recipe 应挂载能力。")
	assert_false(_utility.is_capability_active(receiver, ActiveCapability), "Recipe 应应用默认启停状态。")
	assert_true(_utility.get_receivers_in_group(&"targets").has(receiver), "Recipe 应添加分组。")

	var removed: Dictionary = _utility.remove_recipe(receiver, recipe)

	assert_true(GFVariantData.get_option_bool(removed, "ok"), "移除 Recipe 应成功。")
	assert_false(_utility.has_capability(receiver, ActiveCapability), "remove_recipe 应移除能力。")
	assert_false(_utility.get_receivers_in_group(&"targets").has(receiver), "remove_recipe 应移除分组。")


func test_capability_recipe_rolls_back_added_entries_and_groups_on_failure() -> void:
	var receiver: RefCounted = RefCounted.new()
	var recipe: GFCapabilityRecipe = GFCapabilityRecipe.new()
	recipe.groups = [&"targets"]
	var valid_entry: GFCapabilityRecipeEntry = GFCapabilityRecipeEntry.new()
	valid_entry.capability_type = ActiveCapability
	var failing_entry: GFCapabilityRecipeEntry = GFCapabilityRecipeEntry.new()
	failing_entry.capability_type = RollbackRootCapability
	recipe.entries = [valid_entry, failing_entry]

	var result: Dictionary = _utility.apply_recipe(receiver, recipe)

	assert_false(GFVariantData.get_option_bool(result, "ok"), "事务化 Recipe 中任一条目失败时整体应失败。")
	assert_true(GFVariantData.get_option_bool(result, "rolled_back"), "默认 transactional=true 时应执行回滚。")
	assert_false(_utility.has_capability(receiver, ActiveCapability), "失败前已新增的能力应被移除。")
	assert_false(_utility.get_receivers_in_group(&"targets").has(receiver), "失败前新增的分组也应回滚。")
	assert_push_error("[GFCapabilityUtility] 检测到循环能力依赖：")


func test_capability_recipe_validation_reports_invalid_entries() -> void:
	var recipe: GFCapabilityRecipe = GFCapabilityRecipe.new()
	recipe.entries = [GFCapabilityRecipeEntry.new()]

	var report: Dictionary = recipe.validate_recipe()

	assert_false(GFVariantData.get_option_bool(report, "ok"), "无效条目应使 Recipe 校验失败。")
	assert_true(_has_issue(report, "invalid_entry"), "Recipe 校验应报告 invalid_entry。")
	assert_eq(_find_issue_path(report, "invalid_entry"), "entries[0]", "Recipe 校验应保留条目路径。")
	assert_false(GFVariantData.get_option_string(report, "next_action").is_empty(), "Recipe 校验应提供下一步建议。")


func test_capability_recipe_validation_report_reports_group_issues() -> void:
	var recipe: GFCapabilityRecipe = GFCapabilityRecipe.new()
	recipe.recipe_id = &"group_recipe"
	recipe.groups = [&"targets", &"", &"targets"]

	var report: GFValidationReport = recipe.validate_recipe_report()
	var serialized_report: Dictionary = recipe.validate_recipe()

	assert_true(report.is_ok(), "空分组和重复分组只应作为 warning。")
	assert_false(report.is_healthy(), "存在 warning 时报告不应视为完全健康。")
	assert_eq(report.get_warning_count(), 2, "应报告空分组和重复分组两个 warning。")
	assert_eq(GFVariantData.get_option_string(serialized_report, "recipe_id"), "group_recipe", "字典报告应保留 recipe_id。")
	assert_eq(_find_issue_path(serialized_report, "empty_group"), "groups[1]", "空分组应保留路径。")
	assert_eq(_find_issue_path(serialized_report, "duplicate_group"), "groups[2]", "重复分组应保留路径。")


func test_capability_recipe_validation_reports_empty_recipe_as_healthy() -> void:
	var recipe: GFCapabilityRecipe = GFCapabilityRecipe.new()

	var report: Dictionary = recipe.validate_recipe()

	assert_true(GFVariantData.get_option_bool(report, "ok"), "空 Recipe 没有结构错误时应通过校验。")
	assert_true(GFVariantData.get_option_bool(report, "healthy"), "空 Recipe 没有警告时应视为健康。")
	assert_eq(GFVariantData.get_option_int(report, "entry_count"), 0, "报告应保留条目数量。")
	assert_eq(GFVariantData.get_option_string(report, "summary"), "Capability recipe is healthy.", "健康报告应提供稳定摘要。")


func test_capability_inspector_reads_required_property_without_calling_capability_method() -> void:
	var capability: RequiredByPropertyCapability = RequiredByPropertyCapability.new()
	capability.name = "RequiredByPropertyCapability"
	capability.required_capabilities = [HealthCapability]
	var inspector_plugin: Script = _load_capability_inspector_plugin()

	assert_not_null(inspector_plugin, "应能加载 Capability Inspector 插件。")
	var required_types: Array[Script] = _collect_required_capability_types(inspector_plugin, capability)

	assert_false(capability.get_required_capabilities_called, "编辑器 Inspector 不应调用能力脚本方法。")
	assert_eq(required_types, [HealthCapability], "编辑器 Inspector 应从 required_capabilities 读取依赖。")

	capability.free()


func test_capability_inspector_add_plan_reuses_pending_container_and_names() -> void:
	var inspector_script: Script = _load_capability_inspector_plugin()
	assert_not_null(inspector_script, "应能加载 Capability Inspector 插件。")
	if inspector_script == null:
		return

	var target: Node = Node.new()
	var first: Node = Node.new()
	var second: Node = Node.new()
	var planned: Array[Dictionary] = []

	var first_plan: Dictionary = GFVariantData.as_dictionary(
		inspector_script.call(&"_make_capability_add_plan", target, first, "SharedCapability", planned)
	)
	planned.append(first_plan)
	var second_plan: Dictionary = GFVariantData.as_dictionary(
		inspector_script.call(&"_make_capability_add_plan", target, second, "SharedCapability", planned)
	)
	var first_container: Node = _get_node_value(first_plan.get("container", null))
	var second_container: Node = _get_node_value(second_plan.get("container", null))

	assert_true(GFVariantData.get_option_bool(first_plan, "container_is_new"), "第一条待添加能力应准备新容器。")
	assert_false(GFVariantData.get_option_bool(second_plan, "container_is_new"), "同类待添加能力应复用已计划的新容器。")
	assert_eq(first_container, second_container, "批量添加计划应复用同一个能力容器。")
	assert_eq(String(first.name), "SharedCapability", "第一条能力应使用请求名称。")
	assert_eq(String(second.name), "SharedCapability2", "第二条同名能力应生成稳定唯一名称。")
	assert_eq(GFVariantData.get_option_int(second_plan, "node_index"), 1, "第二条能力应排在同容器下一位。")

	first.free()
	second.free()
	if first_container != null:
		first_container.free()
	target.free()


# --- 私有/辅助方法 ---

func _make_counting_capability_scene() -> PackedScene:
	var node: CountingCapabilityNode = CountingCapabilityNode.new()
	var scene: PackedScene = PackedScene.new()
	var _pack_result_987: Variant = scene.pack(node)
	node.free()
	CountingCapabilityNode.created_nodes.clear()
	return scene


func _find_capability_report_with_dependencies(report: Dictionary) -> Dictionary:
	for entry: Dictionary in GFVariantData.get_option_array(report, "capabilities"):
		var dependencies: PackedStringArray = GFVariantData.get_option_packed_string_array(entry, "registered_dependencies")
		if dependencies.size() > 0:
			return entry
	return {}


func _has_issue(report: Dictionary, kind: String) -> bool:
	for issue_variant: Variant in GFVariantData.get_option_array(report, "issues"):
		if not issue_variant is Dictionary:
			continue
		var issue: Dictionary = issue_variant
		if GFVariantData.get_option_string(issue, "kind") == kind:
			return true
	return false


func _find_issue_path(report: Dictionary, kind: String) -> String:
	for issue_variant: Variant in GFVariantData.get_option_array(report, "issues"):
		if not issue_variant is Dictionary:
			continue
		var issue: Dictionary = issue_variant
		if GFVariantData.get_option_string(issue, "kind") == kind:
			return GFVariantData.get_option_string(issue, "path")
	return ""


func _load_capability_inspector_plugin() -> Script:
	return _load_script(GF_CAPABILITY_INSPECTOR_PLUGIN_PATH)


func _load_script(script_path: String) -> Script:
	var resource: Resource = ResourceLoader.load(script_path, "", ResourceLoader.CACHE_MODE_IGNORE)
	if resource is Script:
		var script: Script = resource
		return script
	return null


func _collect_required_capability_types(inspector_plugin: Script, capability: Node) -> Array[Script]:
	if inspector_plugin == null:
		return []

	var value: Variant = inspector_plugin.call(
		&"collect_required_capability_types",
		capability,
		null,
		"RequiredByPropertyCapability"
	)
	var result: Array[Script] = []
	if value is Array:
		for item: Variant in GFVariantData.as_array(value):
			if item is Script:
				var script: Script = item
				result.append(script)
	return result


func _new_control_node() -> Node:
	var instance: Variant = ClassDB.instantiate("Control")
	return _get_node_value(instance)


func _get_node_value(value: Variant) -> Node:
	if value is Node:
		var node: Node = value
		return node
	return null


func _object_value(value: Variant) -> Object:
	if value is Object:
		var object_value: Object = value
		return object_value
	return null


func _property_bag(value: Object) -> GFPropertyBagCapability:
	if value is GFPropertyBagCapability:
		var bag: GFPropertyBagCapability = value
		return bag
	return null
