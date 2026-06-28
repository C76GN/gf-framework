## 测试 Gf 全局单例的便捷代理方法 (Facade 模式)
extends GutTest


# --- 常量 ---

const INSTALLERS_SETTING: String = "gf/project/installers"
const FAIL_ON_INSTALLER_ERROR_SETTING: String = "gf/project/fail_on_installer_error"
const INSTALLER_TIMEOUT_SETTING: String = "gf/project/installer_timeout_seconds"
const TEST_INSTALLER_PATH: String = "res://tests/gf_core/fixtures/installers/gf_test_installer.gd"
const ASYNC_BINDING_INSTALLER_PATH: String = "res://tests/gf_core/fixtures/installers/gf_async_binding_installer.gd"
const BLOCKING_BINDING_INSTALLER_PATH: String = "res://tests/gf_core/fixtures/installers/gf_blocking_binding_installer.gd"
const INVALID_INSTALLER_PATH: String = "res://tests/gf_core/fixtures/installers/gf_invalid_installer.gd"
const BLOCKING_INSTALLER_STARTED_SETTING: String = "gf/test/blocking_installer_started"
const BLOCKING_INSTALLER_RELEASE_SETTING: String = "gf/test/release_blocking_installer"
const InstallerModelFixture = preload("res://tests/gf_core/fixtures/installers/installer_model_fixture.gd")
const AsyncInstallerUtilityFixture = preload("res://tests/gf_core/fixtures/installers/async_installer_utility_fixture.gd")


# --- 辅助类 ---

class DummyModel extends GFModel:
	pass

class DummySystem extends GFSystem:
	pass

class InheritedBaseTickSystem extends GFSystem:
	var tick_order: Array = []

	func tick(_delta: float) -> void:
		tick_order.append("inherited")

class InheritedConcreteTickSystem extends InheritedBaseTickSystem:
	pass

class DummyUtility extends GFUtility:
	pass

class DirectArchitectureLookupUtility extends GFUtility:
	func get_architecture_directly() -> GFArchitecture:
		return _get_architecture()

class RegistryModelBase extends GFModel:
	pass

class RegistryConcreteModel extends RegistryModelBase:
	var disposed: bool = false

	func dispose() -> void:
		disposed = true

class RegistrySystemBase extends GFSystem:
	pass

class RegistryConcreteSystem extends RegistrySystemBase:
	var disposed: bool = false

	func dispose() -> void:
		disposed = true

class RegistryUtilityBase extends GFUtility:
	pass

class RegistryConcreteUtility extends RegistryUtilityBase:
	var disposed: bool = false

	func dispose() -> void:
		disposed = true

class NotUtility extends RefCounted:
	pass

class NoExecuteObject extends RefCounted:
	pass

class UtilityBase extends GFUtility:
	pass

class ConcreteUtility extends UtilityBase:
	pass

class AlternateConcreteUtility extends UtilityBase:
	pass

class DisposableUtility extends GFUtility:
	var disposed: bool = false

	func dispose() -> void:
		disposed = true

class InjectedUtility extends GFUtility:
	var injected_architecture: GFArchitecture = null

	func inject_dependencies(architecture: GFArchitecture) -> void:
		injected_architecture = architecture

class ReleasingUtility extends GFUtility:
	var release_order: Array[String] = []
	var cached_dependency: Object = RefCounted.new()

	func dispose() -> void:
		release_order.append("dispose")

	func release_dependencies() -> void:
		release_order.append("release_dependencies")
		cached_dependency = null
		super.release_dependencies()

class OverrideInjectedLookupUtility extends GFUtility:
	var injected_architecture: GFArchitecture = null

	func inject_dependencies(architecture: GFArchitecture) -> void:
		injected_architecture = architecture

class ParentScopedUtility extends GFUtility:
	var disposed: bool = false

	func dispose() -> void:
		disposed = true

class LocalScopedUtility extends GFUtility:
	var disposed: bool = false

	func dispose() -> void:
		disposed = true

class LocalLookupSystem extends GFSystem:
	var local_utility: LocalScopedUtility = null
	var parent_utility: ParentScopedUtility = null

	func ready() -> void:
		var local_value: Variant = get_utility(LocalScopedUtility)
		var parent_value: Variant = get_utility(ParentScopedUtility)
		if local_value is LocalScopedUtility:
			local_utility = local_value
		if parent_value is ParentScopedUtility:
			parent_utility = parent_value

class ScopedController extends GFController:
	func get_local_scoped_utility() -> LocalScopedUtility:
		var utility: Variant = get_utility(LocalScopedUtility)
		if utility is LocalScopedUtility:
			return utility
		return null

	func get_parent_scoped_utility() -> ParentScopedUtility:
		var utility: Variant = get_utility(ParentScopedUtility)
		if utility is ParentScopedUtility:
			return utility
		return null

class ControllerHost extends Node:
	pass

class DerivedControllerHost extends ControllerHost:
	pass

class OtherControllerHost extends Node:
	pass

class ScopedContext extends GFNodeContext:
	var local_utility: LocalScopedUtility = null
	var lookup_system: LocalLookupSystem = null

	func _init() -> void:
		scope_mode = GFNodeContext.ScopeMode.SCOPED

	func install(architecture_instance: GFArchitecture) -> void:
		local_utility = LocalScopedUtility.new()
		lookup_system = LocalLookupSystem.new()
		await architecture_instance.register_utility_instance(local_utility)
		await architecture_instance.register_system_instance(lookup_system)

class InheritedContext extends GFNodeContext:
	func _init() -> void:
		scope_mode = GFNodeContext.ScopeMode.INHERITED

class ParentSlowScopedContext extends GFNodeContext:
	var slow_utility: SlowInitUtility = null

	func _init() -> void:
		scope_mode = GFNodeContext.ScopeMode.SCOPED

	func install(architecture_instance: GFArchitecture) -> void:
		slow_utility = SlowInitUtility.new()
		await architecture_instance.register_utility_instance(slow_utility)

class ParentReadyLookupSystem extends GFSystem:
	var parent_ready_at_ready: bool = false

	func ready() -> void:
		var parent_value: Variant = get_utility(SlowInitUtility)
		var parent_utility: SlowInitUtility = parent_value if parent_value is SlowInitUtility else null
		parent_ready_at_ready = parent_utility != null and parent_utility.ready_called

class ChildScopedContext extends GFNodeContext:
	var lookup_system: ParentReadyLookupSystem = null

	func _init() -> void:
		scope_mode = GFNodeContext.ScopeMode.SCOPED

	func install(architecture_instance: GFArchitecture) -> void:
		lookup_system = ParentReadyLookupSystem.new()
		await architecture_instance.register_system_instance(lookup_system)

class ManualInitScopedContext extends GFNodeContext:
	var utility: TickUtility = null

	func _init() -> void:
		scope_mode = GFNodeContext.ScopeMode.SCOPED
		auto_init = false

	func install(architecture_instance: GFArchitecture) -> void:
		utility = TickUtility.new()
		await architecture_instance.register_utility_instance(utility)

class AsyncInstallScopedContext extends GFNodeContext:
	var utility: TickUtility = null
	var install_started: bool = false
	var install_finished: bool = false

	func _init() -> void:
		scope_mode = GFNodeContext.ScopeMode.SCOPED

	func install(architecture_instance: GFArchitecture) -> void:
		install_started = true
		await get_tree().process_frame
		utility = TickUtility.new()
		await architecture_instance.register_utility_instance(utility)
		install_finished = true

class FactoryCommand extends GFCommand:
	func get_parent_utility_from_command() -> ParentScopedUtility:
		var utility: Variant = get_utility(ParentScopedUtility)
		if utility is ParentScopedUtility:
			return utility
		return null

class InjectedFactoryCommand extends GFCommand:
	var injected_architecture: GFArchitecture = null

	func inject_dependencies(architecture: GFArchitecture) -> void:
		super.inject_dependencies(architecture)
		injected_architecture = architecture

class DisposableFactoryCommand extends GFCommand:
	var dispose_count: int = 0
	var event_count: int = 0

	func inject_dependencies(architecture: GFArchitecture) -> void:
		super.inject_dependencies(architecture)
		architecture.register_simple_event_owned(self, &"factory_owned_event", _on_factory_owned_event)

	func dispose() -> void:
		dispose_count += 1

	func _on_factory_owned_event(_payload: Variant) -> void:
		event_count += 1

class TickUtility extends GFUtility:
	var initialized: bool = false
	var ready_called: bool = false
	var async_ready_called: bool = false
	var tick_count: int = 0
	var last_delta: float = 0.0

	func init() -> void:
		initialized = true

	func async_init() -> void:
		async_ready_called = true

	func ready() -> void:
		ready_called = true

	func tick(delta: float) -> void:
		tick_count += 1
		last_delta = delta


class ScalingTimeProvider extends GFTimeProvider:
	var scale: float = 1.0
	var paused: bool = false

	func get_scaled_delta(delta: float) -> float:
		return 0.0 if paused else delta * scale

	func get_physics_scaled_delta_steps(delta: float) -> Array[float]:
		var steps: Array[float] = [get_scaled_delta(delta)]
		return steps

	func should_substep_physics(_delta: float) -> bool:
		return false

	func is_time_paused() -> bool:
		return paused


class RegisteringUtility extends GFUtility:
	var utility_to_register: TickUtility

	func _init(target_utility: TickUtility) -> void:
		utility_to_register = target_utility

	func ready() -> void:
		@warning_ignore("missing_await")
		Gf.register_utility(utility_to_register)


class SlowInitUtility extends GFUtility:
	signal async_continue

	var initialized: bool = false
	var async_started: bool = false
	var ready_called: bool = false

	func init() -> void:
		initialized = true

	func async_init() -> void:
		async_started = true
		await async_continue

	func ready() -> void:
		ready_called = true


class LateRegisteringSlowUtility extends GFUtility:
	signal async_continue

	var utility_to_register: GFUtility
	var async_started: bool = false

	func _init(target_utility: GFUtility) -> void:
		utility_to_register = target_utility

	func async_init() -> void:
		async_started = true
		var arch: GFArchitecture = _get_architecture_or_null()
		await async_continue
		if arch != null:
			await arch.register_utility_instance(utility_to_register)


class SlowTickUtility extends SlowInitUtility:
	var tick_count: int = 0

	func tick(_delta: float) -> void:
		tick_count += 1


class RecordingModel extends GFModel:
	var order: Array

	func _init(p_order: Array) -> void:
		order = p_order

	func async_init() -> void:
		order.append("model")


class RecordingUtility extends GFUtility:
	var order: Array

	func _init(p_order: Array) -> void:
		order = p_order

	func async_init() -> void:
		order.append("utility")


class RecordingSystem extends GFSystem:
	var order: Array

	func _init(p_order: Array) -> void:
		order = p_order

	func async_init() -> void:
		order.append("system")


class LowPriorityLifecycleUtility extends GFUtility:
	var order: Array

	func _init(p_order: Array) -> void:
		order = p_order
		lifecycle_priority = -10

	func async_init() -> void:
		order.append("low")

	func dispose() -> void:
		order.append("dispose_low")


class HighPriorityLifecycleUtility extends GFUtility:
	var order: Array

	func _init(p_order: Array) -> void:
		order = p_order
		lifecycle_priority = 10

	func async_init() -> void:
		order.append("high")

	func dispose() -> void:
		order.append("dispose_high")


class OwnedEventUtility extends GFUtility:
	var event_count: int = 0

	func ready() -> void:
		register_simple_event(&"owned_event", _on_owned_event)

	func _on_owned_event(_payload: Variant) -> void:
		event_count += 1


class TickVictimSystem extends GFSystem:
	var tick_order: Array

	func _init(p_tick_order: Array) -> void:
		tick_order = p_tick_order

	func tick(_delta: float) -> void:
		tick_order.append("victim")


class UnregisteringTickSystem extends GFSystem:
	var tick_order: Array

	func _init(p_tick_order: Array) -> void:
		tick_order = p_tick_order

	func tick(_delta: float) -> void:
		tick_order.append("unregistering")
		_get_architecture().unregister_system(TickVictimSystem)


class LowPriorityTickSystem extends GFSystem:
	var tick_order: Array

	func _init(p_tick_order: Array) -> void:
		tick_order = p_tick_order
		tick_priority = -10

	func tick(_delta: float) -> void:
		tick_order.append("low")


class HighPriorityTickSystem extends GFSystem:
	var tick_order: Array

	func _init(p_tick_order: Array) -> void:
		tick_order = p_tick_order
		tick_priority = 10

	func tick(_delta: float) -> void:
		tick_order.append("high")


class PriorityTickUtility extends GFUtility:
	var tick_order: Array

	func _init(p_tick_order: Array) -> void:
		tick_order = p_tick_order
		tick_priority = 20

	func tick(_delta: float) -> void:
		tick_order.append("utility")


class ReplaceableAsyncUtility extends GFUtility:
	signal async_continue

	var version: String = ""
	var block_async: bool = false
	var async_started: bool = false
	var ready_called: bool = false
	var disposed: bool = false

	func _init(p_version: String = "", p_block_async: bool = false) -> void:
		version = p_version
		block_async = p_block_async

	func async_init() -> void:
		async_started = true
		if block_async:
			await async_continue

	func ready() -> void:
		ready_called = true

	func dispose() -> void:
		disposed = true


class ReadyLookupReplacementUtility extends GFUtility:
	var ready_lookup: ReadyLookupReplacementUtility = null
	var disposed: bool = false

	func ready() -> void:
		var value: Variant = get_utility(ReadyLookupReplacementUtility)
		if value is ReadyLookupReplacementUtility:
			ready_lookup = value

	func dispose() -> void:
		disposed = true


class MissingDependencyUtility extends GFUtility:
	func get_required_models() -> Array:
		return [RegistryConcreteModel]


class LifecycleProbeCommand extends GFCommand:
	var active_during_execute: bool = false

	func execute() -> Variant:
		active_during_execute = is_lifecycle_active()
		return active_during_execute


class DummyQuery extends GFQuery:
	func execute() -> Variant:
		return "query_success"

class UtilityLookupQuery extends GFQuery:
	func execute() -> Variant:
		return get_utility(DummyUtility)

class BaseArchitectureEvent extends RefCounted:
	pass

class ChildArchitectureEvent extends BaseArchitectureEvent:
	pass

class FactoryNode extends Node:
	pass

class WrongFactoryNode extends RefCounted:
	pass

class CountingFactory extends RefCounted:
	var call_count: int = 0

	func create() -> Object:
		call_count += 1
		return FactoryNode.new()

class RecoveringFactory extends RefCounted:
	var call_count: int = 0

	func create() -> Object:
		call_count += 1
		if call_count == 1:
			return WrongFactoryNode.new()
		return FactoryNode.new()

class CyclicFactory extends RefCounted:
	var architecture: GFArchitecture = null
	var call_count: int = 0

	func _init(p_architecture: GFArchitecture) -> void:
		architecture = p_architecture

	func create() -> Object:
		call_count += 1
		if architecture != null:
			return architecture.create_instance(FactoryNode)
		return null

class FallbackAfterRecursiveFactory extends RefCounted:
	var architecture: GFArchitecture = null
	var call_count: int = 0
	var recursive_result_was_null: bool = false

	func _init(p_architecture: GFArchitecture) -> void:
		architecture = p_architecture

	func create() -> Object:
		call_count += 1
		if call_count == 1 and architecture != null:
			var recursive_result: Object = architecture.create_instance(FactoryNode)
			recursive_result_was_null = recursive_result == null
		return FactoryNode.new()

# --- Godot 生命周期方法 ---

func before_each() -> void:
	# 重置并初始化一个干净的架构
	var arch: GFArchitecture = GFArchitecture.new()
	Gf._architecture = arch

	# 注册假数据用于测试
	await Gf.register_model(DummyModel.new())
	await Gf.register_system(DummySystem.new())
	await Gf.register_utility(DummyUtility.new())

	await Gf.set_architecture(arch)

func after_each() -> void:
	if Gf.has_architecture():
		var arch: GFArchitecture = Gf.get_architecture()
		arch.dispose()
		await Gf.set_architecture(GFArchitecture.new())

# --- 测试用例 ---

## 验证 Gf autoload 即使在 Godot 原生暂停下也保持处理。
func test_gf_process_mode_is_always() -> void:
	Gf._ready()

	assert_eq(Gf.process_mode, Node.PROCESS_MODE_ALWAYS, "Gf 应在 SceneTree.paused 时继续驱动框架 tick。")


## 验证 GFAutoload 区分架构存在与架构 ready。
func test_gf_autoload_distinguishes_existing_and_ready_architecture() -> void:
	if Gf.has_architecture():
		Gf.get_architecture().dispose()
	Gf._architecture = null

	var architecture: GFArchitecture = Gf.create_architecture()

	assert_eq(GFAutoload.get_architecture_or_null(), architecture, "架构创建后应能通过 GFAutoload 查询实例。")
	assert_null(GFAutoload.get_ready_architecture_or_null(), "架构完成 init 前不应被视为 ready。")

	await Gf.init()

	assert_eq(GFAutoload.get_ready_architecture_or_null(), architecture, "Gf.init() 完成后应能查询 ready 架构。")


## 验证 Gf.get_model 正确代理到架构
func test_get_model_proxy() -> void:
	var model: DummyModel = Gf.get_model(DummyModel)
	assert_not_null(model, "通过 Gf.get_model 应该能获取到注册的模型")
	assert_true(model is DummyModel, "获取到的类型应该正确")

## 验证 Gf.get_system 正确代理到架构
func test_get_system_proxy() -> void:
	var sys: DummySystem = Gf.get_system(DummySystem)
	assert_not_null(sys, "通过 Gf.get_system 应该能获取到注册的系统")
	assert_true(sys is DummySystem, "获取到的类型应该正确")

## 验证 Gf.get_utility 正确代理到架构
func test_get_utility_proxy() -> void:
	var util: DummyUtility = Gf.get_utility(DummyUtility)
	assert_not_null(util, "通过 Gf.get_utility 应该能获取到注册的工具")
	assert_true(util is DummyUtility, "获取到的类型应该正确")

## 验证 Gf.send_query 正确代理并返回结果
func test_send_query_proxy() -> void:
	var query: DummyQuery = DummyQuery.new()
	var result: String = GFVariantData.to_text(Gf.send_query(query))
	assert_eq(result, "query_success", "Gf.send_query 应当正确执行并返回结果")


## 验证 GFQuery 基类可访问当前架构的 Utility。
func test_query_can_get_utility_from_injected_architecture() -> void:
	var query: UtilityLookupQuery = UtilityLookupQuery.new()
	var result: DummyUtility = _dummy_utility(Gf.send_query(query))

	assert_eq(result, Gf.get_utility(DummyUtility), "GFQuery.get_utility 应当解析当前架构中的 Utility。")


## 验证文档推荐的 register_* -> init 启动流程可用
func test_register_before_init_lazily_creates_architecture() -> void:
	if Gf.has_architecture():
		Gf.get_architecture().dispose()
	Gf._architecture = null

	var model: DummyModel = DummyModel.new()
	var utility: TickUtility = TickUtility.new()

	await Gf.register_model(model)
	await Gf.register_utility(utility)
	await Gf.init()

	assert_true(Gf.has_architecture(), "register_* 应自动创建默认架构。")
	assert_true(Gf.get_architecture().is_inited(), "Gf.init() 应初始化当前架构。")
	assert_eq(Gf.get_model(DummyModel), model, "懒创建架构后应能取回注册的 Model。")
	assert_true(utility.initialized, "Gf.init() 应调用 Utility.init()。")
	assert_true(utility.ready_called, "Gf.init() 应调用 Utility.ready()。")


## 验证 Architecture 会统一驱动带 tick() 的 Utility
func test_architecture_ticks_utility() -> void:
	if Gf.has_architecture():
		Gf.get_architecture().dispose()
	Gf._architecture = null

	var utility: TickUtility = TickUtility.new()
	await Gf.register_utility(utility)
	await Gf.init()

	Gf.get_architecture().tick(0.25)

	assert_eq(utility.tick_count, 1, "Architecture.tick() 应驱动 Utility.tick()。")
	assert_almost_eq(utility.last_delta, 0.25, 0.001, "Utility.tick() 应接收正确 delta。")


## 验证架构初始化完成后动态注册 Utility，会立即补跑生命周期并参与 tick。
func test_dynamic_register_after_init_runs_lifecycle() -> void:
	if Gf.has_architecture():

		Gf.get_architecture().dispose()
	Gf._architecture = null

	await Gf.init()
	var utility: TickUtility = TickUtility.new()
	await Gf.register_utility(utility)

	assert_true(utility.initialized, "初始化后的动态注册应补跑 Utility.init()。")
	assert_true(utility.ready_called, "初始化后的动态注册应补跑 Utility.ready()。")

	Gf.get_architecture().tick(0.5)
	assert_eq(utility.tick_count, 1, "动态注册后的 Utility 应参与架构 tick。")


## 验证初始化完成后动态注册的慢初始化模块，在 ready 前不会被 tick 驱动。
func test_dynamic_register_after_init_does_not_tick_before_ready() -> void:
	if Gf.has_architecture():
		Gf.get_architecture().dispose()
	Gf._architecture = null

	await Gf.init()
	var utility: SlowTickUtility = SlowTickUtility.new()
	@warning_ignore("missing_await")
	Gf.register_utility(utility)
	await get_tree().process_frame

	assert_true(utility.async_started, "动态注册应已经进入 async_init 等待。")
	Gf.get_architecture().tick(0.25)
	assert_eq(utility.tick_count, 0, "async_init 未完成前不应被 tick 驱动。")

	utility.async_continue.emit()
	await get_tree().process_frame
	await get_tree().process_frame

	assert_true(utility.ready_called, "动态注册慢初始化完成后应进入 ready。")
	var tick_count_after_ready: int = utility.tick_count
	Gf.get_architecture().tick(0.25)
	assert_eq(utility.tick_count, tick_count_after_ready + 1, "ready 后应恢复正常 tick。")


## 验证初始化期间动态注册的 Utility 也会补跑完整生命周期。
func test_register_during_init_receives_full_lifecycle() -> void:
	if Gf.has_architecture():
		Gf.get_architecture().dispose()
	Gf._architecture = null

	var late_utility: TickUtility = TickUtility.new()
	var registering_utility: RegisteringUtility = RegisteringUtility.new(late_utility)

	await Gf.register_utility(registering_utility)
	await Gf.init()

	assert_true(late_utility.initialized, "初始化过程中动态注册的 Utility 也应执行 init()。")
	assert_true(late_utility.async_ready_called, "初始化过程中动态注册的 Utility 也应执行 async_init()。")
	assert_true(late_utility.ready_called, "初始化过程中动态注册的 Utility 也应执行 ready()。")

	Gf.get_architecture().tick(0.25)
	assert_eq(late_utility.tick_count, 1, "初始化过程中动态注册的 Utility 完成后应参与后续 tick。")


## 验证三阶段生命周期在每个阶段按 Model -> Utility -> System 推进。
func test_lifecycle_stage_order_prefers_utilities_before_systems() -> void:
	if Gf.has_architecture():
		Gf.get_architecture().dispose()
	Gf._architecture = null

	var order: Array = []
	var arch: GFArchitecture = GFArchitecture.new()
	await arch.register_model_instance(RecordingModel.new(order))
	await arch.register_system_instance(RecordingSystem.new(order))
	await arch.register_utility_instance(RecordingUtility.new(order))

	await Gf.set_architecture(arch)

	assert_eq(order, ["model", "utility", "system"], "async_init 阶段应先完成 Model，再完成 Utility，最后进入 System。")


## 验证同一模块类型内生命周期优先级越高越早初始化、越晚释放。
func test_lifecycle_priority_orders_modules_within_same_registry() -> void:
	var order: Array = []
	var arch: GFArchitecture = GFArchitecture.new()
	await arch.register_utility_instance(LowPriorityLifecycleUtility.new(order))
	await arch.register_utility_instance(HighPriorityLifecycleUtility.new(order))

	await arch.init()

	assert_eq(order, ["high", "low"], "同类模块内高 lifecycle_priority 应更早进入生命周期阶段。")

	arch.dispose()
	assert_eq(order, ["high", "low", "dispose_low", "dispose_high"], "释放时高 lifecycle_priority 应更晚释放。")


## 验证可通过显式 alias 以抽象基类获取具体实现。
func test_register_utility_alias_resolves_base_type() -> void:
	if Gf.has_architecture():
		Gf.get_architecture().dispose()
	Gf._architecture = null

	var concrete: ConcreteUtility = ConcreteUtility.new()
	var alternate: AlternateConcreteUtility = AlternateConcreteUtility.new()

	await Gf.register_utility(concrete)
	await Gf.register_utility(alternate)
	Gf.register_utility_alias(UtilityBase, ConcreteUtility)
	await Gf.init()

	assert_eq(Gf.get_utility(UtilityBase), concrete, "显式 alias 应让基类查询解析到指定实现。")


func test_register_utility_alias_rejects_unrelated_target_type() -> void:
	var arch: GFArchitecture = GFArchitecture.new()
	var concrete: ConcreteUtility = ConcreteUtility.new()
	await arch.register_utility_instance(concrete)

	arch.register_utility_alias(NotUtility, ConcreteUtility)

	assert_push_error("[GFArchitecture] register_utility_alias 失败：target 必须继承或等于 alias。")
	assert_null(arch.get_utility(NotUtility), "无关 alias 不应写入注册表。")
	arch.dispose()


## 验证 alias 注销与目标模块注销保持分离。
func test_module_registry_alias_unregister_does_not_remove_targets() -> void:
	var arch: GFArchitecture = GFArchitecture.new()
	var model: RegistryConcreteModel = RegistryConcreteModel.new()
	var system: RegistryConcreteSystem = RegistryConcreteSystem.new()
	var utility: RegistryConcreteUtility = RegistryConcreteUtility.new()

	await arch.register_model_instance(model)
	await arch.register_system_instance(system)
	await arch.register_utility_instance(utility)
	arch.register_model_alias(RegistryModelBase, RegistryConcreteModel)
	arch.register_system_alias(RegistrySystemBase, RegistryConcreteSystem)
	arch.register_utility_alias(RegistryUtilityBase, RegistryConcreteUtility)

	assert_eq(arch.get_model(RegistryModelBase), model, "Model alias 应解析到目标实例。")
	assert_eq(arch.get_system(RegistrySystemBase), system, "System alias 应解析到目标实例。")
	assert_eq(arch.get_utility(RegistryUtilityBase), utility, "Utility alias 应解析到目标实例。")

	arch.unregister_model(RegistryModelBase)
	arch.unregister_system(RegistrySystemBase)
	arch.unregister_utility(RegistryUtilityBase)

	assert_push_error_count(3, "通过 alias 调用 unregister_* 应提示使用 unregister_*_alias。")
	assert_false(model.disposed, "unregister_model(alias) 不应释放目标 Model。")
	assert_false(system.disposed, "unregister_system(alias) 不应释放目标 System。")
	assert_false(utility.disposed, "unregister_utility(alias) 不应释放目标 Utility。")
	assert_eq(arch.get_model(RegistryConcreteModel), model, "目标 Model 应继续直接可查。")
	assert_eq(arch.get_system(RegistryConcreteSystem), system, "目标 System 应继续直接可查。")
	assert_eq(arch.get_utility(RegistryConcreteUtility), utility, "目标 Utility 应继续直接可查。")

	arch.unregister_model_alias(RegistryModelBase)
	arch.unregister_system_alias(RegistrySystemBase)
	arch.unregister_utility_alias(RegistryUtilityBase)

	var alias_state: Dictionary = GFVariantData.get_option_dictionary(arch.get_debug_lifecycle_state(), "aliases")
	assert_eq(GFVariantData.get_option_int(alias_state, "models", -1), 0, "显式注销 Model alias 后 alias 计数应归零。")
	assert_eq(GFVariantData.get_option_int(alias_state, "systems", -1), 0, "显式注销 System alias 后 alias 计数应归零。")
	assert_eq(GFVariantData.get_option_int(alias_state, "utilities", -1), 0, "显式注销 Utility alias 后 alias 计数应归零。")
	assert_false(model.disposed, "注销 alias 不应释放目标 Model。")
	assert_false(system.disposed, "注销 alias 不应释放目标 System。")
	assert_false(utility.disposed, "注销 alias 不应释放目标 Utility。")

	arch.unregister_model(RegistryConcreteModel)
	arch.unregister_system(RegistryConcreteSystem)
	arch.unregister_utility(RegistryConcreteUtility)

	assert_true(model.disposed, "直接注销目标 Model 才应释放实例。")
	assert_true(system.disposed, "直接注销目标 System 才应释放实例。")
	assert_true(utility.disposed, "直接注销目标 Utility 才应释放实例。")
	arch.dispose()


## 验证隐式基类查询缓存会在注册表变化时失效，避免返回旧的唯一匹配。
func test_assignable_lookup_cache_invalidates_when_registry_changes() -> void:
	var arch: GFArchitecture = GFArchitecture.new()
	var concrete: ConcreteUtility = ConcreteUtility.new()
	var alternate: AlternateConcreteUtility = AlternateConcreteUtility.new()

	await arch.register_utility_instance(concrete)
	assert_eq(arch.get_utility(UtilityBase), concrete, "首次基类查询应解析到唯一实现。")

	await arch.register_utility_instance(alternate)
	assert_null(arch.get_utility(UtilityBase), "新增第二个实现后，旧的基类查询缓存不应继续返回旧实例。")

	arch.unregister_utility(AlternateConcreteUtility)
	assert_eq(arch.get_utility(UtilityBase), concrete, "移除歧义实现后，基类查询应重新解析唯一实现。")
	arch.dispose()


## 验证重复注册会给出明确 warning，且 replace_utility 会释放旧实例并接管新实例。
func test_duplicate_register_warns_and_replace_utility() -> void:
	if Gf.has_architecture():
		Gf.get_architecture().dispose()
	Gf._architecture = null

	var old_utility: DisposableUtility = DisposableUtility.new()
	var duplicate_utility: DisposableUtility = DisposableUtility.new()

	await Gf.register_utility(old_utility)
	await Gf.register_utility(duplicate_utility)

	assert_push_warning("[GFArchitecture] register_utility：类型已注册，已忽略重复注册。启用扩展的 Installer 会先于项目 Installer 自动装配其模块；项目通常只注册自身模块。若需要替换，请使用 replace_utility()。")
	assert_eq(Gf.get_utility(DisposableUtility), old_utility, "重复注册不应替换原实例。")

	await Gf.replace_utility(duplicate_utility)

	assert_true(old_utility.disposed, "replace_utility 应释放旧实例。")
	assert_eq(Gf.get_utility(DisposableUtility), duplicate_utility, "replace_utility 应注册新实例。")


## 验证同一模块实例不能被多个脚本键重复注册。
func test_register_rejects_same_instance_under_multiple_keys() -> void:
	var arch: GFArchitecture = GFArchitecture.new()
	var concrete: ConcreteUtility = ConcreteUtility.new()

	await arch.register_utility(ConcreteUtility, concrete)
	await arch.register_utility(UtilityBase, concrete)

	var state: Dictionary = arch.get_debug_lifecycle_state()
	var utilities: Dictionary = GFVariantData.get_option_dictionary(state, "utilities")

	assert_push_error_count(1, "同一实例用第二个脚本键注册时应报错。")
	assert_eq(utilities.size(), 1, "重复实例注册失败后注册表中应只有一个 Utility。")
	assert_eq(arch.get_utility(ConcreteUtility), concrete, "原始注册应保持可用。")
	arch.dispose()


## 验证已初始化架构替换模块时，新实例未准备好不会破坏旧实例。
func test_replace_utility_timeout_keeps_old_instance() -> void:
	var arch: GFArchitecture = GFArchitecture.new()
	arch.module_async_init_timeout_seconds = 0.001
	var old_utility: ReplaceableAsyncUtility = ReplaceableAsyncUtility.new("old", false)
	var new_utility: ReplaceableAsyncUtility = ReplaceableAsyncUtility.new("new", true)

	await arch.register_utility_instance(old_utility)
	await arch.init()
	await arch.replace_utility(ReplaceableAsyncUtility, new_utility)

	assert_true(new_utility.async_started, "替换实例应进入 async_init。")
	assert_true(new_utility.disposed, "替换失败的新实例应被 dispose。")
	assert_false(old_utility.disposed, "替换失败不应释放旧实例。")
	assert_eq(arch.get_utility(ReplaceableAsyncUtility), old_utility, "替换失败后旧实例应继续可用。")
	assert_push_error_count(1, "替换 async_init 超时时应输出错误。")

	new_utility.async_continue.emit()
	await get_tree().process_frame
	arch.dispose()


## 验证已初始化架构替换模块时，ready 阶段查询应解析到替换后的新实例。
func test_replace_utility_ready_lookup_resolves_replacement_instance() -> void:
	var arch: GFArchitecture = GFArchitecture.new()
	var old_utility: ReadyLookupReplacementUtility = ReadyLookupReplacementUtility.new()
	var new_utility: ReadyLookupReplacementUtility = ReadyLookupReplacementUtility.new()

	await arch.register_utility_instance(old_utility)
	await arch.init()
	await arch.replace_utility(ReadyLookupReplacementUtility, new_utility)

	assert_eq(new_utility.ready_lookup, new_utility, "替换实例 ready() 中的查询应返回新实例。")
	assert_true(old_utility.disposed, "替换成功后旧实例应被释放。")
	assert_false(new_utility.disposed, "替换成功的新实例不应被释放。")
	arch.dispose()


## 验证模块可通过 inject_dependencies 接收当前架构引用。
func test_register_injects_architecture_when_hook_exists() -> void:
	var arch: GFArchitecture = GFArchitecture.new()
	var utility: InjectedUtility = InjectedUtility.new()

	await arch.register_utility_instance(utility)

	assert_eq(utility.injected_architecture, arch, "注册时应把当前架构注入到模块。")
	assert_eq(utility.get_utility(InjectedUtility), utility, "覆写 inject_dependencies 且未调用 super 时，基类访问仍应绑定当前架构。")
	arch.unregister_utility(InjectedUtility)
	assert_null(utility.get_utility(InjectedUtility), "注销后即使自定义注入 Hook 未调用 super，也不应回退全局架构。")
	assert_push_error("[GFUtility] 依赖作用域已释放，无法继续访问架构。")
	arch.dispose()


func test_unregister_utility_releases_cached_dependencies_after_dispose() -> void:
	var arch: GFArchitecture = GFArchitecture.new()
	var utility: ReleasingUtility = ReleasingUtility.new()

	await arch.register_utility_instance(utility)
	arch.unregister_utility(ReleasingUtility)

	assert_eq(utility.release_order, ["dispose", "release_dependencies"], "注销模块时应先 dispose，再释放依赖引用。")
	assert_null(utility.cached_dependency, "release_dependencies 应能释放模块缓存的依赖引用。")
	assert_null(utility.get_utility(ReleasingUtility), "释放依赖后不应继续访问已注销架构。")
	assert_push_error("[GFUtility] 依赖作用域已释放，无法继续访问架构。")
	arch.dispose()


func test_architecture_dispose_releases_module_dependencies_after_dispose() -> void:
	var arch: GFArchitecture = GFArchitecture.new()
	var utility: ReleasingUtility = ReleasingUtility.new()

	await arch.register_utility_instance(utility)
	arch.dispose()

	assert_eq(utility.release_order, ["dispose", "release_dependencies"], "架构 dispose 应先释放模块自身，再释放依赖引用。")
	assert_null(utility.cached_dependency, "架构 dispose 应调用模块依赖释放钩子。")
	assert_null(utility.get_utility(ReleasingUtility), "架构 dispose 后模块不应回退全局架构。")
	assert_push_error("[GFUtility] 依赖作用域已释放，无法继续访问架构。")


## 验证模块覆写 inject_dependencies 且不调用 super 时，基类依赖访问仍绑定当前架构。
func test_register_sets_internal_scope_before_custom_inject_hook() -> void:
	var arch: GFArchitecture = GFArchitecture.new()
	var utility: OverrideInjectedLookupUtility = OverrideInjectedLookupUtility.new()

	await arch.register_utility_instance(utility)

	assert_eq(utility.injected_architecture, arch, "自定义 inject_dependencies 仍应接收当前架构。")
	assert_eq(utility.get_utility(OverrideInjectedLookupUtility), utility, "内部依赖作用域应先于自定义注入钩子绑定。")
	arch.dispose()


## 验证注销后的模块不会继续通过基类访问回退到全局架构。
func test_unregistered_utility_does_not_fallback_to_global_architecture() -> void:
	var arch: GFArchitecture = GFArchitecture.new()
	var utility: DummyUtility = DummyUtility.new()

	await arch.register_utility_instance(utility)
	arch.unregister_utility(DummyUtility)

	assert_null(utility.get_utility(DummyUtility), "注销后的 Utility 不应回退访问全局架构。")
	assert_push_error("[GFUtility] 依赖作用域已释放，无法继续访问架构。")
	arch.dispose()


## 验证释放后的内部架构访问不会绕过作用域保护回退到全局架构。
func test_released_internal_scope_does_not_fallback_to_global_architecture() -> void:
	var previous_global_architecture: GFArchitecture = Gf._architecture
	var global_arch: GFArchitecture = GFArchitecture.new()
	var local_arch: GFArchitecture = GFArchitecture.new()
	var utility: DirectArchitectureLookupUtility = DirectArchitectureLookupUtility.new()
	Gf._architecture = global_arch

	await local_arch.register_utility_instance(utility)
	local_arch.unregister_utility(DirectArchitectureLookupUtility)
	var resolved: GFArchitecture = utility.get_architecture_directly()

	Gf._architecture = previous_global_architecture
	global_arch.dispose()
	local_arch.dispose()

	assert_null(resolved, "释放后的内部 _get_architecture() 不应回退到全局架构。")
	assert_push_error("[GFUtility] 依赖作用域已释放，无法继续访问架构。")


## 验证子架构未命中本地依赖时会回退到父架构。
func test_child_architecture_falls_back_to_parent() -> void:
	var parent_arch: GFArchitecture = GFArchitecture.new()
	var parent_utility: ParentScopedUtility = ParentScopedUtility.new()
	await parent_arch.register_utility_instance(parent_utility)

	var child_arch: GFArchitecture = GFArchitecture.new(parent_arch)

	assert_eq(child_arch.get_utility(ParentScopedUtility), parent_utility, "子架构应能回退获取父级 Utility。")

	child_arch.dispose()
	parent_arch.dispose()


## 验证严格依赖查询模式不会静默回退父架构。
func test_strict_dependency_lookup_blocks_parent_fallback() -> void:
	var parent_arch: GFArchitecture = GFArchitecture.new()
	var parent_utility: ParentScopedUtility = ParentScopedUtility.new()
	await parent_arch.register_utility_instance(parent_utility)

	var child_arch: GFArchitecture = GFArchitecture.new(parent_arch)
	child_arch.strict_dependency_lookup = true
	var resolved: ParentScopedUtility = _parent_scoped_utility(child_arch.get_utility(ParentScopedUtility))

	assert_null(resolved, "严格查询模式下，子架构缺失本地 Utility 时不应回退父架构。")
	assert_push_error_count(1, "严格查询缺失依赖时应输出明确错误。")

	child_arch.dispose()
	parent_arch.dispose()


## 验证子架构中的失效 alias 不会遮蔽父架构回退。
func test_stale_child_alias_does_not_shadow_parent_fallback() -> void:
	var parent_arch: GFArchitecture = GFArchitecture.new()
	var parent_utility: ConcreteUtility = ConcreteUtility.new()
	await parent_arch.register_utility_instance(parent_utility)

	var child_arch: GFArchitecture = GFArchitecture.new(parent_arch)
	child_arch.register_utility_alias(UtilityBase, ConcreteUtility)

	assert_push_warning("[GFArchitecture] register_utility_alias：目标类型尚未注册，仍会记录别名。")
	assert_eq(child_arch.get_utility(UtilityBase), parent_utility, "子架构失效 alias 不应阻断父架构基类回退。")
	assert_push_error_count(1, "失效 alias 查询应报告目标缺失。")

	child_arch.dispose()
	parent_arch.dispose()


func test_stale_alias_does_not_fallback_to_local_assignable_instance() -> void:
	var arch: GFArchitecture = GFArchitecture.new()
	var alternate_utility: AlternateConcreteUtility = AlternateConcreteUtility.new()
	await arch.register_utility_instance(alternate_utility)

	arch.register_utility_alias(UtilityBase, ConcreteUtility)
	var resolved: Object = arch.get_utility(UtilityBase)

	assert_push_warning("[GFArchitecture] register_utility_alias：目标类型尚未注册，仍会记录别名。")
	assert_null(resolved, "失效 alias 不应回落到同架构内另一个可赋值实现。")
	assert_push_error_count(1, "失效 alias 查询应报告目标缺失。")

	arch.dispose()


## 验证子架构本地已注册但未 ready 的模块不会在 require_ready 查询中偷用父级同类型模块。
func test_child_local_unready_module_shadows_parent_require_ready_lookup() -> void:
	var parent_arch: GFArchitecture = GFArchitecture.new()
	var parent_utility: ParentScopedUtility = ParentScopedUtility.new()
	await parent_arch.register_utility_instance(parent_utility)
	await parent_arch.init()

	var child_arch: GFArchitecture = GFArchitecture.new(parent_arch)
	var child_utility: ParentScopedUtility = ParentScopedUtility.new()
	await child_arch.register_utility_instance(child_utility)

	assert_eq(child_arch.get_utility(ParentScopedUtility), child_utility, "普通查询应返回子架构本地实例。")
	assert_null(child_arch.get_utility(ParentScopedUtility, true), "本地存在但未 ready 的实例应遮蔽父级同类型 ready 实例。")
	assert_eq(child_arch.get_local_utility(ParentScopedUtility), child_utility, "本地查询仍应能看到未 ready 的本地实例。")

	child_arch.dispose()
	parent_arch.dispose()


## 验证注册时会拒绝与目标槽位不匹配的实例。
func test_register_utility_rejects_wrong_base_type() -> void:
	var arch: GFArchitecture = GFArchitecture.new()

	await arch.register_utility_instance(NotUtility.new())

	assert_push_error("[GFArchitecture] register_utility 失败：实例类型必须继承 GFUtility。")
	assert_null(arch.get_utility(NotUtility), "非 GFUtility 实例不应进入 Utility 注册表。")
	arch.dispose()


## 验证声明式 Binder 可以注册模块、别名与短生命周期工厂。
func test_binder_registers_modules_alias_and_factory_lifetimes() -> void:
	var arch: GFArchitecture = GFArchitecture.new()
	var binder: GFBinder = arch.create_binder()
	var utility: ConcreteUtility = ConcreteUtility.new()

	await binder.bind_utility(ConcreteUtility).from_instance(utility).with_alias(UtilityBase).as_singleton()
	binder.bind_factory(InjectedFactoryCommand).from_factory(func() -> Object:
		return InjectedFactoryCommand.new()
	).as_transient()
	await binder.bind_factory(FactoryCommand).from_factory(func() -> Object:
		return FactoryCommand.new()
	).as_singleton()

	var transient_a: InjectedFactoryCommand = _injected_factory_command(arch.create_instance(InjectedFactoryCommand))
	var transient_b: InjectedFactoryCommand = _injected_factory_command(arch.create_instance(InjectedFactoryCommand))
	var singleton_a: FactoryCommand = _factory_command(arch.create_instance(FactoryCommand))
	var singleton_b: FactoryCommand = _factory_command(arch.create_instance(FactoryCommand))

	assert_eq(arch.get_utility(UtilityBase), utility, "Binder 应支持模块 alias 注册。")
	assert_ne(transient_a, transient_b, "Transient 工厂每次应返回新实例。")
	assert_eq(transient_a.injected_architecture, arch, "Transient 工厂结果应注入当前架构。")
	assert_eq(singleton_a, singleton_b, "Singleton 工厂应缓存同一实例。")

	arch.dispose()


## 验证已有实例不能伪装成 transient 工厂，避免静默退化为单例。
func test_binder_rejects_transient_factory_from_instance() -> void:
	var arch: GFArchitecture = GFArchitecture.new()
	var binder: GFBinder = arch.create_binder()
	var command: FactoryCommand = FactoryCommand.new()

	binder.bind_factory(FactoryCommand).from_instance(command).as_transient()

	assert_false(arch.has_factory(FactoryCommand), "from_instance().as_transient() 不应注册单例工厂。")
	assert_push_error("[GFBindBuilder] from_instance() 不支持 as_transient()；请改用 from_factory()。")
	arch.dispose()


## 验证 factory 绑定不支持 alias 时会提示，避免误以为 alias 已生效。
func test_factory_binding_warns_when_alias_is_ignored() -> void:
	var arch: GFArchitecture = GFArchitecture.new()
	var binder: GFBinder = arch.create_binder()

	binder.bind_factory(FactoryCommand).with_alias(UtilityBase).as_transient()

	assert_true(arch.has_factory(FactoryCommand), "Factory alias 被忽略时，原始工厂绑定仍应完成。")
	assert_push_warning("[GFBindBuilder] with_alias() 仅对 Model/System/Utility 有效，Factory 绑定会忽略 alias。")
	arch.dispose()


func test_register_factory_instance_does_not_dispose_external_instance() -> void:
	var arch: GFArchitecture = GFArchitecture.new()
	var command: DisposableFactoryCommand = DisposableFactoryCommand.new()

	arch.register_factory_instance(DisposableFactoryCommand, command)
	var resolved: Object = arch.create_instance(DisposableFactoryCommand)
	arch.unregister_factory(DisposableFactoryCommand)

	assert_same(resolved, command, "外部实例工厂应返回传入实例。")
	assert_eq(command.dispose_count, 0, "注销外部实例工厂不应调用项目对象的 dispose()。")
	arch.dispose()


## 验证项目 Installer 会在 Gf.init() 初始化前自动注册模块。
func test_project_installer_registers_modules_before_init() -> void:
	var previous_installers: Variant = ProjectSettings.get_setting(INSTALLERS_SETTING, [])
	ProjectSettings.set_setting(INSTALLERS_SETTING, [TEST_INSTALLER_PATH])

	if Gf.has_architecture():
		Gf.get_architecture().dispose()
	Gf._architecture = null

	await Gf.init()

	var installed_model: InstallerModelFixture = Gf.get_model(InstallerModelFixture)

	ProjectSettings.set_setting(INSTALLERS_SETTING, previous_installers)

	assert_not_null(installed_model, "项目 Installer 应在初始化前注册 Model。")
	assert_true(installed_model.installed, "Installer 注册的 Model 应保留自身状态。")


## 验证项目 Installer 的异步 install_bindings 会在架构 init 前完成。
func test_project_installer_awaits_async_install_bindings_before_init() -> void:
	var previous_installers: Variant = ProjectSettings.get_setting(INSTALLERS_SETTING, [])
	ProjectSettings.set_setting(INSTALLERS_SETTING, [ASYNC_BINDING_INSTALLER_PATH])

	if Gf.has_architecture():
		Gf.get_architecture().dispose()
	Gf._architecture = null

	await Gf.init()

	var installed_utility: AsyncInstallerUtilityFixture = _async_installer_utility(Gf.get_utility(AsyncInstallerUtilityFixture))

	ProjectSettings.set_setting(INSTALLERS_SETTING, previous_installers)

	assert_not_null(installed_utility, "异步 install_bindings 注册的 Utility 应在 init 后可获取。")
	assert_true(installed_utility.ready_called, "异步 install_bindings 注册的 Utility 应参与本轮生命周期。")


## 验证启用扩展的 Installer 会在 Gf.init() 初始化前自动注册扩展级服务。
func test_enabled_extension_installer_registers_services_before_init() -> void:
	var previous_installers: Variant = ProjectSettings.get_setting(INSTALLERS_SETTING, [])
	var previous_extensions: Variant = ProjectSettings.get_setting(GFExtensionSettings.ENABLED_EXTENSIONS_SETTING, [])
	var previous_auto_install: Variant = ProjectSettings.get_setting(
		GFExtensionSettings.AUTO_INSTALL_ENABLED_INSTALLERS_SETTING,
		true
	)
	ProjectSettings.set_setting(INSTALLERS_SETTING, [])
	ProjectSettings.set_setting(GFExtensionSettings.ENABLED_EXTENSIONS_SETTING, ["gf.save"])
	ProjectSettings.set_setting(GFExtensionSettings.AUTO_INSTALL_ENABLED_INSTALLERS_SETTING, true)

	if Gf.has_architecture():
		Gf.get_architecture().dispose()
	Gf._architecture = null

	await Gf.init()
	var save_graph_utility: Object = Gf.get_utility(GFSaveGraphUtility)

	ProjectSettings.set_setting(INSTALLERS_SETTING, previous_installers)
	ProjectSettings.set_setting(GFExtensionSettings.ENABLED_EXTENSIONS_SETTING, previous_extensions)
	ProjectSettings.set_setting(GFExtensionSettings.AUTO_INSTALL_ENABLED_INSTALLERS_SETTING, previous_auto_install)

	assert_not_null(save_graph_utility, "启用扩展 installer 应在三阶段初始化前注册扩展级服务。")


## 验证 Installer 配置错误默认会中断架构初始化并记录失败原因。
func test_project_installer_error_fails_initialization_by_default() -> void:
	var previous_installers: Variant = ProjectSettings.get_setting(INSTALLERS_SETTING, [])
	var had_fail_on_error: bool = ProjectSettings.has_setting(FAIL_ON_INSTALLER_ERROR_SETTING)
	var previous_fail_on_error: Variant = ProjectSettings.get_setting(FAIL_ON_INSTALLER_ERROR_SETTING, true)
	ProjectSettings.set_setting(INSTALLERS_SETTING, [INVALID_INSTALLER_PATH])
	ProjectSettings.set_setting(FAIL_ON_INSTALLER_ERROR_SETTING, null)

	if Gf.has_architecture():
		Gf.get_architecture().dispose()
	Gf._architecture = null

	await Gf.init()
	var architecture: GFArchitecture = Gf.get_architecture()

	ProjectSettings.set_setting(INSTALLERS_SETTING, previous_installers)
	_restore_project_setting(FAIL_ON_INSTALLER_ERROR_SETTING, had_fail_on_error, previous_fail_on_error)

	assert_false(architecture.is_inited(), "默认 Installer 错误策略下架构不应继续初始化。")
	assert_true(architecture.has_initialization_failed(), "默认 Installer 错误策略下应标记初始化失败。")
	assert_eq(architecture.last_initialization_error, "[GF] 项目 Installer 必须继承 GFInstaller：%s" % INVALID_INSTALLER_PATH)
	assert_push_error("[GF] 项目 Installer 必须继承 GFInstaller：%s" % INVALID_INSTALLER_PATH)
	assert_push_error("[GF] 项目 Installer 必须继承 GFInstaller：%s" % INVALID_INSTALLER_PATH)

	await Gf.init()
	assert_true(architecture.is_inited(), "修正 Installer 配置后再次 Gf.init() 应允许重试初始化。")
	assert_false(architecture.has_initialization_failed(), "重试成功后应清除旧的初始化失败状态。")


## 验证显式关闭 Installer 错误失败时仍会跳过无效项，便于迁移期临时兼容。
func test_project_installer_error_can_be_skipped_when_disabled() -> void:
	var previous_installers: Variant = ProjectSettings.get_setting(INSTALLERS_SETTING, [])
	var had_fail_on_error: bool = ProjectSettings.has_setting(FAIL_ON_INSTALLER_ERROR_SETTING)
	var previous_fail_on_error: Variant = ProjectSettings.get_setting(FAIL_ON_INSTALLER_ERROR_SETTING, true)
	ProjectSettings.set_setting(INSTALLERS_SETTING, [INVALID_INSTALLER_PATH])
	ProjectSettings.set_setting(FAIL_ON_INSTALLER_ERROR_SETTING, false)

	if Gf.has_architecture():
		Gf.get_architecture().dispose()
	Gf._architecture = null

	await Gf.init()
	var architecture: GFArchitecture = Gf.get_architecture()

	ProjectSettings.set_setting(INSTALLERS_SETTING, previous_installers)
	_restore_project_setting(FAIL_ON_INSTALLER_ERROR_SETTING, had_fail_on_error, previous_fail_on_error)

	assert_true(architecture.is_inited(), "显式关闭 Installer 错误失败后，架构应继续初始化。")
	assert_false(architecture.has_initialization_failed(), "显式关闭 Installer 错误失败后，不应标记初始化失败。")
	assert_push_error("[GF] 项目 Installer 必须继承 GFInstaller：%s" % INVALID_INSTALLER_PATH)


## 验证并发 Gf.init() 会等待正在运行的项目 Installer，而不是跳过未完成的装配。
func test_concurrent_gf_init_waits_for_active_project_installers() -> void:
	var previous_installers: Variant = ProjectSettings.get_setting(INSTALLERS_SETTING, [])
	var previous_started: Variant = ProjectSettings.get_setting(BLOCKING_INSTALLER_STARTED_SETTING, false)
	var previous_release: Variant = ProjectSettings.get_setting(BLOCKING_INSTALLER_RELEASE_SETTING, false)
	ProjectSettings.set_setting(INSTALLERS_SETTING, [BLOCKING_BINDING_INSTALLER_PATH])
	ProjectSettings.set_setting(BLOCKING_INSTALLER_STARTED_SETTING, false)
	ProjectSettings.set_setting(BLOCKING_INSTALLER_RELEASE_SETTING, false)

	if Gf.has_architecture():
		Gf.get_architecture().dispose()
	Gf._architecture = null

	var first_state: Dictionary = { "done": false }
	var second_state: Dictionary = { "done": false }
	@warning_ignore("missing_await")
	_await_gf_init(first_state)
	await get_tree().process_frame
	await get_tree().process_frame
	@warning_ignore("missing_await")
	_await_gf_init(second_state)
	await get_tree().process_frame

	assert_true(GFVariantData.to_bool(ProjectSettings.get_setting(BLOCKING_INSTALLER_STARTED_SETTING, false)), "第一轮 init 应已进入阻塞 Installer。")
	assert_false(GFVariantData.get_option_bool(second_state, "done"), "第二个 Gf.init() 不应在 Installer 完成前提前返回。")

	ProjectSettings.set_setting(BLOCKING_INSTALLER_RELEASE_SETTING, true)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame

	var installed_utility: AsyncInstallerUtilityFixture = _async_installer_utility(Gf.get_utility(AsyncInstallerUtilityFixture))

	ProjectSettings.set_setting(INSTALLERS_SETTING, previous_installers)
	ProjectSettings.set_setting(BLOCKING_INSTALLER_STARTED_SETTING, previous_started)
	ProjectSettings.set_setting(BLOCKING_INSTALLER_RELEASE_SETTING, previous_release)

	assert_true(GFVariantData.get_option_bool(first_state, "done"), "第一轮 Gf.init() 应正常完成。")
	assert_true(GFVariantData.get_option_bool(second_state, "done"), "第二个 Gf.init() 应等待同一轮 Installer 和初始化完成。")
	assert_not_null(installed_utility, "阻塞 Installer 完成后注册的 Utility 应可获取。")
	assert_true(installed_utility.ready_called, "阻塞 Installer 注册的 Utility 应参与本轮生命周期。")


## 验证项目 Installer 单步超时会中断初始化并记录失败原因。
func test_project_installer_timeout_fails_initialization() -> void:
	var previous_installers: Variant = ProjectSettings.get_setting(INSTALLERS_SETTING, [])
	var previous_timeout: Variant = ProjectSettings.get_setting(INSTALLER_TIMEOUT_SETTING, 0.0)
	var previous_started: Variant = ProjectSettings.get_setting(BLOCKING_INSTALLER_STARTED_SETTING, false)
	var previous_release: Variant = ProjectSettings.get_setting(BLOCKING_INSTALLER_RELEASE_SETTING, false)
	ProjectSettings.set_setting(INSTALLERS_SETTING, [BLOCKING_BINDING_INSTALLER_PATH])
	ProjectSettings.set_setting(INSTALLER_TIMEOUT_SETTING, 0.01)
	ProjectSettings.set_setting(BLOCKING_INSTALLER_STARTED_SETTING, false)
	ProjectSettings.set_setting(BLOCKING_INSTALLER_RELEASE_SETTING, false)

	if Gf.has_architecture():
		Gf.get_architecture().dispose()
	Gf._architecture = null

	await Gf.init()
	var architecture: GFArchitecture = Gf.get_architecture()

	ProjectSettings.set_setting(BLOCKING_INSTALLER_RELEASE_SETTING, true)
	await get_tree().process_frame
	await get_tree().process_frame
	ProjectSettings.set_setting(INSTALLERS_SETTING, previous_installers)
	ProjectSettings.set_setting(INSTALLER_TIMEOUT_SETTING, previous_timeout)
	ProjectSettings.set_setting(BLOCKING_INSTALLER_STARTED_SETTING, previous_started)
	ProjectSettings.set_setting(BLOCKING_INSTALLER_RELEASE_SETTING, previous_release)

	var expected_error: String = "[GF] 项目 Installer 超时：%s 的 install_bindings() 超过 0.01 秒。" % BLOCKING_BINDING_INSTALLER_PATH
	assert_false(architecture.is_inited(), "Installer 超时后架构不应继续初始化。")
	assert_true(architecture.has_initialization_failed(), "Installer 超时后架构应标记初始化失败。")
	assert_eq(architecture.last_initialization_error, expected_error)
	assert_push_error(expected_error)
	assert_push_error("[GFArchitecture] register_utility 失败：架构初始化已失败，已拒绝迟到写入。")


## 验证项目 Installer 超时后重试时，旧 Installer 迟到恢复也不能写入新生命周期。
func test_project_installer_timeout_retry_blocks_stale_late_binding() -> void:
	var previous_installers: Variant = ProjectSettings.get_setting(INSTALLERS_SETTING, [])
	var previous_timeout: Variant = ProjectSettings.get_setting(INSTALLER_TIMEOUT_SETTING, 0.0)
	var previous_started: Variant = ProjectSettings.get_setting(BLOCKING_INSTALLER_STARTED_SETTING, false)
	var previous_release: Variant = ProjectSettings.get_setting(BLOCKING_INSTALLER_RELEASE_SETTING, false)
	ProjectSettings.set_setting(INSTALLERS_SETTING, [BLOCKING_BINDING_INSTALLER_PATH])
	ProjectSettings.set_setting(INSTALLER_TIMEOUT_SETTING, 0.01)
	ProjectSettings.set_setting(BLOCKING_INSTALLER_STARTED_SETTING, false)
	ProjectSettings.set_setting(BLOCKING_INSTALLER_RELEASE_SETTING, false)

	if Gf.has_architecture():
		Gf.get_architecture().dispose()
	Gf._architecture = null

	await Gf.init()
	var architecture: GFArchitecture = Gf.get_architecture()
	var expected_error: String = "[GF] 项目 Installer 超时：%s 的 install_bindings() 超过 0.01 秒。" % BLOCKING_BINDING_INSTALLER_PATH
	assert_true(architecture.has_initialization_failed(), "Installer 超时后架构应处于失败状态。")
	assert_push_error(expected_error)

	ProjectSettings.set_setting(INSTALLERS_SETTING, [])
	await Gf.init()
	assert_false(architecture.is_inited(), "旧 Installer 未收尾前，重试不应提前清除失败状态。")
	assert_true(architecture.has_initialization_failed(), "旧 Installer 未收尾前，架构应继续保持失败状态。")

	ProjectSettings.set_setting(BLOCKING_INSTALLER_RELEASE_SETTING, true)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame

	var late_lookup: Variant = architecture.get_local_utility(AsyncInstallerUtilityFixture)
	assert_true(late_lookup == null, "旧 Installer 迟到恢复不应把 Utility 写入重试后的架构。")
	assert_push_error("[GFArchitecture] register_utility 失败：架构初始化已失败，已拒绝迟到写入。")

	await Gf.init()
	assert_true(architecture.is_inited(), "旧 Installer 收尾后，重试时没有 Installer 应完成初始化。")
	assert_false(architecture.has_initialization_failed(), "旧 Installer 收尾后，重试应清除旧失败状态。")

	ProjectSettings.set_setting(INSTALLERS_SETTING, previous_installers)
	ProjectSettings.set_setting(INSTALLER_TIMEOUT_SETTING, previous_timeout)
	ProjectSettings.set_setting(BLOCKING_INSTALLER_STARTED_SETTING, previous_started)
	ProjectSettings.set_setting(BLOCKING_INSTALLER_RELEASE_SETTING, previous_release)


## 验证 Scoped NodeContext 会创建局部架构、回退父架构并在退出树时释放局部模块。
func test_scoped_node_context_owns_local_architecture() -> void:
	if Gf.has_architecture():
		Gf.get_architecture().dispose()
	Gf._architecture = null

	var parent_arch: GFArchitecture = GFArchitecture.new()
	var parent_utility: ParentScopedUtility = ParentScopedUtility.new()
	await parent_arch.register_utility_instance(parent_utility)
	await Gf.set_architecture(parent_arch)

	var context: ScopedContext = ScopedContext.new()
	var ready_state: Dictionary = { "done": false }
	var _connect_result_1189: Variant = context.context_ready.connect(func(_architecture: GFArchitecture) -> void: ready_state.done = true)
	add_child(context)
	await get_tree().process_frame

	var local_utility: LocalScopedUtility = _local_scoped_utility(context.get_utility(LocalScopedUtility))
	var inherited_utility: ParentScopedUtility = _parent_scoped_utility(context.get_utility(ParentScopedUtility))
	var lookup_system: LocalLookupSystem = _local_lookup_system(context.get_system(LocalLookupSystem))
	var controller: ScopedController = ScopedController.new()
	context.add_child(controller)
	await get_tree().process_frame

	assert_true(GFVariantData.get_option_bool(ready_state, "done"), "Scoped NodeContext 应自动初始化局部架构。")
	assert_not_null(local_utility, "Scoped NodeContext 应注册局部 Utility。")
	assert_eq(inherited_utility, parent_utility, "局部架构应回退获取父架构依赖。")
	assert_eq(lookup_system.local_utility, local_utility, "Scoped System 的基类 get_utility 应优先访问局部架构。")
	assert_eq(lookup_system.parent_utility, parent_utility, "Scoped System 的基类 get_utility 应能回退父架构。")
	assert_eq(controller.get_local_scoped_utility(), local_utility, "Scoped Controller 应沿场景树找到局部架构。")
	assert_eq(controller.get_parent_scoped_utility(), parent_utility, "Scoped Controller 应通过局部架构回退父架构。")

	context.queue_free()
	await get_tree().process_frame

	assert_true(local_utility.disposed, "Scoped NodeContext 退出树时应释放局部模块。")
	assert_false(parent_utility.disposed, "Scoped NodeContext 不应释放父架构模块。")


func test_inherited_node_context_emits_context_ready_for_ready_parent() -> void:
	var parent_architecture: GFArchitecture = Gf.get_architecture()
	var context: InheritedContext = InheritedContext.new()
	var ready_state: Dictionary = {
		"done": false,
		"architecture": null,
	}
	var _connect_result_1222: Variant = context.context_ready.connect(func(architecture: GFArchitecture) -> void:
		ready_state["done"] = true
		ready_state["architecture"] = architecture
	)
	add_child(context)
	await get_tree().process_frame
	await get_tree().process_frame

	assert_true(GFVariantData.get_option_bool(ready_state, "done"), "Inherited NodeContext 应在继承架构 ready 后发出 context_ready。")
	assert_eq(_state_architecture(ready_state), parent_architecture, "context_ready 应传出继承的架构。")
	assert_true(context.is_context_ready(), "Inherited NodeContext 应标记 ready。")

	context.queue_free()
	await get_tree().process_frame


func test_inherited_node_context_emits_context_ready_after_parent_initializes() -> void:
	if Gf.has_architecture():
		Gf.get_architecture().dispose()
	Gf._architecture = GFArchitecture.new()
	var parent_architecture: GFArchitecture = Gf.get_architecture()
	var context: InheritedContext = InheritedContext.new()
	context.context_wait_timeout_seconds = 0.0
	var ready_state: Dictionary = {
		"done": false,
		"architecture": null,
	}
	var _connect_result_1249: Variant = context.context_ready.connect(func(architecture: GFArchitecture) -> void:
		ready_state["done"] = true
		ready_state["architecture"] = architecture
	)
	add_child(context)
	await get_tree().process_frame

	assert_false(context.is_context_ready(), "父架构未初始化前，Inherited NodeContext 不应提前 ready。")
	assert_false(GFVariantData.get_option_bool(ready_state, "done"), "父架构未初始化前不应发出 context_ready。")

	await parent_architecture.init()
	await get_tree().process_frame
	await get_tree().process_frame

	assert_true(GFVariantData.get_option_bool(ready_state, "done"), "父架构稍后 ready 时，Inherited NodeContext 应发出 context_ready。")
	assert_eq(_state_architecture(ready_state), parent_architecture, "context_ready 应传出继承的架构。")
	assert_true(context.is_context_ready(), "Inherited NodeContext 应标记 ready。")

	context.queue_free()
	await get_tree().process_frame


## 验证 Controller 可以等待最近的局部上下文完成初始化。
func test_controller_waits_for_context_ready() -> void:
	if Gf.has_architecture():
		Gf.get_architecture().dispose()
	Gf._architecture = null

	var parent_arch: GFArchitecture = GFArchitecture.new()
	await Gf.set_architecture(parent_arch)

	var context: ScopedContext = ScopedContext.new()
	var controller: ScopedController = ScopedController.new()
	add_child(context)
	context.add_child(controller)
	var architecture: GFArchitecture = await controller.wait_for_context_ready()

	assert_eq(architecture, context.get_architecture(), "Controller 应等待并返回最近上下文的架构。")
	assert_not_null(controller.get_local_scoped_utility(), "等待完成后 Controller 应能获取局部依赖。")

	context.queue_free()
	await get_tree().process_frame


## 验证 auto_init=false 的 Scoped NodeContext 可通过公开 API 手动完成初始化。
func test_scoped_node_context_initialize_context_runs_manual_lifecycle() -> void:
	if Gf.has_architecture():
		Gf.get_architecture().dispose()
	Gf._architecture = null

	var context: ManualInitScopedContext = ManualInitScopedContext.new()
	add_child(context)
	watch_signals(context)
	await get_tree().process_frame

	assert_false(context.is_context_ready(), "auto_init=false 时上下文不应自动 ready。")
	assert_not_null(context.utility, "上下文仍应完成局部安装。")
	assert_false(context.utility.ready_called, "手动初始化前局部 Utility 不应进入 ready。")

	var architecture: GFArchitecture = await context.initialize_context()

	assert_not_null(architecture, "initialize_context 应返回初始化完成的局部架构。")
	assert_true(context.is_context_ready(), "手动初始化后上下文应进入 ready。")
	assert_true(context.utility.ready_called, "手动初始化应驱动局部模块 ready。")
	assert_signal_emitted(context, "context_ready", "手动初始化成功应发出 context_ready。")

	context.queue_free()
	await get_tree().process_frame


func test_scoped_node_context_awaits_async_install_before_init() -> void:
	if Gf.has_architecture():
		Gf.get_architecture().dispose()
	Gf._architecture = null

	var context: AsyncInstallScopedContext = AsyncInstallScopedContext.new()
	add_child(context)

	assert_true(context.install_started, "进入树时应启动 install。")
	assert_false(context.install_finished, "install await 完成前不应被视为安装结束。")
	assert_false(context.is_context_ready(), "异步 install 完成前上下文不应提前 ready。")

	var architecture: GFArchitecture = await context.wait_until_ready()

	assert_not_null(architecture, "异步 install 完成后上下文应能初始化。")
	assert_true(context.install_finished, "wait_until_ready 应等待 install 完成。")
	assert_not_null(context.utility, "异步 install 注册的 Utility 应存在。")
	assert_true(context.utility.ready_called, "异步 install 注册的 Utility 应参与 ready 阶段。")

	context.queue_free()
	await get_tree().process_frame


## 验证 Controller 等待到上下文失败时返回 null，而不是回退未就绪架构。
func test_controller_wait_for_context_ready_returns_null_when_context_failed() -> void:
	if Gf.has_architecture():
		Gf.get_architecture().dispose()

	var failed_arch: GFArchitecture = GFArchitecture.new()
	failed_arch.fail_initialization("[test] parent failed")
	assert_push_error("[test] parent failed")
	Gf._architecture = failed_arch

	var context: InheritedContext = InheritedContext.new()
	var controller: ScopedController = ScopedController.new()
	context.add_child(controller)
	add_child(context)
	watch_signals(context)

	var architecture: GFArchitecture = await controller.wait_for_context_ready()

	assert_null(architecture, "上下文失败时 Controller.wait_for_context_ready() 应返回 null。")
	assert_signal_emitted(context, "context_failed", "上下文失败应发出 context_failed。")
	assert_push_warning("[GFNodeContext] [test] parent failed")

	context.queue_free()
	await get_tree().process_frame


## 验证 Controller 默认把父节点解析为宿主节点。
func test_controller_resolves_parent_host_by_default() -> void:
	var host: DerivedControllerHost = DerivedControllerHost.new()
	var controller: ScopedController = ScopedController.new()

	add_child(host)
	host.add_child(controller)
	await get_tree().process_frame

	assert_eq(controller.get_host(), host, "Controller 默认应把父节点作为宿主。")
	assert_eq(controller.host, host, "Controller.host 应代理 get_host()。")
	assert_true(controller.has_host(), "父节点存在时 has_host() 应返回 true。")
	assert_eq(controller.get_host_as(ControllerHost), host, "get_host_as() 应支持脚本基类匹配。")
	assert_eq(controller.get_host_as(Node), host, "get_host_as() 应支持 Godot 原生类型匹配。")
	assert_null(controller.get_host_as(OtherControllerHost), "类型不匹配时 get_host_as() 应返回 null。")

	host.queue_free()
	await get_tree().process_frame


## 验证 Controller 可通过 host_node_path 指定非父节点宿主。
func test_controller_resolves_configured_host_path() -> void:
	var scene_root: Node = Node.new()
	var host: ControllerHost = ControllerHost.new()
	var branch: Node = Node.new()
	var controller: ScopedController = ScopedController.new()
	host.name = "RuntimeHost"
	branch.name = "ControllerBranch"
	controller.host_node_path = NodePath("../../RuntimeHost")

	add_child(scene_root)
	scene_root.add_child(host)
	scene_root.add_child(branch)
	branch.add_child(controller)
	await get_tree().process_frame

	assert_eq(controller.get_host(), host, "Controller 应按 host_node_path 解析宿主。")

	scene_root.queue_free()
	await get_tree().process_frame


## 验证 Controller 宿主路径缺失时安全返回 null。
func test_controller_missing_host_returns_null() -> void:
	var controller: ScopedController = ScopedController.new()
	controller.host_node_path = NodePath("MissingHost")
	add_child(controller)
	await get_tree().process_frame

	assert_null(controller.get_host(), "宿主路径不存在时 get_host() 应返回 null。")
	assert_false(controller.has_host(), "宿主路径不存在时 has_host() 应返回 false。")
	assert_null(controller.get_host_as(Node), "宿主不存在时 get_host_as() 应返回 null。")

	controller.queue_free()
	await get_tree().process_frame


func test_controller_proxy_methods_without_architecture_return_null_silently() -> void:
	if Gf.has_architecture():
		Gf.get_architecture().dispose()
	Gf._architecture = null
	var controller: ScopedController = ScopedController.new()
	add_child(controller)

	assert_null(controller.get_model(DummyModel), "无可用架构时 Controller.get_model 应返回 null。")
	assert_null(controller.get_system(DummySystem), "无可用架构时 Controller.get_system 应返回 null。")
	assert_null(controller.get_utility(DummyUtility), "无可用架构时 Controller.get_utility 应返回 null。")
	var command_result: Variant = controller.send_command(GFCommand.new())
	var query_result: Variant = controller.send_query(GFQuery.new())
	assert_true(command_result == null, "无可用架构时 Controller.send_command 应返回 null。")
	assert_true(query_result == null, "无可用架构时 Controller.send_query 应返回 null。")
	controller.send_event(GFPayload.new())
	controller.send_simple_event(&"missing_architecture", 1)

	assert_push_error_count(0, "Controller 便捷代理在缺少架构时不应触发全局架构错误。")
	controller.queue_free()
	await get_tree().process_frame


## 验证 Inherited NodeContext 也能等待父架构完成异步初始化。
func test_inherited_context_waits_for_parent_architecture_init() -> void:
	if Gf.has_architecture():
		Gf.get_architecture().dispose()
	Gf._architecture = null

	var parent_arch: GFArchitecture = GFArchitecture.new()
	var slow_utility: SlowInitUtility = SlowInitUtility.new()
	await parent_arch.register_utility_instance(slow_utility)
	Gf._architecture = parent_arch

	var context: InheritedContext = InheritedContext.new()
	add_child(context)
	await get_tree().process_frame

	@warning_ignore("missing_await")
	parent_arch.init()
	await get_tree().process_frame
	assert_true(slow_utility.async_started, "父架构应已进入 async_init 等待。")

	slow_utility.call_deferred("emit_signal", "async_continue")
	var architecture: GFArchitecture = await context.wait_until_ready()

	assert_eq(architecture, parent_arch, "Inherited NodeContext 应返回继承到的父架构。")
	assert_true(slow_utility.ready_called, "wait_until_ready 应等待父架构 ready 后再返回。")

	context.queue_free()
	await get_tree().process_frame


## 验证等待上下文 ready 时可通过超时失败退出。
func test_context_wait_until_ready_times_out_when_parent_never_initializes() -> void:
	if Gf.has_architecture():
		Gf.get_architecture().dispose()
	Gf._architecture = GFArchitecture.new()

	var context: InheritedContext = InheritedContext.new()
	context.context_wait_timeout_seconds = 0.01
	add_child(context)
	watch_signals(context)

	var architecture: GFArchitecture = await context.wait_until_ready()

	assert_null(architecture, "父架构一直未初始化时，wait_until_ready 应在超时后返回 null。")
	assert_signal_emitted(context, "context_failed", "等待超时应发出 context_failed。")
	assert_true(context.is_context_failed(), "超时后上下文应进入失败终态。")
	assert_eq(context.get_context_failure_reason(), "等待上下文初始化超时。", "失败原因应保留给后续诊断。")
	assert_push_warning("[GFNodeContext] 等待上下文初始化超时。")

	var retry_architecture: GFArchitecture = await context.wait_until_ready()

	assert_null(retry_architecture, "失败终态的上下文不应在后续等待中重新进入初始化流程。")

	context.queue_free()
	await get_tree().process_frame


## 验证禁用超时时，等待上下文 ready 的协程仍会在节点离树时取消。
func test_context_wait_until_ready_returns_null_when_context_exits_tree_without_timeout() -> void:
	if Gf.has_architecture():
		Gf.get_architecture().dispose()
	Gf._architecture = GFArchitecture.new()

	var context: InheritedContext = InheritedContext.new()
	context.context_wait_timeout_seconds = 0.0
	add_child(context)

	var state: Dictionary = {
		"done": false,
		"result": null,
	}
	@warning_ignore("missing_await")
	_await_context_ready(context, state)
	await get_tree().process_frame

	remove_child(context)
	await get_tree().process_frame
	await get_tree().process_frame

	assert_true(GFVariantData.get_option_bool(state, "done"), "上下文离树应唤醒等待中的 wait_until_ready。")
	assert_true(GFVariantData.get_option_value(state, "result") == null, "上下文离树后 wait_until_ready 应返回 null。")
	context.free()


## 验证 Inherited NodeContext 找不到任何父级或全局架构时会立即失败。
func test_inherited_context_without_parent_architecture_emits_failure() -> void:
	if Gf.has_architecture():
		Gf.get_architecture().dispose()
	Gf._architecture = null

	var context: InheritedContext = InheritedContext.new()
	context.context_wait_timeout_seconds = 0.0
	watch_signals(context)
	add_child(context)

	var architecture: GFArchitecture = await context.wait_until_ready()

	assert_null(architecture, "没有可继承架构时，wait_until_ready 应直接返回 null。")
	assert_signal_emitted(context, "context_failed", "没有可继承架构时应发出 context_failed。")
	assert_push_warning("[GFNodeContext] 未找到可继承的架构。")

	context.queue_free()
	await get_tree().process_frame


## 验证子 Scoped NodeContext 初始化前会等待父 Scoped 架构 ready。
func test_child_scoped_context_waits_for_parent_scoped_context_ready() -> void:
	if Gf.has_architecture():
		Gf.get_architecture().dispose()
	Gf._architecture = null

	var parent_context: ParentSlowScopedContext = ParentSlowScopedContext.new()
	var child_context: ChildScopedContext = ChildScopedContext.new()
	parent_context.add_child(child_context)
	add_child(parent_context)
	await get_tree().process_frame

	assert_true(parent_context.slow_utility.async_started, "父 Scoped 架构应已进入 async_init 等待。")
	assert_false(child_context.is_context_ready(), "父架构 ready 前，子 Scoped 上下文不应提前 ready。")

	parent_context.slow_utility.async_continue.emit()
	await child_context.wait_until_ready()

	assert_true(child_context.lookup_system.parent_ready_at_ready, "子 Scoped 模块 ready 时父架构应已经 ready。")

	parent_context.queue_free()
	await get_tree().process_frame


## 验证子 Scoped NodeContext 会识别父级架构初始化失败并停止等待。
func test_child_scoped_context_fails_when_parent_architecture_failed() -> void:
	if Gf.has_architecture():
		Gf.get_architecture().dispose()

	var failed_arch: GFArchitecture = GFArchitecture.new()
	failed_arch.fail_initialization("[test] scoped parent failed")
	assert_push_error("[test] scoped parent failed")
	Gf._architecture = failed_arch

	var child_context: ChildScopedContext = ChildScopedContext.new()
	watch_signals(child_context)
	add_child(child_context)
	await get_tree().process_frame

	assert_false(child_context.is_context_ready(), "父级架构失败时子 Scoped 上下文不应继续初始化。")
	assert_signal_emitted(child_context, "context_failed", "父级失败应发出 context_failed。")
	assert_push_warning("[GFNodeContext] [test] scoped parent failed")

	child_context.queue_free()
	await get_tree().process_frame


## 验证工厂创建的短生命周期对象会自动注入当前架构。
func test_factory_create_instance_injects_architecture() -> void:
	var parent_arch: GFArchitecture = GFArchitecture.new()
	var parent_utility: ParentScopedUtility = ParentScopedUtility.new()
	await parent_arch.register_utility_instance(parent_utility)

	var child_arch: GFArchitecture = GFArchitecture.new(parent_arch)
	child_arch.register_factory(FactoryCommand, func() -> Object:
		return FactoryCommand.new()
	)

	var command: FactoryCommand = _factory_command(child_arch.create_instance(FactoryCommand))

	assert_not_null(command, "create_instance 应返回工厂创建的命令。")
	assert_eq(command.get_parent_utility_from_command(), parent_utility, "工厂创建的命令应使用创建它的架构解析依赖。")

	child_arch.dispose()
	parent_arch.dispose()


## 验证父级 transient 工厂被子架构解析时，会注入请求方架构。
func test_parent_transient_factory_injects_requesting_child_architecture() -> void:
	var parent_arch: GFArchitecture = GFArchitecture.new()
	var child_arch: GFArchitecture = GFArchitecture.new(parent_arch)
	parent_arch.register_factory(InjectedFactoryCommand, func() -> Object:
		return InjectedFactoryCommand.new()
	)

	var command: InjectedFactoryCommand = _injected_factory_command(child_arch.create_instance(InjectedFactoryCommand))

	assert_not_null(command, "子架构应能通过父级工厂创建对象。")
	assert_eq(command.injected_architecture, child_arch, "父级 transient 工厂结果应注入发起解析的子架构。")

	child_arch.dispose()
	parent_arch.dispose()


## 验证子架构初始化后仍能感知父级后续注册的 TimeProvider。
func test_child_architecture_uses_parent_time_provider_registered_late() -> void:
	var parent_arch: GFArchitecture = GFArchitecture.new()
	var child_arch: GFArchitecture = GFArchitecture.new(parent_arch)
	var system: TickUtility = TickUtility.new()
	await child_arch.register_utility_instance(system)
	await parent_arch.init()
	await child_arch.init()

	child_arch.tick(8.0)
	assert_almost_eq(system.last_delta, 8.0, 0.0001, "父级尚无 TimeProvider 时应使用原始 delta。")

	var time_provider: ScalingTimeProvider = ScalingTimeProvider.new()
	time_provider.scale = 0.25
	await parent_arch.register_utility_instance(time_provider)
	child_arch.tick(8.0)

	assert_almost_eq(system.last_delta, 2.0, 0.0001, "父级后续注册 TimeProvider 后，子架构应动态使用父级时间缩放。")
	child_arch.dispose()
	parent_arch.dispose()


## 验证父级 TimeProvider 注销后，子架构不会继续使用旧缓存引用。
func test_child_architecture_drops_parent_time_provider_after_unregister() -> void:
	var parent_arch: GFArchitecture = GFArchitecture.new()
	var child_arch: GFArchitecture = GFArchitecture.new(parent_arch)
	var time_provider: ScalingTimeProvider = ScalingTimeProvider.new()
	time_provider.scale = 0.5
	var system: TickUtility = TickUtility.new()
	await parent_arch.register_utility_instance(time_provider)
	await child_arch.register_utility_instance(system)
	await parent_arch.init()
	await child_arch.init()

	child_arch.tick(10.0)
	assert_almost_eq(system.last_delta, 5.0, 0.0001, "子架构应先使用父级 TimeProvider。")

	parent_arch.unregister_utility(ScalingTimeProvider)
	child_arch.tick(10.0)

	assert_almost_eq(system.last_delta, 10.0, 0.0001, "父级 TimeProvider 注销后，子架构应回退到原始 delta。")
	child_arch.dispose()
	parent_arch.dispose()


## 验证父级架构配置拒绝自身与循环引用，避免依赖回退无限递归。
func test_parent_architecture_rejects_self_and_cycles() -> void:
	var parent_arch: GFArchitecture = GFArchitecture.new()
	var child_arch: GFArchitecture = GFArchitecture.new(parent_arch)

	parent_arch.set_parent_architecture(parent_arch)
	parent_arch.set_parent_architecture(child_arch)

	assert_null(parent_arch.get_parent_architecture(), "父级不能设为自身，也不能形成 parent-child 循环。")
	assert_same(child_arch.get_parent_architecture(), parent_arch, "合法的子架构父级关系应保持不变。")
	assert_push_error("[GFArchitecture] set_parent_architecture 失败：父级架构不能是自身。")
	assert_push_error("[GFArchitecture] set_parent_architecture 失败：父级架构会形成循环引用。")
	child_arch.dispose()
	parent_arch.dispose()


## 验证 has_factory 会查询当前架构与父级架构，且不会创建实例或输出错误。
func test_has_factory_checks_parent_without_instantiating() -> void:
	var parent_arch: GFArchitecture = GFArchitecture.new()
	var child_arch: GFArchitecture = GFArchitecture.new(parent_arch)
	var factory_call_count: Array[int] = [0]
	parent_arch.register_factory(InjectedFactoryCommand, func() -> Object:
		factory_call_count[0] += 1
		return InjectedFactoryCommand.new()
	)

	assert_true(child_arch.has_factory(InjectedFactoryCommand), "子架构应能发现父级工厂。")
	assert_false(child_arch.has_factory(FactoryCommand), "未注册工厂应返回 false。")
	assert_eq(factory_call_count[0], 0, "has_factory 不应触发工厂实例化。")

	child_arch.dispose()
	parent_arch.dispose()


## 验证未知工厂生命周期会在注册期暴露，而不是延迟到 create_instance()。
func test_factory_registration_rejects_unknown_lifetime() -> void:
	var arch: GFArchitecture = GFArchitecture.new()

	arch.register_factory(
		FactoryCommand,
		func() -> Object:
			return FactoryCommand.new(),
		999
	)
	assert_false(arch.has_factory(FactoryCommand), "非法生命周期不应写入工厂注册表。")
	assert_push_error("[GFArchitecture] register_factory 失败：未知工厂生命周期：999。")

	arch.replace_factory(
		FactoryCommand,
		func() -> Object:
			return FactoryCommand.new(),
		999
	)
	assert_false(arch.has_factory(FactoryCommand), "replace_factory 也不应接受非法生命周期。")
	assert_push_error("[GFArchitecture] replace_factory 失败：未知工厂生命周期：999。")
	arch.dispose()


## 验证 Singleton 工厂缓存的节点失效后会重新创建实例。
func test_singleton_factory_recreates_freed_cached_instance() -> void:
	var arch: GFArchitecture = GFArchitecture.new()
	var factory: CountingFactory = CountingFactory.new()
	arch.register_factory(FactoryNode, Callable(factory, "create"), GFBindingLifetimes.Lifetime.SINGLETON)

	var first: FactoryNode = _factory_node(arch.create_instance(FactoryNode))
	first.free()
	var second: FactoryNode = _factory_node(arch.create_instance(FactoryNode))

	assert_eq(factory.call_count, 2, "缓存实例失效后 Singleton 工厂应重新调用 provider。")
	assert_true(is_instance_valid(second), "重新创建的 Singleton 实例应有效。")

	second.free()
	arch.dispose()


## 验证 Singleton 工厂失败返回不会被缓存，后续有效返回仍可恢复。
func test_singleton_factory_does_not_cache_wrong_type_failure() -> void:
	var arch: GFArchitecture = GFArchitecture.new()
	var factory: RecoveringFactory = RecoveringFactory.new()
	arch.register_factory(FactoryNode, Callable(factory, "create"), GFBindingLifetimes.Lifetime.SINGLETON)

	var first: Object = arch.create_instance(FactoryNode)
	var second: FactoryNode = _factory_node(arch.create_instance(FactoryNode))

	assert_null(first, "工厂返回错误类型时应解析失败。")
	assert_push_error("[GFBinding] 绑定来源返回的实例脚本必须继承或等于绑定键。")
	assert_eq(factory.call_count, 2, "失败结果不应写入 Singleton 缓存，下一次应重新调用 provider。")
	assert_not_null(second, "后续 provider 返回正确类型后应能成功解析。")

	second.free()
	arch.dispose()


## 验证 Singleton 工厂循环解析会被拒绝，而不是递归创建直到栈溢出。
func test_singleton_factory_rejects_recursive_resolution() -> void:
	var arch: GFArchitecture = GFArchitecture.new()
	var factory: CyclicFactory = CyclicFactory.new(arch)
	arch.register_factory(FactoryNode, Callable(factory, "create"), GFBindingLifetimes.Lifetime.SINGLETON)

	var resolved: Object = arch.create_instance(FactoryNode)

	assert_null(resolved, "循环解析的 Singleton 工厂应返回 null。")
	assert_eq(factory.call_count, 1, "循环解析应在第二次进入同一 binding 时被拦截。")
	assert_push_error("[GFBinding] Singleton 工厂正在解析中，检测到循环依赖。")
	arch.dispose()


## 验证 Singleton 工厂在递归解析后即使 provider 返回对象，也不能缓存该对象。
func test_singleton_factory_rejects_provider_value_after_recursive_resolution() -> void:
	var arch: GFArchitecture = GFArchitecture.new()
	var factory: FallbackAfterRecursiveFactory = FallbackAfterRecursiveFactory.new(arch)
	arch.register_factory(FactoryNode, Callable(factory, "create"), GFBindingLifetimes.Lifetime.SINGLETON)

	var first: Object = arch.create_instance(FactoryNode)
	var second: FactoryNode = _factory_node(arch.create_instance(FactoryNode))

	assert_null(first, "递归解析发生后外层 provider 的补偿返回值也应被拒绝。")
	assert_true(factory.recursive_result_was_null, "递归进入同一 Singleton binding 时应被拦截。")
	assert_eq(factory.call_count, 2, "递归失败不应写入 Singleton 缓存，后续解析应重新调用 provider。")
	assert_not_null(second, "后续非递归解析仍应恢复。")
	assert_push_error("[GFBinding] Singleton 工厂正在解析中，检测到循环依赖。")

	second.free()
	arch.dispose()


## 验证父级 Singleton 工厂被子架构解析时，实例归属和注入仍属于父架构。
func test_parent_singleton_factory_keeps_owner_architecture_injection() -> void:
	var parent_arch: GFArchitecture = GFArchitecture.new()
	var child_arch: GFArchitecture = GFArchitecture.new(parent_arch)
	parent_arch.register_factory(
		InjectedFactoryCommand,
		func() -> Object:
			return InjectedFactoryCommand.new(),
		GFBindingLifetimes.Lifetime.SINGLETON
	)

	var first: InjectedFactoryCommand = _injected_factory_command(child_arch.create_instance(InjectedFactoryCommand))
	var second: InjectedFactoryCommand = _injected_factory_command(child_arch.create_instance(InjectedFactoryCommand))

	assert_not_null(first, "子架构应能解析父级 Singleton 工厂。")
	assert_eq(first, second, "父级 Singleton 工厂应缓存同一实例。")
	assert_eq(first.injected_architecture, parent_arch, "父级 Singleton 工厂结果应注入拥有该绑定的父架构。")

	child_arch.dispose()
	parent_arch.dispose()


## 验证注销 Singleton 工厂会释放缓存实例的依赖作用域。
func test_unregister_singleton_factory_releases_cached_instance_scope() -> void:
	var arch: GFArchitecture = GFArchitecture.new()
	var utility: ParentScopedUtility = ParentScopedUtility.new()
	await arch.register_utility_instance(utility)
	arch.register_factory(
		FactoryCommand,
		func() -> Object:
			return FactoryCommand.new(),
		GFBindingLifetimes.Lifetime.SINGLETON
	)

	var command: FactoryCommand = _factory_command(arch.create_instance(FactoryCommand))

	assert_eq(command.get_parent_utility_from_command(), utility, "工厂实例应先能访问注入架构中的依赖。")

	arch.unregister_factory(FactoryCommand)

	assert_null(command.get_parent_utility_from_command(), "工厂注销后旧 Singleton 实例不应继续访问旧架构。")
	assert_push_error("[GFCommand] 依赖作用域已释放，无法继续访问架构。")
	arch.dispose()


## 验证替换 Singleton 工厂会释放旧缓存实例的依赖作用域。
func test_replace_singleton_factory_releases_previous_cached_instance_scope() -> void:
	var arch: GFArchitecture = GFArchitecture.new()
	var utility: ParentScopedUtility = ParentScopedUtility.new()
	await arch.register_utility_instance(utility)
	arch.register_factory(
		FactoryCommand,
		func() -> Object:
			return FactoryCommand.new(),
		GFBindingLifetimes.Lifetime.SINGLETON
	)

	var previous: FactoryCommand = _factory_command(arch.create_instance(FactoryCommand))
	arch.replace_factory(
		FactoryCommand,
		func() -> Object:
			return FactoryCommand.new(),
		GFBindingLifetimes.Lifetime.SINGLETON
	)
	var replacement: FactoryCommand = _factory_command(arch.create_instance(FactoryCommand))

	assert_ne(previous, replacement, "替换工厂后应使用新的 Singleton 缓存实例。")
	assert_eq(replacement.get_parent_utility_from_command(), utility, "新 Singleton 实例应接收当前架构注入。")
	assert_null(previous.get_parent_utility_from_command(), "旧 Singleton 实例不应继续访问被替换前的架构作用域。")
	assert_push_error("[GFCommand] 依赖作用域已释放，无法继续访问架构。")
	arch.dispose()


## 验证注销 Singleton 工厂会释放缓存实例的生命周期归属。
func test_unregister_singleton_factory_disposes_cached_instance_and_owned_events() -> void:
	var arch: GFArchitecture = GFArchitecture.new()
	arch.register_factory(
		DisposableFactoryCommand,
		func() -> Object:
			return DisposableFactoryCommand.new(),
		GFBindingLifetimes.Lifetime.SINGLETON
	)

	var command: DisposableFactoryCommand = _disposable_factory_command(arch.create_instance(DisposableFactoryCommand))
	arch.send_simple_event(&"factory_owned_event")

	arch.unregister_factory(DisposableFactoryCommand)
	arch.send_simple_event(&"factory_owned_event")

	assert_eq(command.dispose_count, 1, "注销 Singleton 工厂应调用缓存实例的 dispose()。")
	assert_eq(command.event_count, 1, "注销 Singleton 工厂后，缓存实例的 owner 事件监听应被清理。")
	arch.dispose()


## 验证架构销毁会释放 Singleton 工厂缓存实例的生命周期归属。
func test_architecture_dispose_disposes_singleton_factory_cached_instance() -> void:
	var arch: GFArchitecture = GFArchitecture.new()
	arch.register_factory(
		DisposableFactoryCommand,
		func() -> Object:
			return DisposableFactoryCommand.new(),
		GFBindingLifetimes.Lifetime.SINGLETON
	)

	var command: DisposableFactoryCommand = _disposable_factory_command(arch.create_instance(DisposableFactoryCommand))
	arch.send_simple_event(&"factory_owned_event")

	arch.dispose()
	arch.send_simple_event(&"factory_owned_event")

	assert_eq(command.dispose_count, 1, "架构销毁应调用 Singleton 工厂缓存实例的 dispose()。")
	assert_eq(command.event_count, 1, "架构销毁后，Singleton 工厂缓存实例的 owner 事件监听应被清理。")


## 验证模块注销会自动清理通过基类注册的事件监听。
func test_unregister_utility_removes_owned_event_listeners() -> void:
	var arch: GFArchitecture = GFArchitecture.new()
	var utility: OwnedEventUtility = OwnedEventUtility.new()
	await arch.register_utility_instance(utility)
	await arch.init()

	arch.send_simple_event(&"owned_event")
	arch.unregister_utility(OwnedEventUtility)
	arch.send_simple_event(&"owned_event")

	assert_eq(utility.event_count, 1, "Utility 注销后不应继续收到 owner-bound 事件。")
	arch.dispose()


## 验证架构可赋值事件监听会接收子类事件。
func test_architecture_assignable_event_listener_receives_child_event() -> void:
	var arch: GFArchitecture = GFArchitecture.new()
	var state: Dictionary = {"count": 0}
	arch.register_assignable_event(BaseArchitectureEvent, func(_event: BaseArchitectureEvent) -> void:
		state["count"] = GFVariantData.get_option_int(state, "count") + 1
	)

	arch.send_event(ChildArchitectureEvent.new())

	assert_eq(GFVariantData.get_option_int(state, "count"), 1, "架构可赋值事件监听应接收子类事件。")
	arch.dispose()


## 验证架构事件调试配置会代理到底层事件系统。
func test_architecture_event_debugging_exposes_trace() -> void:
	var arch: GFArchitecture = GFArchitecture.new()
	arch.configure_event_debugging(4, true, 2)
	arch.register_simple_event(&"trace_event", func(_payload: Variant) -> void:
		pass
	)

	arch.send_simple_event(&"trace_event")
	var trace: Array = arch.get_event_dispatch_trace()
	var stats: Dictionary = arch.get_event_debug_stats()
	var first_trace: Dictionary = GFVariantData.as_dictionary(trace[0])

	assert_eq(GFVariantData.get_option_int(stats, "max_dispatch_depth"), 4, "架构应能配置事件最大深度。")
	assert_true(GFVariantData.get_option_bool(stats, "trace_enabled"), "架构应能开启事件追踪。")
	assert_eq(trace.size(), 1, "开启追踪后应能读取派发记录。")
	assert_eq(GFVariantData.get_option_string(first_trace, "event"), "trace_event", "追踪记录应包含简单事件 ID。")

	arch.clear_event_dispatch_trace()
	assert_true(arch.get_event_dispatch_trace().is_empty(), "架构应能清空事件追踪。")
	arch.dispose()


## 验证 Gf 门面可访问事件追踪。
func test_facade_event_debugging_proxies_architecture() -> void:
	Gf.configure_event_debugging(0, true, 2)
	Gf.listen_simple(&"facade_trace_event", func(_payload: Variant) -> void:
		pass
	)

	Gf.send_simple_event(&"facade_trace_event")
	var trace: Array[Dictionary] = Gf.get_event_dispatch_trace()
	var first_trace: Dictionary = GFVariantData.as_dictionary(trace[0])

	assert_eq(trace.size(), 1, "Gf 门面应能读取事件追踪。")
	assert_eq(GFVariantData.get_option_string(first_trace, "event"), "facade_trace_event", "门面追踪应来自当前架构。")

	Gf.clear_event_dispatch_trace()
	assert_true(Gf.get_event_dispatch_trace().is_empty(), "Gf 门面应能清空事件追踪。")


## 验证架构诊断快照会报告模块生命周期与工厂绑定状态。
func test_architecture_debug_lifecycle_state_reports_modules_and_factories() -> void:
	var arch: GFArchitecture = GFArchitecture.new()
	var utility: TickUtility = TickUtility.new()
	await arch.register_utility_instance(utility)
	arch.register_factory(
		FactoryCommand,
		func() -> Object:
			return FactoryCommand.new(),
		GFBindingLifetimes.Lifetime.SINGLETON
	)

	var before_init: Dictionary = arch.get_debug_lifecycle_state()
	var before_utilities: Dictionary = GFVariantData.get_option_dictionary(before_init, "utilities")
	var before_utility_entry: Dictionary = GFVariantData.as_dictionary(before_utilities.values()[0])

	assert_false(GFVariantData.get_option_bool(before_init, "inited", true), "初始化前诊断快照应报告未初始化。")
	assert_eq(GFVariantData.get_option_int(before_utility_entry, "stage"), 0, "初始化前模块应停留在 registered 阶段。")

	await arch.init()
	var after_init: Dictionary = arch.get_debug_lifecycle_state()
	var after_utilities: Dictionary = GFVariantData.get_option_dictionary(after_init, "utilities")
	var after_factories: Dictionary = GFVariantData.get_option_dictionary(after_init, "factories")
	var after_utility_entry: Dictionary = GFVariantData.as_dictionary(after_utilities.values()[0])
	var factory_entry: Dictionary = GFVariantData.as_dictionary(after_factories.values()[0])

	assert_true(GFVariantData.get_option_bool(after_init, "inited"), "初始化后诊断快照应报告已初始化。")
	assert_eq(GFVariantData.get_option_int(after_utility_entry, "stage"), 3, "初始化后模块应进入 ready 阶段。")
	assert_true(GFVariantData.get_option_bool(after_utility_entry, "has_tick"), "诊断快照应报告 tick 能力。")
	assert_eq(GFVariantData.get_option_int(factory_entry, "lifetime"), GFBindingLifetimes.Lifetime.SINGLETON, "诊断快照应报告工厂生命周期。")

	arch.dispose()


## 验证未重写 tick 模板的 System 不会进入热路径缓存。
func test_system_without_tick_override_stays_out_of_tick_cache() -> void:
	var arch: GFArchitecture = GFArchitecture.new()
	await arch.register_system_instance(DummySystem.new())
	await arch.init()

	var state: Dictionary = arch.get_debug_lifecycle_state()
	var tick_state: Dictionary = GFVariantData.get_option_dictionary(state, "tick")
	var systems: Dictionary = GFVariantData.get_option_dictionary(state, "systems")
	var system_entry: Dictionary = GFVariantData.as_dictionary(systems.values()[0])

	assert_eq(GFVariantData.get_option_int(tick_state, "systems", -1), 0, "未重写 tick() 的 System 不应进入 tick 缓存。")
	assert_eq(GFVariantData.get_option_int(tick_state, "physics_systems", -1), 0, "未重写 physics_tick() 的 System 不应进入物理 tick 缓存。")
	assert_false(GFVariantData.get_option_bool(system_entry, "has_tick", true), "诊断快照不应把基类空 tick 模板当成真实 tick 能力。")
	assert_false(GFVariantData.get_option_bool(system_entry, "has_physics_tick", true), "诊断快照不应把基类空 physics_tick 模板当成真实能力。")

	arch.dispose()


## 验证显式 tick 标记会刷新缓存，并可让模板 System 参与 tick 缓存。
func test_explicit_tick_opt_in_refreshes_system_tick_cache() -> void:
	var arch: GFArchitecture = GFArchitecture.new()
	var system: DummySystem = DummySystem.new()
	await arch.register_system_instance(system)
	await arch.init()

	system.tick_enabled = true
	system.physics_tick_enabled = true
	var enabled_state: Dictionary = arch.get_debug_lifecycle_state()
	var enabled_tick: Dictionary = GFVariantData.get_option_dictionary(enabled_state, "tick")
	var enabled_systems: Dictionary = GFVariantData.get_option_dictionary(enabled_state, "systems")
	var enabled_entry: Dictionary = GFVariantData.as_dictionary(enabled_systems.values()[0])

	assert_eq(GFVariantData.get_option_int(enabled_tick, "systems", -1), 1, "显式 tick_enabled 应让 System 进入 tick 缓存。")
	assert_eq(GFVariantData.get_option_int(enabled_tick, "physics_systems", -1), 1, "显式 physics_tick_enabled 应让 System 进入物理 tick 缓存。")
	assert_true(GFVariantData.get_option_bool(enabled_entry, "has_tick"), "诊断快照应报告显式 tick 能力。")
	assert_true(GFVariantData.get_option_bool(enabled_entry, "tick_enabled"), "诊断快照应暴露显式 tick 标记。")

	system.tick_enabled = false
	system.physics_tick_enabled = false
	var disabled_state: Dictionary = arch.get_debug_lifecycle_state()
	var disabled_tick: Dictionary = GFVariantData.get_option_dictionary(disabled_state, "tick")

	assert_eq(GFVariantData.get_option_int(disabled_tick, "systems", -1), 0, "关闭显式 tick 标记后，未重写模板的 System 应退出 tick 缓存。")
	assert_eq(GFVariantData.get_option_int(disabled_tick, "physics_systems", -1), 0, "关闭显式 physics 标记后，未重写模板的 System 应退出物理 tick 缓存。")

	arch.dispose()


## 验证 Utility 显式 tick 标记不会让缺少 tick() 方法的实例进入缓存。
func test_utility_tick_opt_in_requires_tick_method() -> void:
	var arch: GFArchitecture = GFArchitecture.new()
	var utility: DummyUtility = DummyUtility.new()
	await arch.register_utility_instance(utility)
	await arch.init()

	utility.tick_enabled = true
	var state: Dictionary = arch.get_debug_lifecycle_state()
	var tick_state: Dictionary = GFVariantData.get_option_dictionary(state, "tick")
	var utilities: Dictionary = GFVariantData.get_option_dictionary(state, "utilities")
	var utility_entry: Dictionary = GFVariantData.as_dictionary(utilities.values()[0])

	assert_eq(GFVariantData.get_option_int(tick_state, "utilities", -1), 0, "缺少 tick() 方法的 Utility 不应因 tick_enabled 进入缓存。")
	assert_false(GFVariantData.get_option_bool(utility_entry, "has_tick", true), "诊断快照不应把缺少 tick() 方法的 Utility 标记为可 tick。")
	assert_true(GFVariantData.get_option_bool(utility_entry, "tick_enabled"), "诊断快照仍应暴露显式标记，方便定位配置问题。")

	arch.tick(0.016)
	arch.dispose()


## 验证中间基类声明 tick 时，具体子类仍按旧契约自动参与 tick。
func test_inherited_system_tick_override_is_auto_detected() -> void:
	var arch: GFArchitecture = GFArchitecture.new()
	var tick_order: Array = []
	var system: InheritedConcreteTickSystem = InheritedConcreteTickSystem.new()
	system.tick_order = tick_order
	await arch.register_system_instance(system)
	await arch.init()

	arch.tick(0.016)

	assert_eq(tick_order, ["inherited"], "继承自项目中间基类的 tick() 仍应被架构自动驱动。")
	arch.dispose()


## 验证同一帧 tick 中被提前注销的模块不会继续从旧缓存中被驱动。
func test_tick_skips_module_unregistered_earlier_in_same_frame() -> void:
	var arch: GFArchitecture = GFArchitecture.new()
	var tick_order: Array = []
	await arch.register_system_instance(UnregisteringTickSystem.new(tick_order))
	await arch.register_system_instance(TickVictimSystem.new(tick_order))
	await arch.init()

	arch.tick(0.016)

	assert_eq(tick_order, ["unregistering"], "同一帧内已被注销的 System 不应继续 tick。")
	arch.dispose()


## 验证 tick 优先级越高越早驱动。
func test_tick_priority_orders_system_tick_cache() -> void:
	var arch: GFArchitecture = GFArchitecture.new()
	var tick_order: Array = []
	await arch.register_system_instance(LowPriorityTickSystem.new(tick_order))
	await arch.register_system_instance(HighPriorityTickSystem.new(tick_order))
	await arch.init()

	arch.tick(0.016)

	assert_eq(tick_order, ["high", "low"], "高 tick_priority 的 System 应更早 tick。")
	arch.dispose()


## 验证 tick_priority 在 System 与 Utility 之间按全局队列排序。
func test_tick_priority_orders_systems_and_utilities_together() -> void:
	var arch: GFArchitecture = GFArchitecture.new()
	var tick_order: Array = []
	await arch.register_system_instance(LowPriorityTickSystem.new(tick_order))
	await arch.register_utility_instance(PriorityTickUtility.new(tick_order))
	await arch.init()

	arch.tick(0.016)

	assert_eq(tick_order, ["utility", "low"], "Utility 的更高 tick_priority 应早于低优先级 System 执行。")
	arch.dispose()


## 验证 Command 执行作用域绑定当前生命周期，且同一实例不能重复发送。
func test_command_execution_scope_is_single_use_and_lifecycle_bound() -> void:
	var arch: GFArchitecture = GFArchitecture.new()
	await arch.init()
	var lifecycle_generation: int = arch.get_lifecycle_generation()
	var command: LifecycleProbeCommand = LifecycleProbeCommand.new()

	var result: Variant = arch.send_command(command)
	var second_result: Variant = arch.send_command(command)

	assert_true(GFVariantData.to_bool(result), "Command 执行期间应能看到活动生命周期。")
	assert_true(command.active_during_execute, "Command 内部 is_lifecycle_active() 应为 true。")
	assert_true(second_result == null, "同一 Command 实例重复发送应被拒绝。")
	assert_push_error_count(1, "重复发送同一 Command 实例应输出错误。")

	arch.dispose()
	assert_false(arch.is_lifecycle_generation_active(lifecycle_generation), "dispose 后旧 lifecycle generation 应失效。")
	assert_false(command.is_lifecycle_active(), "dispose 后 Command 执行作用域应失效。")
	assert_push_error_count(1, "只有重复发送同一 Command 实例应输出错误。")


## 验证声明式依赖严格模式会在生命周期推进前失败。
func test_fail_on_missing_declared_dependencies_blocks_init() -> void:
	var arch: GFArchitecture = GFArchitecture.new()
	arch.fail_on_missing_declared_dependencies = true
	await arch.register_utility_instance(MissingDependencyUtility.new())
	watch_signals(arch)

	await arch.init()

	assert_false(arch.is_inited(), "声明依赖缺失时架构不应初始化成功。")
	assert_true(arch.has_initialization_failed(), "声明依赖缺失应标记初始化失败。")
	assert_true(arch.last_initialization_error.contains("声明式依赖校验失败"), "失败原因应说明依赖校验失败。")
	assert_signal_emitted(arch, "initialization_failed", "严格依赖校验失败时应发出 initialization_failed。")
	assert_push_error_count(1, "严格依赖校验失败应输出错误。")
	arch.dispose()


## 验证 Gf.set_architecture 在新架构初始化失败时保留旧架构。
func test_set_architecture_keeps_previous_architecture_when_new_init_fails() -> void:
	if Gf.has_architecture():
		Gf.get_architecture().dispose()
	Gf._architecture = null

	var old_arch: GFArchitecture = GFArchitecture.new()
	await old_arch.register_utility_instance(DummyUtility.new())
	await Gf.set_architecture(old_arch)
	assert_eq(Gf.get_architecture(), old_arch, "旧架构应先成功成为全局架构。")

	var failing_arch: GFArchitecture = GFArchitecture.new()
	failing_arch.fail_on_missing_declared_dependencies = true
	await failing_arch.register_utility_instance(MissingDependencyUtility.new())
	await Gf.set_architecture(failing_arch)

	assert_eq(Gf.get_architecture(), old_arch, "新架构初始化失败时全局架构应仍指向旧架构。")
	assert_true(old_arch.is_inited(), "旧架构不应被提前 dispose。")
	assert_true(failing_arch.has_initialization_failed(), "失败的新架构应保留失败状态。")
	assert_push_error_count(1, "失败的新架构初始化应输出错误。")

	old_arch.dispose()
	Gf._architecture = null


## 验证并发 init 调用会等待同一轮初始化完成。
func test_concurrent_init_waits_for_active_initialization() -> void:
	if Gf.has_architecture():
		Gf.get_architecture().dispose()
	Gf._architecture = null

	var arch: GFArchitecture = GFArchitecture.new()
	var slow_utility: SlowInitUtility = SlowInitUtility.new()
	await arch.register_utility_instance(slow_utility)

	var first_state: Dictionary = { "done": false }
	var second_state: Dictionary = { "done": false }
	@warning_ignore("missing_await")
	_await_arch_init(arch, first_state)
	await get_tree().process_frame
	@warning_ignore("missing_await")
	_await_arch_init(arch, second_state)
	await get_tree().process_frame

	assert_true(slow_utility.async_started, "第一轮初始化应已进入 async_init。")
	assert_false(GFVariantData.get_option_bool(second_state, "done"), "第二个 init 调用不应在初始化完成前提前返回。")

	slow_utility.async_continue.emit()
	await get_tree().process_frame
	await get_tree().process_frame

	assert_true(GFVariantData.get_option_bool(first_state, "done"), "第一轮 init 应正常完成。")
	assert_true(GFVariantData.get_option_bool(second_state, "done"), "第二个 init 调用应在同一轮初始化完成后返回。")
	assert_true(arch.is_inited(), "架构应处于已初始化状态。")
	assert_true(slow_utility.ready_called, "慢初始化 Utility 最终应进入 ready 阶段。")


## 验证模块 async_init 超时会结束初始化流程并唤醒等待者。
func test_module_async_init_timeout_fails_initialization() -> void:
	if Gf.has_architecture():
		Gf.get_architecture().dispose()
	Gf._architecture = null

	var arch: GFArchitecture = GFArchitecture.new()
	arch.module_async_init_timeout_seconds = 0.001
	var slow_utility: SlowInitUtility = SlowInitUtility.new()
	await arch.register_utility_instance(slow_utility)
	watch_signals(arch)

	await arch.init()

	assert_true(slow_utility.async_started, "超时前模块应已进入 async_init。")
	assert_false(arch.is_inited(), "async_init 超时后架构不应标记为已初始化。")
	assert_true(arch.has_initialization_failed(), "架构应记录初始化失败状态。")
	assert_true(arch.last_initialization_error.contains("async_init 超时"), "失败原因应包含超时诊断。")
	assert_signal_emitted(arch, "initialization_failed", "async_init 超时时应发出 initialization_failed。")
	assert_push_error_count(1, "async_init 超时时应输出一条错误。")

	arch.dispose()


## 验证 async_init 超时后的迟到恢复不能继续写入注册表。
func test_late_async_init_resume_cannot_register_after_timeout() -> void:
	if Gf.has_architecture():
		Gf.get_architecture().dispose()
	Gf._architecture = null

	var arch: GFArchitecture = GFArchitecture.new()
	arch.module_async_init_timeout_seconds = 0.001
	var late_target: TickUtility = TickUtility.new()
	var slow_utility: LateRegisteringSlowUtility = LateRegisteringSlowUtility.new(late_target)
	await arch.register_utility_instance(slow_utility)

	await arch.init()
	assert_true(slow_utility.async_started, "测试模块应已进入 async_init。")
	assert_true(arch.has_initialization_failed(), "超时后架构应处于失败状态。")
	assert_push_error_count(1, "async_init 超时时应先输出一条错误。")

	slow_utility.async_continue.emit()
	await get_tree().process_frame
	await get_tree().process_frame

	var late_target_script: Script = _object_script(late_target)
	var late_lookup: Variant = arch.get_local_utility(late_target_script)
	assert_true(late_lookup == null, "迟到恢复的 async_init 不应再注册新 Utility。")
	assert_push_error("[GFArchitecture] register_utility 失败：架构初始化已失败，已拒绝迟到写入。")

	arch.dispose()


## 验证 async_init 超时后重试时，旧 async_init 迟到恢复也不能写入新生命周期。
func test_late_async_init_resume_cannot_register_after_timeout_retry() -> void:
	if Gf.has_architecture():
		Gf.get_architecture().dispose()
	Gf._architecture = null

	var arch: GFArchitecture = GFArchitecture.new()
	arch.module_async_init_timeout_seconds = 0.001
	var late_target: TickUtility = TickUtility.new()
	var slow_utility: LateRegisteringSlowUtility = LateRegisteringSlowUtility.new(late_target)
	await arch.register_utility_instance(slow_utility)

	await arch.init()
	assert_true(slow_utility.async_started, "测试模块应已进入 async_init。")
	assert_true(arch.has_initialization_failed(), "超时后架构应处于失败状态。")
	assert_push_error_count(1, "async_init 超时时应先输出一条错误。")

	await arch.init()
	assert_false(arch.is_inited(), "旧 async_init 未收尾前，重试不应提前清除失败状态。")
	assert_true(arch.has_initialization_failed(), "旧 async_init 未收尾前，架构应继续保持失败状态。")

	slow_utility.async_continue.emit()
	await get_tree().process_frame
	await get_tree().process_frame

	var late_target_script: Script = _object_script(late_target)
	var late_lookup: Variant = arch.get_local_utility(late_target_script)
	assert_true(late_lookup == null, "旧 async_init 迟到恢复不应把 Utility 写入重试后的架构。")
	assert_push_error("[GFArchitecture] register_utility 失败：架构初始化已失败，已拒绝迟到写入。")

	await arch.init()
	assert_true(arch.is_inited(), "旧 async_init 收尾后，重试应在清空失败模块后完成初始化。")
	assert_false(arch.has_initialization_failed(), "旧 async_init 收尾后，重试应清除旧失败状态。")

	arch.dispose()


## 验证 dispose 会唤醒等待中的并发 init 调用，且旧初始化恢复后不会写回状态。
func test_dispose_during_init_cancels_waiters_and_stale_resume() -> void:
	if Gf.has_architecture():
		Gf.get_architecture().dispose()
	Gf._architecture = null

	var arch: GFArchitecture = GFArchitecture.new()
	var slow_utility: SlowInitUtility = SlowInitUtility.new()
	await arch.register_utility_instance(slow_utility)

	var first_state: Dictionary = { "done": false }
	var second_state: Dictionary = { "done": false }
	@warning_ignore("missing_await")
	_await_arch_init(arch, first_state)
	await get_tree().process_frame
	@warning_ignore("missing_await")
	_await_arch_init(arch, second_state)
	await get_tree().process_frame

	arch.dispose()
	await get_tree().process_frame

	assert_true(GFVariantData.get_option_bool(second_state, "done"), "dispose 应唤醒正在等待初始化完成的并发调用。")
	assert_false(arch.is_inited(), "dispose 后架构不应被标记为已初始化。")

	slow_utility.async_continue.emit()
	await get_tree().process_frame
	await get_tree().process_frame

	assert_true(GFVariantData.get_option_bool(first_state, "done"), "旧初始化 await 恢复后应安全退出。")
	assert_false(arch.is_inited(), "旧初始化恢复后不应重新写回已初始化状态。")
	assert_false(slow_utility.ready_called, "被 dispose 中断的模块不应继续进入 ready。")


## 验证 async_init 超时轮询路径下 dispose 也会取消等待者和迟到恢复。
func test_dispose_during_timed_async_init_cancels_waiters_and_stale_resume() -> void:
	if Gf.has_architecture():
		Gf.get_architecture().dispose()
	Gf._architecture = null

	var arch: GFArchitecture = GFArchitecture.new()
	arch.module_async_init_timeout_seconds = 1.0
	var slow_utility: SlowInitUtility = SlowInitUtility.new()
	await arch.register_utility_instance(slow_utility)
	watch_signals(arch)

	var first_state: Dictionary = { "done": false }
	@warning_ignore("missing_await")
	_await_arch_init(arch, first_state)
	await get_tree().process_frame

	assert_true(slow_utility.async_started, "限时 async_init 路径应已进入异步等待。")

	arch.dispose()
	await get_tree().process_frame

	assert_true(GFVariantData.get_option_bool(first_state, "done"), "dispose 应取消限时 async_init 的外层等待。")
	assert_false(arch.is_inited(), "dispose 后架构不应被标记为已初始化。")
	assert_signal_emit_count(arch, "initialization_finished", 1)

	slow_utility.async_continue.emit()
	await get_tree().process_frame
	await get_tree().process_frame

	assert_false(arch.is_inited(), "限时 async_init 迟到恢复后不应重新写回已初始化状态。")
	assert_false(slow_utility.ready_called, "被 dispose 中断的限时 async_init 模块不应进入 ready。")
	assert_signal_emit_count(arch, "initialization_finished", 1)


## 验证 dispose 后架构进入终态，不能被重新初始化或继续写入。
func test_disposed_architecture_rejects_reuse_and_late_registration() -> void:
	var arch: GFArchitecture = GFArchitecture.new()

	arch.dispose()
	arch.dispose()
	await arch.register_utility_instance(DummyUtility.new())
	await arch.init()
	var created: Object = arch.create_instance(FactoryCommand)

	assert_null(created, "dispose 后 create_instance 应返回 null。")
	assert_push_error("[GFArchitecture] register_utility 失败：架构已 dispose，不能继续修改注册表。")
	assert_push_error("[GFArchitecture] init 失败：架构已 dispose，不能重新初始化。")
	assert_push_error("[GFArchitecture] create_instance 失败：架构已 dispose。")


## 验证无架构时 Gf 门面方法只报错并返回空值，不发生空引用崩溃。
func test_facade_returns_null_when_architecture_missing() -> void:
	if Gf.has_architecture():
		Gf.get_architecture().dispose()
	Gf._architecture = null

	var model: Variant = Gf.get_model(DummyModel)

	assert_push_error("[GF] get_model 失败：架构尚未初始化，请先注册架构。")
	assert_true(model == null, "架构缺失时 get_model 应安全返回 null。")


## 验证核心架构对空输入进行防御，不发生空引用崩溃。
func test_architecture_null_inputs_are_rejected() -> void:
	var arch: GFArchitecture = GFArchitecture.new()

	var command_result: Variant = arch.send_command(null)
	var query_result: Variant = arch.send_query(null)
	arch.send_event(null)
	await arch.register_utility_instance_as(null, UtilityBase)

	assert_true(command_result == null, "空 command 应返回 null。")
	assert_true(query_result == null, "空 query 应返回 null。")
	assert_push_error("[GFArchitecture] send_command 失败：command 为空。")
	assert_push_error("[GFArchitecture] send_query 失败：query 为空。")
	assert_push_error("[GFArchitecture] send_event 失败：event_instance 为空。")
	assert_push_error("[GFArchitecture] register_utility_instance_as 失败：实例为空。")
	arch.dispose()


## 验证命令/查询误传没有 execute() 的对象时会输出警告并安全返回 null。
func test_architecture_warns_when_command_or_query_lacks_execute() -> void:
	var arch: GFArchitecture = GFArchitecture.new()

	var command_result: Variant = arch.send_command(NoExecuteObject.new())
	var query_result: Variant = arch.send_query(NoExecuteObject.new())

	assert_true(command_result == null, "缺少 execute() 的 command 应返回 null。")
	assert_true(query_result == null, "缺少 execute() 的 query 应返回 null。")
	assert_push_warning("[GFArchitecture] send_command 失败：command 缺少 execute() 方法，已忽略。")
	assert_push_warning("[GFArchitecture] send_query 失败：query 缺少 execute() 方法，已忽略。")
	arch.dispose()


func _await_arch_init(arch: GFArchitecture, state: Dictionary) -> void:
	await arch.init()
	state["done"] = true


func _await_context_ready(context: GFNodeContext, state: Dictionary) -> void:
	state["result"] = await context.wait_until_ready()
	state["done"] = true


func _await_gf_init(state: Dictionary) -> void:
	await Gf.init()
	state["done"] = true


func _dummy_utility(value: Variant) -> DummyUtility:
	if value is DummyUtility:
		return value
	return null


func _parent_scoped_utility(value: Variant) -> ParentScopedUtility:
	if value is ParentScopedUtility:
		return value
	return null


func _local_scoped_utility(value: Variant) -> LocalScopedUtility:
	if value is LocalScopedUtility:
		return value
	return null


func _local_lookup_system(value: Variant) -> LocalLookupSystem:
	if value is LocalLookupSystem:
		return value
	return null


func _factory_command(value: Variant) -> FactoryCommand:
	if value is FactoryCommand:
		return value
	return null


func _injected_factory_command(value: Variant) -> InjectedFactoryCommand:
	if value is InjectedFactoryCommand:
		return value
	return null


func _disposable_factory_command(value: Variant) -> DisposableFactoryCommand:
	if value is DisposableFactoryCommand:
		return value
	return null


func _factory_node(value: Variant) -> FactoryNode:
	if value is FactoryNode:
		return value
	return null


func _async_installer_utility(value: Variant) -> AsyncInstallerUtilityFixture:
	if value is AsyncInstallerUtilityFixture:
		return value
	return null


func _state_architecture(state: Dictionary) -> GFArchitecture:
	var value: Variant = GFVariantData.get_option_value(state, "architecture")
	if value is GFArchitecture:
		var architecture: GFArchitecture = value
		return architecture
	return null


func _object_script(instance: Object) -> Script:
	var value: Variant = instance.get_script()
	if value is Script:
		var script: Script = value
		return script
	return null


func _restore_project_setting(setting_name: String, had_setting: bool, previous_value: Variant) -> void:
	if had_setting:
		ProjectSettings.set_setting(setting_name, previous_value)
	else:
		ProjectSettings.set_setting(setting_name, null)
