## GFArchitecture: 管理 Model、System 和 Utility 的注册与生命周期的容器。
##
## 生命周期遵循四阶段初始化协议：
##   阶段一 (init)       ：各模块按声明依赖 DAG 执行自身内部变量初始化。
##   阶段二 (async_init) ：按同一 DAG 串行执行异步准备（可使用 await）。
##   阶段三 (ready)      ：当前模块的声明依赖已 ready，可完成同步装配。
##   阶段四 (activation) ：按依赖顺序完成异步启动，全部成功后才开放运行时准入。
## [br]
## @api public
## [br]
## @category runtime_service
## [br]
## @since 3.17.0
## [br]
## @layer kernel/core
class_name GFArchitecture


# --- 信号 ---

## 当一次初始化流程完成或被 dispose() 中断后发出。
## [br]
## @api public
signal initialization_finished

## 当一次初始化流程因为框架级保护失败后发出。
## [br]
## @api public
## [br]
## @param reason: 初始化失败原因。
signal initialization_failed(reason: String)

## 当异步关闭流程或同步强制释放发布类型化终态时发出。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @param result: 类型化关闭结果快照。
signal shutdown_finished(result: GFArchitectureShutdownResult)

## 当一轮项目级 Installer 成功提交、失败回滚完成或被 dispose() 中断后发出。
## [br]
## @api public
## [br]
## @since 1.14.1
signal project_installers_finished


# --- 枚举 ---

## 可由架构访问策略解析的模块类型。
## [br]
## @api public
## [br]
## @since 11.0.0
enum ModuleKind {
	## Model 模块。
	MODEL,
	## System 模块。
	SYSTEM,
	## Utility 模块。
	UTILITY,
}

## 模块访问的架构作用域。
## [br]
## @api public
## [br]
## @since 11.0.0
enum ModuleLookupScope {
	## 按当前架构的父级回退与 strict_dependency_lookup 规则解析。
	INHERITED,
	## 只解析当前架构，不回退父级。
	LOCAL,
}


# --- 常量 ---

## 依赖绑定记录脚本。
## [br]
## @api framework_internal
## [br]
## @layer kernel/core
const GFBindingBase = preload("res://addons/gf/kernel/core/gf_binding.gd")

## 架构声明式装配器脚本。
## [br]
## @api framework_internal
## [br]
## @layer kernel/core
const GFBinderBase = preload("res://addons/gf/kernel/core/gf_binder.gd")

## 工厂绑定生命周期定义脚本。
## [br]
## @api framework_internal
## [br]
## @layer kernel/core
const GFBindingLifetimesBase = preload("res://addons/gf/kernel/core/gf_binding_lifetimes.gd")

## 时间提供器基类脚本。
## [br]
## @api framework_internal
## [br]
## @layer kernel/core
const GFTimeProviderBase = preload("res://addons/gf/kernel/base/gf_time_provider.gd")
const _GF_ASYNC_CALL_SCRIPT = preload("res://addons/gf/kernel/core/gf_async_call.gd")
const _GF_ARCHITECTURE_LIFECYCLE_PLAN_SCRIPT = preload("res://addons/gf/kernel/core/gf_architecture_lifecycle_plan.gd")
const _GF_ARCHITECTURE_SHUTDOWN_RESULT_SCRIPT = preload("res://addons/gf/kernel/core/gf_architecture_shutdown_result.gd")
const _GF_ARCHITECTURE_SNAPSHOT_COORDINATOR_SCRIPT = preload("res://addons/gf/kernel/core/gf_architecture_snapshot_coordinator.gd")
const _GF_ARCHITECTURE_TICK_SCHEDULER_SCRIPT = preload("res://addons/gf/kernel/core/gf_architecture_tick_scheduler.gd")
const _GF_KERNEL_RUNTIME_SCRIPT = preload("res://addons/gf/kernel/core/gf_kernel_runtime.gd")
const _GF_VARIANT_ACCESS_SCRIPT = preload("res://addons/gf/kernel/core/gf_variant_access.gd")
const _FACTORY_RESOLUTION_BINDING_KEY: String = "binding"
const _FACTORY_RESOLUTION_CREATED_SINGLETONS_KEY: String = "created_singletons"
const _FACTORY_RESOLUTION_FAILED_KEY: String = "failed"
const _FACTORY_RESOLUTION_INSTANCE_KEY: String = "instance"
const _FACTORY_RESOLUTION_SCRIPT_KEY: String = "script"
const _FACTORY_RESOLUTION_STACK_KEY: String = "stack"
const _PARENT_CHAIN_ENTRIES_KEY: String = "entries"
const _PARENT_CHAIN_CYCLE_DETECTED_KEY: String = "cycle_detected"
const _PARENT_CHAIN_CYCLE_ARCHITECTURE_KEY: String = "cycle_architecture"
const _PARENT_CHAIN_CYCLE_DEPTH_KEY: String = "cycle_depth"
const _PARENT_CHAIN_CYCLE_START_DEPTH_KEY: String = "cycle_start_depth"
const _PARENT_CHAIN_TRUNCATED_KEY: String = "truncated"

## 命令历史服务 capability key。
## [br]
## @api public
## [br]
## @since 8.0.0
const SERVICE_COMMAND_HISTORY_STORE: StringName = &"gf.kernel.command_history_store"

## 分帧快照 API 默认每帧处理的 Model 数量。
## [br]
## @api public
## [br]
## @since 5.0.0
const DEFAULT_SNAPSHOT_MODELS_PER_FRAME: int = 8
const _MAX_LIFECYCLE_TIMEOUT_SECONDS: float = 86_400.0
const _MAX_LIFECYCLE_PARENT_DEPTH: int = 64
const _MAX_TOPOLOGY_SERVICE_INTENTS: int = 64
const _REQUIRED_REGISTRATION_ACCEPTED: int = 0
const _REQUIRED_REGISTRATION_REJECTED_CALLER_OWNS: int = 1
const _REQUIRED_REGISTRATION_REJECTED_ARCHITECTURE_SETTLED: int = 2
const _REQUIRED_REGISTRATION_REJECTED_ARCHITECTURE_OWNS: int = 3


# --- 公共变量 ---

## 单个模块 async_init() 的最长等待时间。0 时不启用超时。
## 默认关闭；项目可按自身加载预算显式启用。
## [br]
## @api public
## [br]
## @since 1.23.0
var module_async_init_timeout_seconds: float = 0.0:
	set(value):
		if (
			not is_finite(value)
			or value < 0.0
			or value > _MAX_LIFECYCLE_TIMEOUT_SECONDS
		):
			push_error(
				"[GFArchitecture] module_async_init_timeout_seconds 必须是 0 到 86400 之间的有限值。"
			)
			return
		module_async_init_timeout_seconds = value

## 严格依赖查询模式。开启后本架构查询不到本地模块时不会回退父级架构。
## [br]
## @api public
## [br]
## @since 1.23.0
var strict_dependency_lookup: bool = false

## 架构激活阶段的总等待上限（秒）。
## 0 时不启用 deadline；默认 30 秒。
## [br]
## @api public
## [br]
## @since 11.0.0
var activation_timeout_seconds: float = 30.0:
	set(value):
		if (
			not is_finite(value)
			or value < 0.0
			or value > _MAX_LIFECYCLE_TIMEOUT_SECONDS
		):
			push_error(
				"[GFArchitecture] activation_timeout_seconds 必须是 0 到 86400 之间的有限值。"
			)
			return
		activation_timeout_seconds = value

## 架构 quiesce 阶段的总等待上限（秒）。
## 0 时不启用 deadline；默认 10 秒。
## [br]
## @api public
## [br]
## @since 11.0.0
var shutdown_timeout_seconds: float = 10.0:
	set(value):
		if (
			not is_finite(value)
			or value < 0.0
			or value > _MAX_LIFECYCLE_TIMEOUT_SECONDS
		):
			push_error(
				"[GFArchitecture] shutdown_timeout_seconds 必须是 0 到 86400 之间的有限值。"
			)
			return
		shutdown_timeout_seconds = value

## 最近一次初始化失败原因；没有失败时为空字符串。
## [br]
## @api public
var last_initialization_error: String = ""


# --- 私有变量 ---

var _system_registry: ModuleRegistry = ModuleRegistry.new("System")
var _model_registry: ModuleRegistry = ModuleRegistry.new("Model")
var _utility_registry: ModuleRegistry = ModuleRegistry.new("Utility")
var _systems: Dictionary = _system_registry.instances
var _models: Dictionary = _model_registry.instances
var _utilities: Dictionary = _utility_registry.instances
var _factories: Dictionary = {}
var _factory_resolution_context_stack: Array[Dictionary] = []
var _module_lifecycle_stages: Dictionary = {}
var _services: Dictionary = {}
var _event_system: GFTypeEventSystem
var _time_provider: Object
var _tick_scheduler: GFArchitectureTickScheduler
var _snapshot_coordinator: GFArchitectureSnapshotCoordinator
var _runtime: GFKernelRuntime
var _parent_architecture: GFArchitecture = null
var _project_installers_applied: bool = false
var _project_installers_running: bool = false
var _stale_async_write_block_count: int = 0
var _initialization_failure_settlement_in_progress: bool = false
var _active_async_scopes: Array[GFAsyncScope] = []
var _active_lifecycle_plan: GFArchitectureLifecyclePlan = null
var _lifecycle_plan_in_progress: GFArchitectureLifecyclePlan = null
var _activation_scope: GFAsyncScope = null
var _shutdown_scope: GFAsyncScope = null
var _shutdown_completion: GFAsyncCompletion = null
var _last_shutdown_result: GFArchitectureShutdownResult = null
var _shutdown_duplicate_request_count: int = 0
var _lifecycle_hook_depth: int = 0
var _topology_mutation: TopologyMutation = null
var _next_topology_mutation_id: int = 1
var _last_lifecycle_plan_error: String = ""
var _module_disposal_claims: Dictionary = {}
var _module_disposal_session_depth: int = 0
var _active_external_dependency_leases: Array[Dictionary] = []
var _child_external_dependency_leases: Dictionary = {}
var _next_child_external_dependency_lease_id: int = 1


# --- Godot 生命周期方法 ---

## 创建架构容器，可选择指定父级架构作为依赖回退来源。
## [br]
## @api public
## [br]
## @param parent_architecture: 父级架构；为空时不启用回退。
func _init(parent_architecture: GFArchitecture = null) -> void:
	_runtime = _GF_KERNEL_RUNTIME_SCRIPT.new()
	_event_system = GFTypeEventSystem.new()
	_tick_scheduler = _GF_ARCHITECTURE_TICK_SCHEDULER_SCRIPT.new().configure(
		_systems,
		_utilities,
		_module_lifecycle_stages
	)
	_snapshot_coordinator = _GF_ARCHITECTURE_SNAPSHOT_COORDINATOR_SCRIPT.new().configure(
		_models,
		Callable(self, &"_get_command_history_store"),
		DEFAULT_SNAPSHOT_MODELS_PER_FRAME
	)
	_assign_parent_architecture(parent_architecture, "_init")


# --- 公共方法 ---

## 检查架构是否已完成四阶段启动并提交 READY。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @return 四阶段启动全部完成且 activation 已提交时返回 true，否则返回 false。
func is_inited() -> bool:
	return _runtime.is_ready()


## 检查最近一次初始化是否因为框架级保护失败。
## [br]
## @api public
## [br]
## @return 最近一次初始化失败返回 true。
func has_initialization_failed() -> bool:
	return _runtime.has_failed()


## 检查当前架构生命周期是否仍处于可安全继续已接纳异步写回的活动状态。
## QUIESCING 期间该值仍可为 true；它不代表允许接纳新工作，新请求还必须通过
## is_accepting_runtime_work() 检查。
## [br]
## @api public
## [br]
## @since 1.23.2
## [br]
## @return 正在初始化、已完成初始化或正在收敛已接纳工作，且未被 dispose() 或失败保护中断时返回 true。
func is_lifecycle_active() -> bool:
	return _runtime.is_lifecycle_active()


## 检查架构是否正在执行第四阶段激活。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @return 架构正在执行第四阶段激活时返回 true。
func is_activating() -> bool:
	return _runtime.is_activating()


## 检查架构是否已经关闭新工作、正在等待已接纳工作收敛。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @return 架构正在 quiesce 且尚未进入同步释放阶段时返回 true。
func is_quiescing() -> bool:
	return _runtime.is_quiescing()


## 检查架构是否仍接纳新的运行时工作。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @return 仅在完整激活并处于 READY 时返回 true。
func is_accepting_runtime_work() -> bool:
	return _runtime.is_ready() and _topology_mutation == null


## 检查架构是否已经完成释放并进入不可恢复终态。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @return dispose() 已完成时返回 true。
func is_disposed() -> bool:
	return _runtime.is_disposed()


## 检查架构是否正在执行释放回调。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @return dispose() 已开始但尚未完成时返回 true。
func is_disposing() -> bool:
	return _runtime.is_disposing()


## 获取当前架构生命周期 generation。
## 每次 init()、dispose() 或初始化失败都会推进 generation，用于异步流程判断自身是否仍属于当前生命周期。
## [br]
## @api public
## [br]
## @since 5.0.0
## [br]
## @return 当前生命周期 generation。
func get_lifecycle_generation() -> int:
	return _runtime.get_lifecycle_generation()


## 检查指定生命周期 generation 是否仍是当前活动生命周期。
## [br]
## @api public
## [br]
## @since 5.0.0
## [br]
## @param lifecycle_generation: 由 get_lifecycle_generation() 读取到的 generation。
## [br]
## @return generation 匹配且架构生命周期仍活动时返回 true。
func is_lifecycle_generation_active(lifecycle_generation: int) -> bool:
	return _runtime.is_generation_current(lifecycle_generation) and is_lifecycle_active()


## 检查指定模块实例是否已经完成 ready 阶段。
## [br]
## @api public
## [br]
## @param instance: 由当前架构注册的模块实例。
## [br]
## @return 模块完成 ready 阶段时返回 true。
func is_module_ready(instance: Object) -> bool:
	return _is_module_ready_for_lookup(instance)


## 检查模块是否已经完成第四阶段激活。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @param instance: 由当前架构本地注册的模块实例。
## [br]
## @return 模块属于当前架构且已完成第四阶段激活时返回 true。
func is_module_active(instance: Object) -> bool:
	return _is_committed_module_at_lifecycle_stage(instance, 4)


## 获取最近一次关闭结果的隔离副本。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @return 尚未关闭时返回 null。
func get_last_shutdown_result() -> GFArchitectureShutdownResult:
	if _last_shutdown_result == null:
		return null
	return _last_shutdown_result.duplicate_result()


## 将当前架构标记为初始化失败，并唤醒等待初始化或 Installer 的调用方。
## DISPOSING / DISPOSED 是不可恢复终态，迟到调用不会改写其状态或 generation。
## [br]
## @api public
## [br]
## @since 1.23.2
## [br]
## @param reason: 初始化失败原因。
func fail_initialization(reason: String) -> void:
	var failure_reason: String = reason
	if failure_reason.is_empty():
		failure_reason = "[GFArchitecture] 初始化失败。"
	_fail_initialization(failure_reason, _runtime.get_lifecycle_generation())


## 获取父级架构。Scoped 架构会在本地未找到依赖时回退到父级架构查询。
## [br]
## @api public
## [br]
## @return 父级架构实例；未设置时返回 null。
func get_parent_architecture() -> GFArchitecture:
	return _parent_architecture


## 设置父级架构。不会接管父级生命周期。
## [br]
## @api public
## [br]
## @param parent_architecture: 要作为依赖回退来源的父级架构。
func set_parent_architecture(parent_architecture: GFArchitecture) -> void:
	_assign_parent_architecture(parent_architecture, "set_parent_architecture")


## 检查项目级 Installer 是否已经应用到当前架构。
## [br]
## @api public
## [br]
## @return 已应用返回 true。
func has_project_installers_applied() -> bool:
	return _project_installers_applied


## 检查项目级 Installer 是否正在应用。
## [br]
## @api public
## [br]
## @return 正在应用返回 true。
func is_project_installers_running() -> bool:
	return _project_installers_running


## 标记项目级 Installer 已开始应用。
## 失败结算、迟到写屏障或 quiesce/dispose 期间会拒绝开始。
## [br]
## @api public
## [br]
## @since 1.14.1
## [br]
## @return 成功开始返回 true；已经完成、正在运行或生命周期拒绝准入时返回 false。
func begin_project_installers() -> bool:
	if _project_installers_applied or _project_installers_running:
		return false

	if (
		_initialization_failure_settlement_in_progress
		or _stale_async_write_block_count > 0
		or _runtime.is_quiescing()
		or _runtime.is_disposing()
		or _runtime.is_disposed()
	):
		return false

	if _runtime.has_failed() and not _runtime.is_ready() and not _runtime.is_initializing():
		var _cleared_failure: bool = _runtime.clear_failure()
		last_initialization_error = ""

	_project_installers_running = true
	return true


## 标记项目级 Installer 已应用。由 Gf 启动入口调用。失败结算、迟到写屏障、
## 初始化失败或 quiesce/dispose 期间保持 no-op。
## [br]
## @api public
## [br]
## @since 1.14.1
func mark_project_installers_applied() -> void:
	if (
		not _project_installers_running
		or _initialization_failure_settlement_in_progress
		or _stale_async_write_block_count > 0
		or _runtime.has_failed()
		or _runtime.is_quiescing()
		or _runtime.is_disposing()
		or _runtime.is_disposed()
	):
		return
	var was_running: bool = _project_installers_running
	_project_installers_applied = true
	_project_installers_running = false
	if was_running:
		project_installers_finished.emit()


## 标记项目级 Installer 应用完成并唤醒等待方；准入已关闭时保持 no-op。
## [br]
## @api public
## [br]
## @since 1.14.1
func finish_project_installers() -> void:
	mark_project_installers_applied()


## 创建一个声明式装配器，便于 Installer 使用 fluent API 注册模块与工厂。
## [br]
## @api public
## [br]
## @return 绑定到当前架构的装配器。
## [br]
## @schema return: GFBinder owned by this architecture.
func create_binder() -> GFBinder:
	return GFBinderBase.new(self)


## 初始化架构及所有注册的组件（四阶段）。
## 阶段一：按声明依赖 DAG 调用模块的 init()，用于初始化自身内部变量。
## 阶段二：按同一 DAG 串行 await 模块的 async_init()，用于异步准备。
## 阶段三：调用模块的 ready()；当前模块声明的依赖已 ready，未声明依赖无可用保证。
## 阶段四：按声明依赖顺序调用 begin_activation()，全部成功后才提交 READY。
## 并发调用复用同一初始化事务；首个调用拥有共享流程的取消策略，后续调用的
## token 只取消自身等待，不会中断共享初始化。架构已经 READY 时幂等成功优先于
## 调用方 token 的取消状态。初始化失败尚在回滚与终态通知期间时，同步重入会
## 返回 false，待结算完成后才允许安全重试。
## [br]
## @api public
## [br]
## @since 5.0.0
## [br]
## @param cancellation_token: 可选的初始化取消令牌。
## [br]
## @return 初始化完成且架构处于 ready 状态时返回 true。
func init(cancellation_token: GFCancellationToken = null) -> bool:
	if _runtime.is_quiescing() or _runtime.is_disposing() or _runtime.is_disposed():
		push_error("[GFArchitecture] init 失败：架构正在或已经 dispose，不能重新初始化。")
		return false
	if _initialization_failure_settlement_in_progress:
		return false
	if _runtime.is_ready():
		return true

	if _runtime.is_initializing() or _runtime.is_activating():
		var waiting_serial: int = _runtime.get_lifecycle_generation()
		return await _await_existing_initialization(
			waiting_serial,
			cancellation_token
		)

	if _runtime.has_failed() and _stale_async_write_block_count > 0:
		return false
	if _runtime.has_failed():
		if not _runtime.clear_failure():
			return false
		last_initialization_error = ""

	var current_serial: int = _runtime.begin_initialization()
	if current_serial < 0:
		return false
	last_initialization_error = ""
	if cancellation_token != null and cancellation_token.is_cancel_requested():
		_fail_initialization(
			"[GFArchitecture] 初始化已取消：%s。" % String(cancellation_token.get_cancel_reason()),
			current_serial
		)
		return false
	_lifecycle_hook_depth += 1
	_on_init()
	_lifecycle_hook_depth -= 1
	if (
		not _runtime.is_initializing()
		or not _is_lifecycle_current(current_serial)
		or _runtime.has_failed()
	):
		return false

	var lifecycle_plan: GFArchitectureLifecyclePlan = _compile_lifecycle_plan_or_fail(current_serial)
	if lifecycle_plan == null:
		return false
	if (
		not _runtime.is_initializing()
		or not _is_lifecycle_current(current_serial)
		or _runtime.has_failed()
	):
		return false
	_lifecycle_plan_in_progress = lifecycle_plan
	var lease_report: Dictionary = _acquire_external_dependency_leases(
		lifecycle_plan,
		current_serial
	)
	if not _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(
		lease_report,
		"ok",
		false
	):
		_fail_initialization(
			"[GFArchitecture] 初始化失败：无法冻结父级外部依赖。",
			current_serial
		)
		return false
	_active_external_dependency_leases = (
		_get_external_dependency_lease_array(lease_report)
	)
	if not await _advance_lifecycle_plan_to_stage(
		lifecycle_plan,
		1,
		current_serial,
		cancellation_token
	):
		return false
	if not await _advance_lifecycle_plan_to_stage(
		lifecycle_plan,
		2,
		current_serial,
		cancellation_token
	):
		return false
	if not await _advance_lifecycle_plan_to_stage(
		lifecycle_plan,
		3,
		current_serial,
		cancellation_token
	):
		return false
	if not _all_registered_modules_reached_stage(3):
		_fail_initialization(
			"[GFArchitecture] 初始化提交失败：仍有已注册模块未完成 ready 阶段。",
			current_serial
		)
		return false

	_refresh_cached_utility_refs()
	if cancellation_token != null and cancellation_token.is_cancel_requested():
		_fail_initialization(
			"[GFArchitecture] 初始化已取消：%s。" % String(
				cancellation_token.get_cancel_reason()
			),
			current_serial
		)
		return false
	if not _runtime.begin_activation(current_serial):
		_fail_initialization(
			"[GFArchitecture] 初始化提交失败：无法进入 activation 状态。",
			current_serial
		)
		return false
	var activated: bool = await _activate_lifecycle_plan(
		lifecycle_plan,
		current_serial,
		cancellation_token
	)
	if not activated:
		return false
	if cancellation_token != null and cancellation_token.is_cancel_requested():
		_fail_initialization(
			"[GFArchitecture] 初始化已取消：%s。" % String(
				cancellation_token.get_cancel_reason()
			),
			current_serial
		)
		return false
	if _runtime.finish_activation(current_serial):
		_active_lifecycle_plan = lifecycle_plan
		_lifecycle_plan_in_progress = null
		_refresh_tick_caches()
		initialization_finished.emit()
		return (
			_runtime.is_ready()
			and _runtime.is_generation_current(current_serial)
		)
	return false


## 异步关闭架构。
##
## 若活动子架构仍持有本架构的外部依赖租约，本方法会在改变任何生命周期
## 状态前返回失败；否则新工作准入会不可逆关闭，已接纳工作按激活计划逆序
## quiesce，随后每个模块的同步 dispose/release hook 恰好执行一次。并发调用共享
## 同一流程；首个调用拥有共享流程的 cancellation token 与 deadline 策略，后续
## 调用在参数校验通过后只等待并复制同一终态结果。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @param cancellation_token: 可选关闭取消令牌。
## [br]
## @param timeout_seconds: cooperative quiesce 与异步等待预算；仅 -1 使用 shutdown_timeout_seconds。最终同步释放不承诺墙钟硬上限。
## [br]
## @return 类型化关闭结果。
func shutdown_async(
	cancellation_token: GFCancellationToken = null,
	timeout_seconds: float = -1.0
) -> GFArchitectureShutdownResult:
	if (
		not is_finite(timeout_seconds)
		or (timeout_seconds < 0.0 and timeout_seconds != -1.0)
		or timeout_seconds > _MAX_LIFECYCLE_TIMEOUT_SECONDS
	):
		var invalid_timeout_msec: int = Time.get_ticks_msec()
		return _GF_ARCHITECTURE_SHUTDOWN_RESULT_SCRIPT.failed(
			ERR_INVALID_PARAMETER,
			"shutdown_async timeout_seconds must be -1 or a finite value from 0 to 86400.",
			[],
			[],
			invalid_timeout_msec,
			invalid_timeout_msec
		)
	if _runtime.is_disposed():
		return _GF_ARCHITECTURE_SHUTDOWN_RESULT_SCRIPT.already_disposed()
	if _shutdown_completion != null and _shutdown_completion.is_pending():
		_shutdown_duplicate_request_count += 1
		await _shutdown_completion.completed
		var shared_result_value: Variant = _shutdown_completion.get_result()
		if shared_result_value is GFArchitectureShutdownResult:
			var shared_result: GFArchitectureShutdownResult = shared_result_value
			return shared_result.duplicate_result()
		return _GF_ARCHITECTURE_SHUTDOWN_RESULT_SCRIPT.forced(
			"Shared shutdown completed without a typed result."
		)
	if _runtime.is_ready() and _has_live_child_external_dependency_leases():
		var blocked_at_msec: int = Time.get_ticks_msec()
		return _GF_ARCHITECTURE_SHUTDOWN_RESULT_SCRIPT.failed(
			ERR_BUSY,
			(
				"Architecture shutdown requires child architectures with "
				+ "external dependency leases to close first."
			),
			[],
			[],
			blocked_at_msec,
			blocked_at_msec
		)
	var started_at_msec: int = Time.get_ticks_msec()
	_shutdown_duplicate_request_count = 0
	_shutdown_completion = GFAsyncCompletion.new()
	if _runtime.is_initializing() or _runtime.is_activating():
		var interrupted_reason: String = (
			"Shutdown interrupted architecture initialization or activation."
		)
		var interrupted_unfinished: Array[Dictionary] = (
			_snapshot_forced_unfinished_modules(interrupted_reason)
		)
		_cancel_active_async_scopes("[GFArchitecture] shutdown_async 中断了尚未完成的初始化。")
		_force_dispose_internal()
		var interrupted_result: GFArchitectureShutdownResult = (
			_GF_ARCHITECTURE_SHUTDOWN_RESULT_SCRIPT.forced(
				interrupted_reason,
				[],
				interrupted_unfinished,
				started_at_msec,
				Time.get_ticks_msec(),
				_shutdown_duplicate_request_count
			)
		)
		_publish_shutdown_result(interrupted_result)
		initialization_finished.emit()
		return interrupted_result.duplicate_result()

	if not _runtime.begin_quiesce():
		var transition_reason: String = (
			"Architecture could not enter quiesce."
		)
		var transition_unfinished: Array[Dictionary] = (
			_snapshot_forced_unfinished_modules(transition_reason)
		)
		var transition_result: GFArchitectureShutdownResult = (
			_GF_ARCHITECTURE_SHUTDOWN_RESULT_SCRIPT.forced(
				transition_reason,
				[],
				transition_unfinished,
				started_at_msec,
				Time.get_ticks_msec(),
				_shutdown_duplicate_request_count
			)
		)
		_force_dispose_internal()
		_publish_shutdown_result(transition_result)
		return transition_result.duplicate_result()
	_fail_active_factory_resolution_contexts()

	var effective_timeout_seconds: float = (
		shutdown_timeout_seconds
		if timeout_seconds < 0.0
		else timeout_seconds
	)
	var deadline_msec: int = _make_deadline_msec(
		started_at_msec,
		effective_timeout_seconds
	)
	var topology_wait_report: Dictionary = await _await_topology_stability(
		cancellation_token,
		deadline_msec
	)
	if _runtime.is_disposed() and _last_shutdown_result != null:
		return _last_shutdown_result.duplicate_result()
	if not _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(
		topology_wait_report,
		"succeeded",
		false
	):
		var topology_shutdown_report: Dictionary = (
			_make_topology_wait_shutdown_report(topology_wait_report)
		)
		_force_dispose_internal()
		var topology_result: GFArchitectureShutdownResult = (
			_make_shutdown_result(
				topology_shutdown_report,
				started_at_msec,
				Time.get_ticks_msec()
			)
		)
		_publish_shutdown_result(topology_result)
		return topology_result.duplicate_result()

	_shutdown_scope = _begin_module_async_scope()
	var quiesce_report: Dictionary = await _quiesce_active_modules(
		cancellation_token,
		deadline_msec
	)
	if _runtime.is_disposed() and _last_shutdown_result != null:
		return _last_shutdown_result.duplicate_result()
	if _shutdown_scope != null:
		if _shutdown_scope.is_active():
			_shutdown_scope.complete()
		_untrack_async_scope(_shutdown_scope)
		_shutdown_scope = null

	_force_dispose_internal()
	var completed_at_msec: int = Time.get_ticks_msec()
	var shutdown_result: GFArchitectureShutdownResult = _make_shutdown_result(
		quiesce_report,
		started_at_msec,
		completed_at_msec
	)
	_publish_shutdown_result(shutdown_result)
	return shutdown_result.duplicate_result()


## 强制同步销毁架构及所有注册组件。
##
## 该方法用于 SceneTree 退出等无法等待的终止路径；正常退出应优先 await
## shutdown_async()，以便已接纳工作先收敛。
## [br]
## @api public
## [br]
## @since 3.17.0
func dispose() -> void:
	if _runtime.is_disposing() or _runtime.is_disposed():
		return
	var started_at_msec: int = Time.get_ticks_msec()
	var was_initializing: bool = _runtime.is_initializing() or _runtime.is_activating()
	if _shutdown_completion == null or not _shutdown_completion.is_pending():
		_shutdown_duplicate_request_count = 0
		_shutdown_completion = GFAsyncCompletion.new()
	var forced_reason: String = "Architecture was synchronously disposed."
	var forced_unfinished: Array[Dictionary] = (
		_snapshot_forced_unfinished_modules(forced_reason)
	)
	_cancel_active_async_scopes("[GFArchitecture] 架构已强制 dispose。")
	_force_dispose_internal()
	var forced_result: GFArchitectureShutdownResult = (
		_GF_ARCHITECTURE_SHUTDOWN_RESULT_SCRIPT.forced(
			forced_reason,
			[],
			forced_unfinished,
			started_at_msec,
			Time.get_ticks_msec(),
			_shutdown_duplicate_request_count
		)
	)
	_publish_shutdown_result(forced_result)
	if was_initializing:
		initialization_finished.emit()


## 驱动所有参与 tick 的 System 与 Utility 的每帧更新。
## 在架构初始化完成后方可生效。
## 若已注册 GFTimeProvider，则自动将 delta 经过时间缩放/暂停处理后再传递给参与 tick 的模块。
## 设置了 ignore_pause 的模块在暂停时将接收原始 delta。
## 设置了 ignore_time_scale 的模块在未暂停时将跳过 time_scale。
## [br]
## @api public
## [br]
## @param delta: 距上一帧的时间（秒）。
func tick(delta: float) -> void:
	if not is_accepting_runtime_work():
		return
	var time_provider: Object = _get_time_provider()
	_tick_scheduler.drive_tick(delta, time_provider)


## 驱动所有参与 physics_tick 的 System 与 Utility 的每物理帧更新。
## 在架构初始化完成后方可生效。
## 若已注册 GFTimeProvider，则自动将 delta 经过时间缩放/暂停处理后再传递给参与 physics_tick 的模块。
## 设置了 ignore_pause 的模块在暂停时将接收原始 delta。
## 设置了 ignore_time_scale 的模块在未暂停时将跳过 time_scale。
## [br]
## @api public
## [br]
## @param delta: 距上一物理帧的时间（秒）。
func physics_tick(delta: float) -> void:
	if not is_accepting_runtime_work():
		return
	var time_provider: Object = _get_time_provider()
	_tick_scheduler.drive_physics_tick(delta, time_provider)


## 执行命令实例。支持 await：'await send_command(MyCommand.new())'。
## command 缺少 execute() 方法时会输出 warning 并返回 null。
## [br]
## @api public
## [br]
## @param command: 要执行的命令实例。
## [br]
## @return 命令 execute() 的返回值；空对象或缺少 execute() 时返回 null。
## [br]
## @schema return: Variant command result returned by command.execute().
func send_command(command: Object) -> Variant:
	if command == null:
		push_error("[GFArchitecture] send_command 失败：command 为空。")
		return null
	if not _can_execute_runtime("send_command"):
		return null

	if not _inject_dependencies_if_needed(command, _get_active_lifecycle_serial_or_unbound(), true):
		return null
	if command.has_method("execute"):
		return command.call("execute")
	push_warning("[GFArchitecture] send_command 失败：command 缺少 execute() 方法，已忽略。")
	return null


## 执行查询实例并返回结果。
## query 缺少 execute() 方法时会输出 warning 并返回 null。
## [br]
## @api public
## [br]
## @param query: 要执行的查询实例。
## [br]
## @return 查询 execute() 的返回值；空对象或缺少 execute() 时返回 null。
## [br]
## @schema return: Variant query result returned by query.execute().
func send_query(query: Object) -> Variant:
	if query == null:
		push_error("[GFArchitecture] send_query 失败：query 为空。")
		return null
	if not _can_execute_runtime("send_query"):
		return null

	if not _inject_dependencies_if_needed(query, _get_active_lifecycle_serial_or_unbound(), true):
		return null
	if query.has_method("execute"):
		return query.call("execute")
	push_warning("[GFArchitecture] send_query 失败：query 缺少 execute() 方法，已忽略。")
	return null


## 通过事件系统发送类型事件实例。
## [br]
## @api public
## [br]
## @param event_instance: 要分发的事件实例。
func send_event(event_instance: Object) -> void:
	if event_instance == null:
		push_error("[GFArchitecture] send_event 失败：event_instance 为空。")
		return
	if not _can_execute_runtime("send_event"):
		return

	_event_system.send(event_instance)


## 为脚本类型注册事件监听器。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param event_type: 要监听的脚本类型。
## [br]
## @param listener: 事件监听器契约。
## [br]
## @param priority: 回调优先级，数值越大越先执行，默认为 0。
func register_event(event_type: Script, listener: GFEventListener, priority: int = 0) -> void:
	if not _can_mutate_runtime("register_event"):
		return
	_event_system.register(event_type, listener, priority)


## 为脚本类型注册带拥有者的事件监听器。
## 拥有者注销或释放后，可通过 unregister_owner_events() 一次性清理相关监听。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param owner: 监听器拥有者。
## [br]
## @param event_type: 要监听的脚本类型。
## [br]
## @param listener: 事件监听器契约。
## [br]
## @param priority: 回调优先级，数值越大越先执行，默认为 0。
func register_event_owned(owner: Object, event_type: Script, listener: GFEventListener, priority: int = 0) -> void:
	if not _can_mutate_runtime("register_event_owned"):
		return
	_event_system.register_owned(owner, event_type, listener, priority)


## 订阅脚本类型事件并返回可取消句柄。
##
## listener 携带 owner 时返回的句柄会绑定该 owner 生命周期。`once` 订阅会在
## 首个回调开始前失效，保证嵌套事件派发不会重复进入同一订阅。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @param event_type: 要订阅的脚本类型。
## [br]
## @param listener: 事件监听器契约。
## [br]
## @param priority: 回调优先级，数值越大越先执行，默认为 0。
## [br]
## @param once: 是否在首个回调开始前自动取消订阅。
## [br]
## @return 可幂等取消的订阅句柄；架构不可修改或参数无效时返回非活动句柄。
func subscribe_event(
	event_type: Script,
	listener: GFEventListener,
	priority: int = 0,
	once: bool = false
) -> GFSubscriptionToken:
	if not _can_mutate_runtime("subscribe_event"):
		return GFSubscriptionToken.new()
	return _event_system.subscribe(event_type, listener, priority, once)


## 为脚本类型注册可赋值事件监听器。
## 监听基类事件时，也会收到继承自该脚本类型的事件实例。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param base_event_type: 要监听的基类脚本类型。
## [br]
## @param listener: 事件监听器契约。
## [br]
## @param priority: 回调优先级，数值越大越先执行，默认为 0。
func register_assignable_event(base_event_type: Script, listener: GFEventListener, priority: int = 0) -> void:
	if not _can_mutate_runtime("register_assignable_event"):
		return
	_event_system.register_assignable(base_event_type, listener, priority)


## 为脚本类型注册带拥有者的可赋值事件监听器。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param owner: 监听器拥有者。
## [br]
## @param base_event_type: 要监听的基类脚本类型。
## [br]
## @param listener: 事件监听器契约。
## [br]
## @param priority: 回调优先级，数值越大越先执行，默认为 0。
func register_assignable_event_owned(
	owner: Object,
	base_event_type: Script,
	listener: GFEventListener,
	priority: int = 0
) -> void:
	if not _can_mutate_runtime("register_assignable_event_owned"):
		return
	_event_system.register_assignable_owned(owner, base_event_type, listener, priority)


## 订阅可赋值类型事件并返回可取消句柄。
##
## listener 携带 owner 时返回的句柄会绑定该 owner 生命周期。监听基类脚本时，
## 订阅也会收到其派生脚本实例；`once` 在首个匹配回调开始前生效。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @param base_event_type: 要订阅的基类脚本类型。
## [br]
## @param listener: 事件监听器契约。
## [br]
## @param priority: 回调优先级，数值越大越先执行，默认为 0。
## [br]
## @param once: 是否在首个匹配回调开始前自动取消订阅。
## [br]
## @return 可幂等取消的订阅句柄；架构不可修改或参数无效时返回非活动句柄。
func subscribe_assignable_event(
	base_event_type: Script,
	listener: GFEventListener,
	priority: int = 0,
	once: bool = false
) -> GFSubscriptionToken:
	if not _can_mutate_runtime("subscribe_assignable_event"):
		return GFSubscriptionToken.new()
	return _event_system.subscribe_assignable(base_event_type, listener, priority, once)


## 为脚本类型注销事件监听器。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param event_type: 要注销的脚本类型。
## [br]
## @param listener: 要移除的事件监听器契约。
func unregister_event(event_type: Script, listener: GFEventListener) -> void:
	if not _can_mutate_runtime("unregister_event"):
		return
	_event_system.unregister(event_type, listener)


## 注销带拥有者的脚本类型事件监听器。
## 只移除 owner 与监听器回调都匹配的监听，不影响其它 owner 使用同一 Callable 注册的监听。
## [br]
## @api public
## [br]
## @since 5.0.0
## [br]
## @param owner: 注册监听时使用的拥有者。
## [br]
## @param event_type: 要注销的脚本类型。
## [br]
## @param listener: 要移除的事件监听器契约。
func unregister_event_owned(owner: Object, event_type: Script, listener: GFEventListener) -> void:
	if not _can_mutate_runtime("unregister_event_owned"):
		return
	_event_system.unregister_owned(owner, event_type, listener)


## 注销可赋值类型事件监听器。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param base_event_type: 注册时使用的基类脚本类型。
## [br]
## @param listener: 要移除的事件监听器契约。
func unregister_assignable_event(base_event_type: Script, listener: GFEventListener) -> void:
	if not _can_mutate_runtime("unregister_assignable_event"):
		return
	_event_system.unregister_assignable(base_event_type, listener)


## 注销带拥有者的可赋值类型事件监听器。
## [br]
## @api public
## [br]
## @since 5.0.0
## [br]
## @param owner: 注册监听时使用的拥有者。
## [br]
## @param base_event_type: 注册时使用的基类脚本类型。
## [br]
## @param listener: 要移除的事件监听器契约。
func unregister_assignable_event_owned(owner: Object, base_event_type: Script, listener: GFEventListener) -> void:
	if not _can_mutate_runtime("unregister_assignable_event_owned"):
		return
	_event_system.unregister_assignable_owned(owner, base_event_type, listener)


## 注册轻量级 StringName 事件监听器。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param event_id: StringName 事件标识符。
## [br]
## @param listener: 简单事件监听器契约。
func register_simple_event(event_id: StringName, listener: GFEventListener) -> void:
	if not _can_mutate_runtime("register_simple_event"):
		return
	_event_system.register_simple(event_id, listener)


## 注册带拥有者的轻量级 StringName 事件监听器。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param owner: 监听器拥有者。
## [br]
## @param event_id: StringName 事件标识符。
## [br]
## @param listener: 简单事件监听器契约。
func register_simple_event_owned(owner: Object, event_id: StringName, listener: GFEventListener) -> void:
	if not _can_mutate_runtime("register_simple_event_owned"):
		return
	_event_system.register_simple_owned(owner, event_id, listener)


## 订阅轻量级 StringName 事件并返回可取消句柄。
##
## listener 携带 owner 时返回的句柄会绑定该 owner 生命周期。`once` 订阅会在
## 首个回调开始前失效，保证嵌套事件派发不会重复进入同一订阅。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @param event_id: StringName 事件标识符。
## [br]
## @param listener: 简单事件监听器契约。
## [br]
## @param once: 是否在首个回调开始前自动取消订阅。
## [br]
## @return 可幂等取消的订阅句柄；架构不可修改或参数无效时返回非活动句柄。
func subscribe_simple_event(
	event_id: StringName,
	listener: GFEventListener,
	once: bool = false
) -> GFSubscriptionToken:
	if not _can_mutate_runtime("subscribe_simple_event"):
		return GFSubscriptionToken.new()
	return _event_system.subscribe_simple(event_id, listener, once)


## 注销轻量级 StringName 事件监听器。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param event_id: StringName 事件标识符。
## [br]
## @param listener: 要移除的简单事件监听器契约。
func unregister_simple_event(event_id: StringName, listener: GFEventListener) -> void:
	if not _can_mutate_runtime("unregister_simple_event"):
		return
	_event_system.unregister_simple(event_id, listener)


## 注销带拥有者的轻量级 StringName 事件监听器。
## [br]
## @api public
## [br]
## @since 5.0.0
## [br]
## @param owner: 注册监听时使用的拥有者。
## [br]
## @param event_id: StringName 事件标识符。
## [br]
## @param listener: 要移除的简单事件监听器契约。
func unregister_simple_event_owned(owner: Object, event_id: StringName, listener: GFEventListener) -> void:
	if not _can_mutate_runtime("unregister_simple_event_owned"):
		return
	_event_system.unregister_simple_owned(owner, event_id, listener)


## 注销某个拥有者注册过的所有事件监听器。
## [br]
## @api public
## [br]
## @param owner: 要清理监听器的拥有者。
func unregister_owner_events(owner: Object) -> void:
	_event_system.unregister_owner(owner)


## 发送轻量级 StringName 事件，避免高频 new() 带来的 GC 压力。
## [br]
## @api public
## [br]
## @param event_id: StringName 事件标识符。
## [br]
## @param payload: 可选的事件附加数据。
## [br]
## @schema payload: Variant payload passed unchanged to simple event listeners.
func send_simple_event(event_id: StringName, payload: Variant = null) -> void:
	if not _can_execute_runtime("send_simple_event"):
		return
	_event_system.send_simple(event_id, payload)


## 获取事件系统诊断统计。
## [br]
## @api public
## [br]
## @return 包含各事件轨道监听数量与 pending 操作数量的字典。
## [br]
## @schema return: Dictionary produced by GFTypeEventSystem.get_debug_stats().
func get_event_debug_stats() -> Dictionary:
	return _event_system.get_debug_stats()


## 获取事件监听器诊断明细。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param options: 诊断选项，支持 include_entries。
## [br]
## @schema options: Dictionary，可包含 include_entries。
## [br]
## @return 监听器诊断报告。
## [br]
## @schema return: Dictionary produced by GFTypeEventSystem.get_listener_diagnostics().
func get_event_listener_diagnostics(options: Dictionary = {}) -> Dictionary:
	return _event_system.get_listener_diagnostics(options)


## 清理 owner 已释放的事件监听器。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @return 本次立即移除或排队清理的监听器数量。
func compact_event_listeners() -> int:
	if not _can_mutate_runtime("compact_event_listeners"):
		return 0
	return _event_system.compact_released_owner_listeners()


## 配置事件系统调试与保护选项。
## [br]
## @api public
## [br]
## @param max_dispatch_depth: 最大嵌套派发深度；小于等于 0 表示不限制。
## [br]
## @param trace_enabled: 是否记录派发追踪。
## [br]
## @param max_trace_entries: 最多保留的追踪条目数。
func configure_event_debugging(
	max_dispatch_depth: int = GFTypeEventSystem.DEFAULT_MAX_DISPATCH_DEPTH,
	trace_enabled: bool = false,
	max_trace_entries: int = 64
) -> void:
	if not _can_mutate_runtime("configure_event_debugging"):
		return
	_event_system.max_dispatch_depth = max_dispatch_depth
	_event_system.trace_enabled = trace_enabled
	_event_system.max_trace_entries = max_trace_entries


## 获取最近事件派发追踪条目。
## [br]
## @api public
## [br]
## @return 从旧到新的追踪条目副本。
## [br]
## @schema return: Array of Dictionary trace entries with event, listener, owner, and dispatch metadata.
func get_event_dispatch_trace() -> Array[Dictionary]:
	return _event_system.get_dispatch_trace()


## 清空事件派发追踪。
## [br]
## @api public
func clear_event_dispatch_trace() -> void:
	if not _can_mutate_runtime("clear_event_dispatch_trace"):
		return
	_event_system.clear_dispatch_trace()


# --- 公共方法（注册） ---

## 注册 System 实例。
## [br]
## @api public
## [br]
## @since 5.0.0
## [br]
## @param script_cls: 系统的脚本类。
## [br]
## @param instance: 系统实例。
## [br]
## @return 注册成功、且运行时热注册完成生命周期推进时返回 true。
func register_system(script_cls: Script, instance: Object) -> bool:
	if _runtime.is_ready():
		var hot_registered: bool = await _register_initialized_module(
			_system_registry,
			script_cls,
			instance
		)
		if hot_registered:
			_refresh_tick_caches()
		return hot_registered
	if not _register_module(_system_registry, script_cls, instance):
		return false

	_refresh_tick_caches()
	return true


## 注册 Model 实例。
## [br]
## @api public
## [br]
## @since 5.0.0
## [br]
## @param script_cls: 模型的脚本类。
## [br]
## @param instance: 模型实例。
## [br]
## @return 注册成功、且运行时热注册完成生命周期推进时返回 true。
func register_model(script_cls: Script, instance: Object) -> bool:
	if _runtime.is_ready():
		return await _register_initialized_module(
			_model_registry,
			script_cls,
			instance
		)
	if not _register_module(_model_registry, script_cls, instance):
		return false

	return true


## 注册 Utility 实例。
## [br]
## @api public
## [br]
## @since 5.0.0
## [br]
## @param script_cls: 工具的脚本类。
## [br]
## @param instance: 工具实例。
## [br]
## @return 注册成功、且运行时热注册完成生命周期推进时返回 true。
func register_utility(script_cls: Script, instance: Object) -> bool:
	if _runtime.is_ready():
		var hot_registered: bool = await _register_initialized_module(
			_utility_registry,
			script_cls,
			instance
		)
		if hot_registered:
			_refresh_cached_utility_refs()
			_refresh_tick_caches()
		return hot_registered
	if not _register_module(_utility_registry, script_cls, instance):
		return false

	_refresh_cached_utility_refs()
	_refresh_tick_caches()
	return true


## 替换 System 实例。新实例成功完成当前生命周期阶段后才会提交替换。
## [br]
## @api public
## [br]
## @since 5.0.0
## [br]
## @param script_cls: 系统的脚本类。
## [br]
## @param instance: 新系统实例。
## [br]
## @return 替换成功时返回 true。
func replace_system(script_cls: Script, instance: Object) -> bool:
	var replaced: bool = await _replace_module(_system_registry, script_cls, instance)
	if replaced:
		_refresh_tick_caches()
	return replaced


## 替换 Model 实例。新实例成功完成当前生命周期阶段后才会提交替换。
## [br]
## @api public
## [br]
## @since 5.0.0
## [br]
## @param script_cls: 模型的脚本类。
## [br]
## @param instance: 新模型实例。
## [br]
## @return 替换成功时返回 true。
func replace_model(script_cls: Script, instance: Object) -> bool:
	return await _replace_module(_model_registry, script_cls, instance)


## 替换 Utility 实例。新实例成功完成当前生命周期阶段后才会提交替换。
## [br]
## @api public
## [br]
## @since 5.0.0
## [br]
## @param script_cls: 工具的脚本类。
## [br]
## @param instance: 新工具实例。
## [br]
## @return 替换成功时返回 true。
func replace_utility(script_cls: Script, instance: Object) -> bool:
	var replaced: bool = await _replace_module(_utility_registry, script_cls, instance)
	if replaced:
		_refresh_cached_utility_refs()
		_refresh_tick_caches()
	return replaced


## 注册短生命周期对象工厂。
## [br]
## @api public
## [br]
## @since 5.0.0
## [br]
## @param script_cls: 要创建的脚本类型。
## [br]
## @param factory: 返回对象实例的工厂回调。
## [br]
## @param lifetime: 工厂生命周期，默认每次 create_instance() 都创建新对象。
## [br]
## @return 工厂注册成功时返回 true。
func register_factory(
	script_cls: Script,
	factory: Callable,
	lifetime: int = GFBindingLifetimesBase.Lifetime.TRANSIENT
) -> bool:
	if not _can_mutate_registration_state("register_factory"):
		return false
	if not _can_mutate_factory_topology("register_factory"):
		return false
	if script_cls == null:
		push_error("[GFArchitecture] register_factory 失败：脚本类型为空。")
		return false
	if not factory.is_valid():
		push_error("[GFArchitecture] register_factory 失败：factory 无效。")
		return false
	if not _validate_factory_lifetime(lifetime, "register_factory"):
		return false
	if _factories.has(script_cls):
		push_warning("[GFArchitecture] register_factory：类型已注册，已忽略重复注册。若需要替换，请使用 replace_factory()。")
		return false
	_factories[script_cls] = GFBindingBase.new(script_cls, factory, self, lifetime, true)
	return true


## 注册已有实例作为短生命周期工厂入口。该实例以单例方式返回。
## [br]
## @api public
## [br]
## @since 5.0.0
## [br]
## @param script_cls: 要创建的脚本类型。
## [br]
## @param instance: 要暴露的实例。
## [br]
## @return 工厂入口注册成功时返回 true。
func register_factory_instance(script_cls: Script, instance: Object) -> bool:
	if not _can_mutate_registration_state("register_factory_instance"):
		return false
	if not _can_mutate_factory_topology("register_factory_instance"):
		return false
	if script_cls == null:
		push_error("[GFArchitecture] register_factory_instance 失败：脚本类型为空。")
		return false
	if instance == null:
		push_error("[GFArchitecture] register_factory_instance 失败：实例为空。")
		return false
	if _factories.has(script_cls):
		push_warning("[GFArchitecture] register_factory_instance：类型已注册，已忽略重复注册。若需要替换，请使用 replace_factory_instance()。")
		return false
	_factories[script_cls] = GFBindingBase.new(script_cls, instance, self, GFBindingLifetimesBase.Lifetime.SINGLETON, true, false)
	return true


## 替换短生命周期对象工厂。
## [br]
## @api public
## [br]
## @since 5.0.0
## [br]
## @param script_cls: 要创建的脚本类型。
## [br]
## @param factory: 新工厂回调。
## [br]
## @param lifetime: 工厂生命周期。
## [br]
## @return 工厂替换成功时返回 true。
func replace_factory(
	script_cls: Script,
	factory: Callable,
	lifetime: int = GFBindingLifetimesBase.Lifetime.TRANSIENT
) -> bool:
	if not _can_mutate_registration_state("replace_factory"):
		return false
	if not _can_mutate_factory_topology("replace_factory"):
		return false
	if script_cls == null:
		push_error("[GFArchitecture] replace_factory 失败：脚本类型为空。")
		return false
	if not factory.is_valid():
		push_error("[GFArchitecture] replace_factory 失败：factory 无效。")
		return false
	if not _validate_factory_lifetime(lifetime, "replace_factory"):
		return false
	_clear_factory_binding(script_cls)
	_factories[script_cls] = GFBindingBase.new(script_cls, factory, self, lifetime, true)
	return true


## 替换已有实例工厂入口。
## [br]
## @api public
## [br]
## @since 5.0.0
## [br]
## @param script_cls: 要创建的脚本类型。
## [br]
## @param instance: 要暴露的实例。
## [br]
## @return 工厂入口替换成功时返回 true。
func replace_factory_instance(script_cls: Script, instance: Object) -> bool:
	if not _can_mutate_registration_state("replace_factory_instance"):
		return false
	if not _can_mutate_factory_topology("replace_factory_instance"):
		return false
	if script_cls == null:
		push_error("[GFArchitecture] replace_factory_instance 失败：脚本类型为空。")
		return false
	if instance == null:
		push_error("[GFArchitecture] replace_factory_instance 失败：实例为空。")
		return false
	_clear_factory_binding(script_cls)
	_factories[script_cls] = GFBindingBase.new(script_cls, instance, self, GFBindingLifetimesBase.Lifetime.SINGLETON, true, false)
	return true


## 注销短生命周期对象工厂。
## [br]
## @api public
## [br]
## @since 5.0.0
## [br]
## @param script_cls: 要移除的脚本类型。
## [br]
## @return 存在并成功注销工厂时返回 true。
func unregister_factory(script_cls: Script) -> bool:
	if not _can_mutate_registration_state("unregister_factory"):
		return false
	if not _can_mutate_factory_topology("unregister_factory"):
		return false
	if script_cls == null or not _factories.has(script_cls):
		return false
	_clear_factory_binding(script_cls)
	return true


## 检查当前架构或父级架构是否注册了指定工厂。
## [br]
## @api public
## [br]
## @param script_cls: 要查询的脚本类型。
## [br]
## @return 工厂存在时返回 true。
func has_factory(script_cls: Script) -> bool:
	if script_cls == null:
		return false
	var current: GFArchitecture = self
	var visited: Dictionary = _create_parent_lookup_visited()
	while current != null:
		if current._factories.has(script_cls):
			return true
		current = _get_next_parent_for_lookup(current, visited, "has_factory")
	return false


## 注册运行时服务 capability。
## 同一 service_key 在同一架构内只能有一个 provider；子架构可通过父级回退读取父级服务。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param service_key: 稳定服务键。
## [br]
## @param provider: 服务提供对象。
## [br]
## @return 注册成功时返回 true。
func register_service(service_key: StringName, provider: Object) -> bool:
	if not _can_mutate_runtime("register_service"):
		return false
	if service_key == &"":
		push_error("[GFArchitecture] register_service 失败：service_key 为空。")
		return false
	if provider == null:
		push_error("[GFArchitecture] register_service 失败：provider 为空。")
		return false
	if _topology_mutation != null:
		return _stage_topology_service_registration(
			_topology_mutation,
			service_key,
			provider
		)
	if _services.has(service_key):
		var existing_provider: Object = _get_dictionary_object(_services, service_key)
		if existing_provider == provider:
			return true
		push_error("[GFArchitecture] register_service 失败：service_key 已注册：%s。" % String(service_key))
		return false
	_services[service_key] = provider
	return true


## 注销运行时服务 capability。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param service_key: 稳定服务键。
## [br]
## @param provider: 可选的当前服务提供对象；传入时必须与已注册 provider 匹配。
## [br]
## @return 注销成功时返回 true。
func unregister_service(service_key: StringName, provider: Object = null) -> bool:
	if not _can_mutate_runtime("unregister_service"):
		return false
	if service_key == &"":
		push_error("[GFArchitecture] unregister_service 失败：service_key 为空。")
		return false
	if _topology_mutation != null:
		return _stage_topology_service_unregistration(
			_topology_mutation,
			service_key,
			provider
		)
	if not _services.has(service_key):
		return false
	var existing_provider: Object = _get_dictionary_object(_services, service_key)
	if provider != null and existing_provider != provider:
		push_error("[GFArchitecture] unregister_service 失败：provider 与当前服务不匹配：%s。" % String(service_key))
		return false
	var _removed_service: bool = _services.erase(service_key)
	return true


## 获取运行时服务 capability。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param service_key: 稳定服务键。
## [br]
## @param include_parent: 为 true 时允许沿父级架构查找。
## [br]
## @return 服务提供对象；不存在时返回 null。
func get_service(service_key: StringName, include_parent: bool = true) -> Object:
	if service_key == &"":
		push_error("[GFArchitecture] get_service 失败：service_key 为空。")
		return null
	return _get_service_with_parent_lookup(service_key, include_parent)


## 检查运行时服务 capability 是否存在。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param service_key: 稳定服务键。
## [br]
## @param include_parent: 为 true 时允许沿父级架构查找。
## [br]
## @return 服务存在时返回 true。
func has_service(service_key: StringName, include_parent: bool = true) -> bool:
	return get_service(service_key, include_parent) != null


## 为已注册 System 增加一个额外查询别名。
## 适合把具体实现以抽象基类或接口式脚本暴露给调用方。
## [br]
## @api public
## [br]
## @param alias_cls: 调用 get_system() 时使用的别名脚本类。
## [br]
## @param target_cls: 已注册 System 的实际脚本类。
func register_system_alias(alias_cls: Script, target_cls: Script) -> void:
	var _registered_alias: bool = _register_module_alias(
		_system_registry,
		alias_cls,
		target_cls
	)


## 为已注册 Model 增加一个额外查询别名。
## [br]
## @api public
## [br]
## @param alias_cls: 调用 get_model() 时使用的别名脚本类。
## [br]
## @param target_cls: 已注册 Model 的实际脚本类。
func register_model_alias(alias_cls: Script, target_cls: Script) -> void:
	var _registered_alias: bool = _register_module_alias(
		_model_registry,
		alias_cls,
		target_cls
	)


## 为已注册 Utility 增加一个额外查询别名。
## [br]
## @api public
## [br]
## @param alias_cls: 调用 get_utility() 时使用的别名脚本类。
## [br]
## @param target_cls: 已注册 Utility 的实际脚本类。
func register_utility_alias(alias_cls: Script, target_cls: Script) -> void:
	var _registered_alias: bool = _register_module_alias(
		_utility_registry,
		alias_cls,
		target_cls
	)


## 注销 System 查询别名，不影响目标 System 实例。
## [br]
## @api public
## [br]
## @since 5.0.0
## [br]
## @param alias_cls: 要移除的别名脚本类。
func unregister_system_alias(alias_cls: Script) -> void:
	var _unregistered_alias: bool = _unregister_module_alias(_system_registry, alias_cls)


## 注销 Model 查询别名，不影响目标 Model 实例。
## [br]
## @api public
## [br]
## @since 5.0.0
## [br]
## @param alias_cls: 要移除的别名脚本类。
func unregister_model_alias(alias_cls: Script) -> void:
	var _unregistered_alias: bool = _unregister_module_alias(_model_registry, alias_cls)


## 注销 Utility 查询别名，不影响目标 Utility 实例。
## [br]
## @api public
## [br]
## @since 5.0.0
## [br]
## @param alias_cls: 要移除的别名脚本类。
func unregister_utility_alias(alias_cls: Script) -> void:
	var _unregistered_alias: bool = _unregister_module_alias(_utility_registry, alias_cls)


## 便捷注册 System 实例，自动从实例获取脚本类作为注册键。
## [br]
## @api public
## [br]
## @since 5.0.0
## [br]
## @param instance: 系统实例，必须附加有 GDScript 脚本。
## [br]
## @return 注册成功时返回 true。
func register_system_instance(instance: Object) -> bool:
	if instance == null:
		push_error("[GFArchitecture] register_system_instance 失败：实例为空。")
		return false
	var script: Script = _get_instance_script_or_null(instance, "register_system_instance")
	if script == null:
		return false
	return await register_system(script, instance)


## 便捷注册 Model 实例，自动从实例获取脚本类作为注册键。
## [br]
## @api public
## [br]
## @since 5.0.0
## [br]
## @param instance: 模型实例，必须附加有 GDScript 脚本。
## [br]
## @return 注册成功时返回 true。
func register_model_instance(instance: Object) -> bool:
	if instance == null:
		push_error("[GFArchitecture] register_model_instance 失败：实例为空。")
		return false
	var script: Script = _get_instance_script_or_null(instance, "register_model_instance")
	if script == null:
		return false
	return await register_model(script, instance)


## 便捷注册 Utility 实例，自动从实例获取脚本类作为注册键。
## [br]
## @api public
## [br]
## @since 5.0.0
## [br]
## @param instance: 工具实例，必须附加有 GDScript 脚本。
## [br]
## @return 注册成功时返回 true。
func register_utility_instance(instance: Object) -> bool:
	if instance == null:
		push_error("[GFArchitecture] register_utility_instance 失败：实例为空。")
		return false
	var script: Script = _get_instance_script_or_null(instance, "register_utility_instance")
	if script == null:
		return false
	return await register_utility(script, instance)


## 便捷注册 System，并同时以 alias_cls 作为额外查询键。
## [br]
## @api public
## [br]
## @since 5.0.0
## [br]
## @param instance: System 实例。
## [br]
## @param alias_cls: 额外查询脚本类。
## [br]
## @return 注册成功并写入 alias 时返回 true。
func register_system_instance_as(instance: Object, alias_cls: Script) -> bool:
	if _runtime.is_ready():
		push_error("[GFArchitecture] register_system_instance_as 失败：activation 后 alias 拓扑不可变。")
		return false
	var script: Script = _get_instance_script_or_null(instance, "register_system_instance_as")
	if script == null:
		return false

	var registered: bool = await register_system_instance(instance)
	if _system_registry._has_direct(script):
		register_system_alias(alias_cls, script)
	return registered and _system_registry.aliases.has(alias_cls)


## 便捷注册 Model，并同时以 alias_cls 作为额外查询键。
## [br]
## @api public
## [br]
## @since 5.0.0
## [br]
## @param instance: Model 实例。
## [br]
## @param alias_cls: 额外查询脚本类。
## [br]
## @return 注册成功并写入 alias 时返回 true。
func register_model_instance_as(instance: Object, alias_cls: Script) -> bool:
	if _runtime.is_ready():
		push_error("[GFArchitecture] register_model_instance_as 失败：activation 后 alias 拓扑不可变。")
		return false
	var script: Script = _get_instance_script_or_null(instance, "register_model_instance_as")
	if script == null:
		return false

	var registered: bool = await register_model_instance(instance)
	if _model_registry._has_direct(script):
		register_model_alias(alias_cls, script)
	return registered and _model_registry.aliases.has(alias_cls)


## 便捷注册 Utility，并同时以 alias_cls 作为额外查询键。
## [br]
## @api public
## [br]
## @since 5.0.0
## [br]
## @param instance: Utility 实例。
## [br]
## @param alias_cls: 额外查询脚本类。
## [br]
## @return 注册成功并写入 alias 时返回 true。
func register_utility_instance_as(instance: Object, alias_cls: Script) -> bool:
	if _runtime.is_ready():
		push_error("[GFArchitecture] register_utility_instance_as 失败：activation 后 alias 拓扑不可变。")
		return false
	var script: Script = _get_instance_script_or_null(instance, "register_utility_instance_as")
	if script == null:
		return false

	var registered: bool = await register_utility_instance(instance)
	if _utility_registry._has_direct(script):
		register_utility_alias(alias_cls, script)
	return registered and _utility_registry.aliases.has(alias_cls)


## 注销 System 实例。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @param script_cls: 系统的脚本类。
## [br]
## @return 模块完成 quiesce 并从活动拓扑移除时返回 true。
func unregister_system(script_cls: Script) -> bool:
	var unregistered: bool = await _unregister_module(
		_system_registry,
		script_cls
	)
	if unregistered:
		_refresh_tick_caches()
	return unregistered


## 注销 Model 实例。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @param script_cls: 模型的脚本类。
## [br]
## @return 模块完成 quiesce 并从活动拓扑移除时返回 true。
func unregister_model(script_cls: Script) -> bool:
	return await _unregister_module(_model_registry, script_cls)


## 注销 Utility 实例。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @param script_cls: 工具的脚本类。
## [br]
## @return 模块完成 quiesce 并从活动拓扑移除时返回 true。
func unregister_utility(script_cls: Script) -> bool:
	var unregistered: bool = await _unregister_module(
		_utility_registry,
		script_cls
	)
	if unregistered:
		_refresh_cached_utility_refs()
		_refresh_tick_caches()
	return unregistered


# --- 公共方法（获取） ---

## 按冻结的作用域、必需性和 ready 策略解析已注册模块。
## 该入口供生成访问器与其他声明式依赖边界复用；required 只控制严格依赖缺失诊断，
## 不改变 strict_dependency_lookup 对父级回退的限制。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @param module_kind: 要解析的 Model、System 或 Utility 类型。
## [br]
## @param script_cls: 模块脚本类。
## [br]
## @param lookup_scope: 父级可见或仅当前架构的查询作用域。
## [br]
## @param required: 为 true 时，严格查询模式下缺失模块会输出 required miss。
## [br]
## @param require_ready: 为 true 时，仅返回已完成 ready 阶段的实例。
## [br]
## @return: 符合全部冻结策略的模块实例；未命中时返回 null。
func resolve_module_access(
	module_kind: ModuleKind,
	script_cls: Script,
	lookup_scope: ModuleLookupScope = ModuleLookupScope.INHERITED,
	required: bool = true,
	require_ready: bool = false
) -> Object:
	var module_registry: ModuleRegistry = _get_module_registry_for_access_kind(module_kind)
	if module_registry == null:
		push_error("[GFArchitecture] resolve_module_access 失败：module_kind 无效。")
		return null
	if script_cls == null:
		push_error("[GFArchitecture] resolve_module_access 失败：script_cls 为空。")
		return null

	match lookup_scope:
		ModuleLookupScope.INHERITED:
			return _get_registered_instance_with_parent_lookup(
				module_registry._label_key(),
				script_cls,
				require_ready,
				required
			)
		ModuleLookupScope.LOCAL:
			var instance: Object = _get_local_registered_instance(module_registry, script_cls)
			if instance == null:
				if required and strict_dependency_lookup:
					_report_strict_lookup_miss(script_cls, module_registry.label)
				return null
			return instance if not require_ready or _is_module_ready_for_lookup(instance) else null
		_:
			push_error("[GFArchitecture] resolve_module_access 失败：lookup_scope 无效。")
			return null


## 通过脚本类获取 System 实例。
## [br]
## @api public
## [br]
## @param script_cls: 脚本类。
## [br]
## @param require_ready: 为 true 时，仅返回已完成 ready 阶段的实例。
## [br]
## @return 系统实例，如果未找到则返回 null。
func get_system(script_cls: Script, require_ready: bool = false) -> Object:
	return resolve_module_access(
		ModuleKind.SYSTEM,
		script_cls,
		ModuleLookupScope.INHERITED,
		true,
		require_ready
	)


## 通过脚本类获取 Model 实例。
## [br]
## @api public
## [br]
## @param script_cls: 脚本类。
## [br]
## @param require_ready: 为 true 时，仅返回已完成 ready 阶段的实例。
## [br]
## @return 模型实例，如果未找到则返回 null。
func get_model(script_cls: Script, require_ready: bool = false) -> Object:
	return resolve_module_access(
		ModuleKind.MODEL,
		script_cls,
		ModuleLookupScope.INHERITED,
		true,
		require_ready
	)


## 通过脚本类获取 Utility 实例。
## [br]
## @api public
## [br]
## @param script_cls: 脚本类。
## [br]
## @param require_ready: 为 true 时，仅返回已完成 ready 阶段的实例。
## [br]
## @return 工具实例，如果未找到则返回 null。
func get_utility(script_cls: Script, require_ready: bool = false) -> Object:
	return resolve_module_access(
		ModuleKind.UTILITY,
		script_cls,
		ModuleLookupScope.INHERITED,
		true,
		require_ready
	)


## 可选查找 System 实例，未找到时不输出严格依赖缺失错误。
## 非严格模式沿用普通查询的父级回退与 alias 遮蔽规则；严格模式只检查当前架构。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @param script_cls: 脚本类。
## [br]
## @param require_ready: 为 true 时，仅返回已完成 ready 阶段的实例。
## [br]
## @return 系统实例；可选依赖不存在或尚未 ready 时返回 null。
func find_system(script_cls: Script, require_ready: bool = false) -> Object:
	return resolve_module_access(
		ModuleKind.SYSTEM,
		script_cls,
		ModuleLookupScope.INHERITED,
		false,
		require_ready
	)


## 可选查找 Model 实例，未找到时不输出严格依赖缺失错误。
## 非严格模式沿用普通查询的父级回退与 alias 遮蔽规则；严格模式只检查当前架构。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @param script_cls: 脚本类。
## [br]
## @param require_ready: 为 true 时，仅返回已完成 ready 阶段的实例。
## [br]
## @return 模型实例；可选依赖不存在或尚未 ready 时返回 null。
func find_model(script_cls: Script, require_ready: bool = false) -> Object:
	return resolve_module_access(
		ModuleKind.MODEL,
		script_cls,
		ModuleLookupScope.INHERITED,
		false,
		require_ready
	)


## 可选查找 Utility 实例，未找到时不输出严格依赖缺失错误。
## 非严格模式沿用普通查询的父级回退与 alias 遮蔽规则；严格模式只检查当前架构。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @param script_cls: 脚本类。
## [br]
## @param require_ready: 为 true 时，仅返回已完成 ready 阶段的实例。
## [br]
## @return 工具实例；可选依赖不存在或尚未 ready 时返回 null。
func find_utility(script_cls: Script, require_ready: bool = false) -> Object:
	return resolve_module_access(
		ModuleKind.UTILITY,
		script_cls,
		ModuleLookupScope.INHERITED,
		false,
		require_ready
	)


## 仅从当前架构获取 System，不回退父级架构。
## [br]
## @api public
## [br]
## @param script_cls: 脚本类。
## [br]
## @param require_ready: 为 true 时，仅返回已完成 ready 阶段的实例。
## [br]
## @return 当前架构中的系统实例，如果未找到则返回 null。
func get_local_system(script_cls: Script, require_ready: bool = false) -> Object:
	return resolve_module_access(
		ModuleKind.SYSTEM,
		script_cls,
		ModuleLookupScope.LOCAL,
		false,
		require_ready
	)


## 仅从当前架构获取 Model，不回退父级架构。
## [br]
## @api public
## [br]
## @param script_cls: 脚本类。
## [br]
## @param require_ready: 为 true 时，仅返回已完成 ready 阶段的实例。
## [br]
## @return 当前架构中的模型实例，如果未找到则返回 null。
func get_local_model(script_cls: Script, require_ready: bool = false) -> Object:
	return resolve_module_access(
		ModuleKind.MODEL,
		script_cls,
		ModuleLookupScope.LOCAL,
		false,
		require_ready
	)


## 仅从当前架构获取 Utility，不回退父级架构。
## [br]
## @api public
## [br]
## @param script_cls: 脚本类。
## [br]
## @param require_ready: 为 true 时，仅返回已完成 ready 阶段的实例。
## [br]
## @return 当前架构中的工具实例，如果未找到则返回 null。
func get_local_utility(script_cls: Script, require_ready: bool = false) -> Object:
	return resolve_module_access(
		ModuleKind.UTILITY,
		script_cls,
		ModuleLookupScope.LOCAL,
		false,
		require_ready
	)


## 通过已注册工厂创建短生命周期对象。
## 仅在架构已经提交 READY 且没有热拓扑事务时接纳；其它生命周期状态会在
## 调用 provider 前返回 null。
## [br]
## @api public
## [br]
## @since 1.9.0
## [br]
## @param script_cls: 要创建的脚本类型。
## [br]
## @return 新对象实例；运行时未开放、没有工厂或工厂返回非对象时返回 null。
func create_instance(script_cls: Script) -> Object:
	if script_cls == null:
		push_error("[GFArchitecture] create_instance 失败：脚本类型为空。")
		return null
	if not _can_execute_runtime("create_instance"):
		return null

	return _create_instance_for_requester(script_cls, self)


## 向任意对象注入当前架构依赖。
## [br]
## @api public
## [br]
## @param instance: 需要注入的对象。
func inject_object(instance: Object) -> void:
	if not _can_execute_runtime("inject_object"):
		return
	var _injected_dependencies: bool = _inject_dependencies_if_needed(instance)


## 递归向节点树中实现注入 Hook 的节点注入当前架构。
## [br]
## @api public
## [br]
## @param node: 节点树根节点。
func inject_node_tree(node: Node) -> void:
	if node == null:
		return
	if not _can_execute_runtime("inject_node_tree"):
		return

	_inject_node_tree(node)


# --- 公共方法（序列化） ---

## 收集所有已注册 Model 的状态快照。
## 捕获前会验证每个 Model 都有唯一稳定存档键；任一目标无效时整个捕获失败，
## 且失败 Result 不包含 `snapshot`，持久化层不得提交失败结果。
## [br]
## @api public
## [br]
## @since 3.0.0
## [br]
## @return 显式捕获 Result；成功时需取 `result.snapshot` 交给存储或恢复接口。
## [br]
## @schema return: Dictionary with ok: bool, optional snapshot: Dictionary keyed by stable model save key, and error: String. A failed result never contains snapshot.
func get_all_models_state() -> Dictionary:
	return _snapshot_coordinator.get_all_models_state()


## 分帧收集所有已注册 Model 的状态快照。
## 为保证耦合 Model 的默认持久化一致性，所有 `Model.to_dict()` 会在首次让帧前
## 同步冻结；`max_models_per_frame` 只分摊冻结数据的物化，不分摊 `to_dict()` 本身。
## 等待期间若 Model 注册表身份或稳定键发生变化，捕获会显式失败且不返回 snapshot。
## [br]
## @api public
## [br]
## @since 5.0.0
## [br]
## @param options: 可选参数，支持 max_models_per_frame；小于等于 0 时不主动让出帧。
## [br]
## @schema options: Dictionary，可包含 max_models_per_frame: int。
## [br]
## @return 显式捕获 Result；成功时需取 `result.snapshot` 交给存储或恢复接口。
## [br]
## @schema return: Dictionary with ok: bool, optional snapshot: Dictionary keyed by stable model save key, and error: String. A failed result never contains snapshot.
func get_all_models_state_async(options: Dictionary = {}) -> Dictionary:
	return await _snapshot_coordinator.get_all_models_state_async(options)


## 从状态字典恢复所有已注册 Model 的数据。
## `data` 必须是成功捕获 Result 的 `snapshot` 字段，而不是 Result 外壳。
## 恢复会先验证全部目标并保存基线，再应用并核对每个 Model；任一步失败会回滚
## 本事务已应用的全部 Model。快照键集合必须与当前直接注册的 Model 精确匹配；
## 未知键或缺少任一已注册 Model 都会在写入前被拒绝。
## [br]
## @api public
## [br]
## @since 3.0.0
## [br]
## @param data: 由 get_all_models_state() 成功 Result 的 `snapshot` 字段。
## [br]
## @schema data: Inner snapshot Dictionary keyed by stable model save key, storing serialized model data; do not pass the outer capture Result.
## [br]
## @return 原子恢复 Result；任一步失败时回滚已应用 Model。
## 失败时 `phase` 标记 validate/apply/commit；`rolled_back` 表示失败前的已应用状态
## 是否全部通过基线核对，validate 零写入失败固定为 false。
## [br]
## @schema return: Dictionary with ok: bool, phase: StringName, rolled_back: bool, and error: String.
func restore_all_models_state(data: Dictionary) -> Dictionary:
	return _snapshot_coordinator.restore_all_models_state(data)


## 分帧恢复所有已注册 Model 的数据。
## 与同步版本使用相同的 validate/apply/commit 事务；Model 会按
## `max_models_per_frame` 分帧应用和核对，失败时回滚本事务已应用的全部 Model。
## 快照键集合必须与当前直接注册的 Model 精确匹配。
## [br]
## @api public
## [br]
## @since 5.0.0
## [br]
## @param data: 由 get_all_models_state() 或 get_all_models_state_async() 成功 Result 的 `snapshot` 字段。
## [br]
## @schema data: Inner snapshot Dictionary keyed by stable model save key, storing serialized model data; do not pass the outer capture Result.
## [br]
## @param options: 可选参数，支持 max_models_per_frame；小于等于 0 时不主动让出帧。
## [br]
## @schema options: Dictionary，可包含 max_models_per_frame: int。
## [br]
## @return 原子恢复 Result；任一步失败时回滚已应用 Model。
## 失败时 `phase` 标记 validate/apply/commit；`rolled_back` 表示失败前的已应用状态
## 是否全部通过基线核对，validate 零写入失败固定为 false。
## [br]
## @schema return: Dictionary with ok: bool, phase: StringName, rolled_back: bool, and error: String.
func restore_all_models_state_async(
	data: Dictionary,
	options: Dictionary = {}
) -> Dictionary:
	return await _snapshot_coordinator.restore_all_models_state_async(data, options)


## 获取整个框架的全局快照，包含所有 Model 状态以及可选命令历史记录。
## 捕获成功的 snapshot 固定包含 `format_version` 与 `models`，注册完整命令历史
## 服务时还包含 Dictionary 形式的 `command_history`。任一捕获步骤失败时 Result
## 不包含 snapshot，持久化层不得提交失败结果。
## [br]
## @api public
## [br]
## @since 3.0.0
## [br]
## @return 显式捕获 Result；成功时需取 `result.snapshot` 交给存储或恢复接口。
## [br]
## @schema return: Dictionary with ok: bool, optional snapshot: Dictionary with format_version: int, models: Dictionary, and optional command_history: Dictionary, and error: String. A failed result never contains snapshot.
func get_global_snapshot() -> Dictionary:
	return _snapshot_coordinator.get_global_snapshot()


## 分帧获取整个框架的全局快照。
## 为保证 Model 与命令历史属于同一默认捕获点，全部 `Model.to_dict()` 与命令历史
## 会在首次让帧前同步冻结；`max_models_per_frame` 只分摊冻结 Model 数据的物化。
## 等待期间若 Model 注册表身份或稳定键发生变化，捕获会显式失败且不返回 snapshot。
## [br]
## @api public
## [br]
## @since 5.0.0
## [br]
## @param options: 可选参数，支持 max_models_per_frame；小于等于 0 时不主动让出帧。
## [br]
## @schema options: Dictionary，可包含 max_models_per_frame: int。
## [br]
## @return 显式捕获 Result；成功时需取 `result.snapshot` 交给存储或恢复接口。
## [br]
## @schema return: Dictionary with ok: bool, optional snapshot: Dictionary with format_version: int, models: Dictionary, and optional command_history: Dictionary, and error: String. A failed result never contains snapshot.
func get_global_snapshot_async(options: Dictionary = {}) -> Dictionary:
	return await _snapshot_coordinator.get_global_snapshot_async(options)


## 从全局快照中恢复整个框架的状态，包含 Model 状态以及可选命令历史记录。
## `data` 必须是成功捕获 Result 的 `snapshot` 字段。仅接受当前
## `format_version`、Dictionary `models` 与可选 Dictionary `command_history`；
## `models` 键集合必须与当前直接注册的 Model 精确匹配；不兼容旧式无版本快照、
## 缺项/未知 Model 键或 Array 命令历史。
## 恢复会先验证全部输入并保存 Model/历史基线，再应用 Model，最后提交并核对历史。
## validate 不写入；apply 或 commit 失败时会回滚全部已应用 Model 与命令历史。
## 恢复命令历史必须传入可实例化具体业务命令的 `command_builder`。
## [br]
## @api public
## [br]
## @since 3.0.0
## [br]
## @param data: 由 get_global_snapshot() 成功 Result 的 `snapshot` 字段。
## [br]
## @schema data: Inner snapshot Dictionary with the current format_version, models, and optional command_history fields; do not pass the outer capture Result.
## [br]
## @param command_builder: 【可选】如果需要恢复历史记录，必须传入用于反序列化具体 Command 实例的 Callable。
## [br]
## @return 原子恢复 Result；validate、apply 或 commit 失败时回滚全部 Model 与命令历史。
## `rolled_back` 表示失败前的已应用状态是否全部通过基线核对；
## validate 零写入失败固定为 false。
## [br]
## @schema return: Dictionary with ok: bool, phase: StringName, rolled_back: bool, and error: String.
func restore_global_snapshot(
	data: Dictionary,
	command_builder: Callable = Callable()
) -> Dictionary:
	return _snapshot_coordinator.restore_global_snapshot(data, command_builder)


## 分帧恢复整个框架的全局快照。
## 与同步版本使用相同的 validate/apply/commit 事务；Model 会分帧应用并逐项核对，
## 命令历史只在全部 Model 成功后提交。任一阶段失败都会回滚全部已应用状态。
## `models` 键集合必须与当前直接注册的 Model 精确匹配。
## [br]
## @api public
## [br]
## @since 5.0.0
## [br]
## @param data: 由 get_global_snapshot() 或 get_global_snapshot_async() 成功 Result 的 `snapshot` 字段。
## [br]
## @schema data: Inner snapshot Dictionary with the current format_version, models, and optional command_history fields; do not pass the outer capture Result.
## [br]
## @param command_builder: 【可选】如果需要恢复历史记录，必须传入用于反序列化具体 Command 实例的 Callable。
## [br]
## @param options: 可选参数，支持 max_models_per_frame；小于等于 0 时不主动让出帧。
## [br]
## @schema options: Dictionary，可包含 max_models_per_frame: int。
## [br]
## @return 原子恢复 Result；validate、apply 或 commit 失败时回滚全部 Model 与命令历史。
## `rolled_back` 表示失败前的已应用状态是否全部通过基线核对；
## validate 零写入失败固定为 false。
## [br]
## @schema return: Dictionary with ok: bool, phase: StringName, rolled_back: bool, and error: String.
func restore_global_snapshot_async(
	data: Dictionary,
	command_builder: Callable = Callable(),
	options: Dictionary = {}
) -> Dictionary:
	return await _snapshot_coordinator.restore_global_snapshot_async(data, command_builder, options)


## 获取架构模块生命周期诊断快照。
## [br]
## @api public
## [br]
## @return 包含 Model、System、Utility、Factory、Alias 与 Tick 缓存状态的字典。
## [br]
## @schema return: Dictionary containing lifecycle flags, registered module summaries, factory summaries, alias counts, and tick cache counts.
func get_debug_lifecycle_state() -> Dictionary:
	return {
		"lifecycle_state": _runtime.get_state_name(),
		"inited": _runtime.is_ready(),
		"is_initializing": _runtime.is_initializing(),
		"models": _collect_module_debug_state(_models),
		"systems": _collect_module_debug_state(_systems),
		"utilities": _collect_module_debug_state(_utilities),
		"factories": _collect_factory_debug_state(),
		"aliases": {
			"models": _model_registry.aliases.size(),
			"systems": _system_registry.aliases.size(),
			"utilities": _utility_registry.aliases.size(),
		},
		"tick": _tick_scheduler.get_debug_state(),
	}


## 获取架构绑定图诊断。
## 该报告只读取当前注册表、别名、工厂和父级链摘要，不触发依赖解析或生命周期推进。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param options: 可选参数，支持 include_entries、include_parent_chain 与 max_parent_depth。
## [br]
## @schema options: Dictionary with optional bool keys include_entries/include_parent_chain and int key max_parent_depth.
## [br]
## @return 绑定图诊断报告。
## [br]
## @schema return: Dictionary containing ok, registry counts, registry entries, factory bindings, parent_chain, parent_chain_cycle_detected, parent_chain_truncated, lifecycle flags, and issues.
func get_binding_diagnostics(options: Dictionary = {}) -> Dictionary:
	var include_entries: bool = _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(options, "include_entries", true)
	var include_parent_chain: bool = _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(options, "include_parent_chain", true)
	var max_parent_depth: int = maxi(_GF_VARIANT_ACCESS_SCRIPT.get_option_int(options, "max_parent_depth", 16), 0)
	var registries: Dictionary = {
		"models": _collect_binding_registry_diagnostics("model", _model_registry, true),
		"systems": _collect_binding_registry_diagnostics("system", _system_registry, true),
		"utilities": _collect_binding_registry_diagnostics("utility", _utility_registry, true),
	}
	var factories: Dictionary = _collect_binding_factory_diagnostics(true)
	var issues: Array[Dictionary] = []
	var parent_chain_report: Dictionary = _collect_parent_chain_report(max_parent_depth)
	var parent_chain_entries: Array = _GF_VARIANT_ACCESS_SCRIPT.as_array(
		_GF_VARIANT_ACCESS_SCRIPT.get_option_value(parent_chain_report, _PARENT_CHAIN_ENTRIES_KEY)
	)
	_append_binding_registry_issues(issues, registries)
	_append_binding_factory_issues(issues, factories)
	_append_parent_chain_issues(issues, parent_chain_report)
	if not include_entries:
		_strip_binding_diagnostic_entries(registries, factories)

	var result: Dictionary = {
		"ok": issues.is_empty(),
		"healthy": issues.is_empty(),
		"issue_count": issues.size(),
		"issues": issues,
		"lifecycle_generation": _runtime.get_lifecycle_generation(),
		"lifecycle_state": _runtime.get_state_name(),
		"inited": _runtime.is_ready(),
		"is_initializing": _runtime.is_initializing(),
		"disposed": _runtime.is_disposed(),
		"strict_dependency_lookup": strict_dependency_lookup,
		"registry_counts": {
			"models": _model_registry.instances.size(),
			"systems": _system_registry.instances.size(),
			"utilities": _utility_registry.instances.size(),
			"factories": _factories.size(),
			"aliases": _model_registry.aliases.size() + _system_registry.aliases.size() + _utility_registry.aliases.size(),
		},
		"registries": registries,
		"factories": factories,
		"parent_depth": parent_chain_entries.size(),
		"parent_chain_cycle_detected": _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(parent_chain_report, _PARENT_CHAIN_CYCLE_DETECTED_KEY, false),
		"parent_chain_truncated": _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(parent_chain_report, _PARENT_CHAIN_TRUNCATED_KEY, false),
	}
	if include_parent_chain:
		result["parent_chain"] = parent_chain_entries
	return result


## 获取架构中已注册模块的声明式依赖诊断报告。
## 模块通过 get_required_models/systems/utilities/factories() 分别声明依赖。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @return 统一诊断报告字典。
## [br]
## @schema return: Dictionary dependency diagnostics report with modules, resolved_dependencies, missing_dependencies, parent-chain cycle issue records, issue counts, and next_action.
func get_dependency_diagnostics() -> Dictionary:
	var plan: GFArchitectureLifecyclePlan = _active_lifecycle_plan
	if plan == null:
		plan = _lifecycle_plan_in_progress
	if plan == null:
		plan = _build_candidate_lifecycle_plan_snapshot(
			_models,
			_utilities,
			_systems
		)
	return _build_dependency_diagnostics_from_plan(plan)


# --- 可重写钩子 / 虚方法 ---

## 内部初始化回调，子类可重写。
## [br]
## @api protected
func _on_init() -> void:
	pass


## 内部销毁回调，子类可重写。
## [br]
## @api protected
func _on_dispose() -> void:
	pass


# --- 框架内部方法 ---

## 登记一个由框架启动入口拥有、需要随架构失败或 dispose 一并取消的异步作用域。
## [br]
## @api framework_internal
## [br]
## @layer kernel/core
## [br]
## @param scope: 要登记的框架异步作用域。
func track_framework_async_scope(scope: GFAsyncScope) -> void:
	_track_async_scope(scope)


## 注销一个已经结束或已由框架启动入口接管清理的异步作用域。
## [br]
## @api framework_internal
## [br]
## @layer kernel/core
## [br]
## @param scope: 要注销的框架异步作用域。
func untrack_framework_async_scope(scope: GFAsyncScope) -> void:
	_untrack_async_scope(scope)


## 返回 required binding plan 是否仍可修改候选架构注册拓扑。
## [br]
## @api framework_internal
## [br]
## @since 11.0.0
## [br]
## @return 架构尚未 ready/init/activation/failure/quiesce/dispose 且没有冲突事务时返回 true。
func can_accept_required_binding_plan_for_framework() -> bool:
	if _runtime.is_ready():
		return false
	return _can_mutate_registration_state("execute_required_binding_plan")


## 在同一个 disposal claim session 内执行一次 required lifecycle binding attempt。
## [br]
## @api framework_internal
## [br]
## @since 11.0.0
## [br]
## @param attempt: 同步创建、校验并注册 candidate 的内部回调。
## [br]
## @return 回调的原始终态；Callable 无效时返回 null。
## [br]
## @schema return: Variant returned by the synchronous required binding attempt; null when the Callable is invalid.
func run_required_binding_attempt_for_framework(attempt: Callable) -> Variant:
	if not attempt.is_valid():
		return null
	var _disposal_claims: Dictionary = _begin_module_disposal_session()
	var attempt_result: Variant = attempt.call()
	_end_module_disposal_session()
	return attempt_result


## 为 required binding plan 注册 Model 查询别名并返回精确结果。
## [br]
## @api framework_internal
## [br]
## @since 11.0.0
## [br]
## @param alias_cls: 查询别名脚本。
## [br]
## @param target_cls: 已注册 Model 的实际脚本。
## [br]
## @return 别名写入成功时返回 true。
func register_model_alias_for_framework(alias_cls: Script, target_cls: Script) -> bool:
	return _register_required_plan_alias(_model_registry, alias_cls, target_cls)


## 为 required binding plan 注册 System 查询别名并返回精确结果。
## [br]
## @api framework_internal
## [br]
## @since 11.0.0
## [br]
## @param alias_cls: 查询别名脚本。
## [br]
## @param target_cls: 已注册 System 的实际脚本。
## [br]
## @return 别名写入成功时返回 true。
func register_system_alias_for_framework(alias_cls: Script, target_cls: Script) -> bool:
	return _register_required_plan_alias(_system_registry, alias_cls, target_cls)


## 为 required binding plan 注册 Utility 查询别名并返回精确结果。
## [br]
## @api framework_internal
## [br]
## @since 11.0.0
## [br]
## @param alias_cls: 查询别名脚本。
## [br]
## @param target_cls: 已注册 Utility 的实际脚本。
## [br]
## @return 别名写入成功时返回 true。
func register_utility_alias_for_framework(alias_cls: Script, target_cls: Script) -> bool:
	return _register_required_plan_alias(_utility_registry, alias_cls, target_cls)


## 为 required binding plan 注册 Model candidate，并由 Architecture 精确结算拒绝所有权。
## [br]
## @api framework_internal
## [br]
## @since 11.0.0
## [br]
## @param script_cls: Plan 声明并冻结的 Model 注册键。
## [br]
## @param instance: 要注册的 Model candidate。
## [br]
## @param release_owned_candidate_on_rejection: 为 true 时，Architecture 会且只会释放仍由调用方拥有的拒绝 candidate。
## [br]
## @return OK 表示 candidate 已由 Architecture 拥有；ERR_INVALID_DATA 表示 candidate
## 无效或不匹配声明目标；其它错误表示注册被拒绝。
func register_model_instance_for_required_plan_for_framework(
	script_cls: Script,
	instance: Object,
	release_owned_candidate_on_rejection: bool
) -> Error:
	return _register_required_plan_module(
		_model_registry,
		script_cls,
		instance,
		release_owned_candidate_on_rejection
	)


## 为 required binding plan 注册 System candidate，并由 Architecture 精确结算拒绝所有权。
## [br]
## @api framework_internal
## [br]
## @since 11.0.0
## [br]
## @param script_cls: Plan 声明并冻结的 System 注册键。
## [br]
## @param instance: 要注册的 System candidate。
## [br]
## @param release_owned_candidate_on_rejection: 为 true 时，Architecture 会且只会释放仍由调用方拥有的拒绝 candidate。
## [br]
## @return OK 表示 candidate 已由 Architecture 拥有；ERR_INVALID_DATA 表示 candidate
## 无效或不匹配声明目标；其它错误表示注册被拒绝。
func register_system_instance_for_required_plan_for_framework(
	script_cls: Script,
	instance: Object,
	release_owned_candidate_on_rejection: bool
) -> Error:
	var registration_error: Error = _register_required_plan_module(
		_system_registry,
		script_cls,
		instance,
		release_owned_candidate_on_rejection
	)
	if registration_error == OK:
		_refresh_tick_caches()
	return registration_error


## 为 required binding plan 注册 Utility candidate，并由 Architecture 精确结算拒绝所有权。
## [br]
## @api framework_internal
## [br]
## @since 11.0.0
## [br]
## @param script_cls: Plan 声明并冻结的 Utility 注册键。
## [br]
## @param instance: 要注册的 Utility candidate。
## [br]
## @param release_owned_candidate_on_rejection: 为 true 时，Architecture 会且只会释放仍由调用方拥有的拒绝 candidate。
## [br]
## @return OK 表示 candidate 已由 Architecture 拥有；ERR_INVALID_DATA 表示 candidate
## 无效或不匹配声明目标；其它错误表示注册被拒绝。
func register_utility_instance_for_required_plan_for_framework(
	script_cls: Script,
	instance: Object,
	release_owned_candidate_on_rejection: bool
) -> Error:
	var registration_error: Error = _register_required_plan_module(
		_utility_registry,
		script_cls,
		instance,
		release_owned_candidate_on_rejection
	)
	if registration_error == OK:
		_refresh_cached_utility_refs()
		_refresh_tick_caches()
	return registration_error


# --- 私有/辅助方法 ---

func _await_existing_initialization(
	waiting_serial: int,
	cancellation_token: GFCancellationToken
) -> bool:
	if not _runtime.is_generation_current(waiting_serial):
		return false
	if cancellation_token != null and cancellation_token.is_cancel_requested():
		return false

	var wait_completion: GFAsyncCompletion = GFAsyncCompletion.new()
	var initialization_callback: Callable = Callable(
		wait_completion,
		&"succeed"
	)
	var connect_error: Error = initialization_finished.connect(
		initialization_callback,
		CONNECT_ONE_SHOT as Object.ConnectFlags
	) as Error
	if connect_error != OK:
		return false
	if (
		cancellation_token != null
		and not wait_completion.bind_cancel_token(cancellation_token)
	):
		if initialization_finished.is_connected(initialization_callback):
			initialization_finished.disconnect(initialization_callback)
		return false
	if wait_completion.is_pending():
		await wait_completion.completed
	if initialization_finished.is_connected(initialization_callback):
		initialization_finished.disconnect(initialization_callback)
	return (
		wait_completion.is_successful()
		and _runtime.is_ready()
		and _runtime.is_generation_current(waiting_serial)
	)


func _build_dependency_diagnostics_from_plan(
	plan: GFArchitectureLifecyclePlan
) -> Dictionary:
	var report: DependencyDiagnosticsReport = DependencyDiagnosticsReport.new(
		"Architecture dependencies"
	)
	var modules: Array[Dictionary] = []
	var modules_by_key: Dictionary = {}
	var resolved_dependencies: Array[Dictionary] = []
	var missing_dependencies: Array[Dictionary] = []
	if plan == null:
		var _missing_plan_issue: Dictionary = report.add_error(
			&"missing_lifecycle_plan",
			"Architecture dependency diagnostics could not build a lifecycle plan."
		)
		return report.to_dict(
			{
				"module_count": 0,
				"modules": modules,
				"resolved_dependencies": resolved_dependencies,
				"missing_dependencies": missing_dependencies,
			},
			_get_dependency_diagnostics_report_options()
		)

	for snapshot: Dictionary in plan.get_dependency_snapshot():
		var module_key: String = _GF_VARIANT_ACCESS_SCRIPT.get_option_string(
			snapshot,
			"module_key"
		)
		var module_script: Script = _get_dictionary_script(
			snapshot,
			"module_script"
		)
		var module_instance: Object = _get_dictionary_object(
			snapshot,
			"module_instance"
		)
		var dependency_map: Dictionary = (
			_GF_VARIANT_ACCESS_SCRIPT.get_option_dictionary(
				snapshot,
				"dependencies"
			)
		)
		var module_record: Dictionary = {
			"kind": _GF_VARIANT_ACCESS_SCRIPT.get_option_string(
				snapshot,
				"module_kind"
			),
			"module_key": module_key,
			"script": _get_script_debug_key(
				module_script,
				module_instance
			),
			"instance": _get_instance_debug_key(module_instance),
			"dependencies": _dependency_map_to_keys(dependency_map),
			"resolved_dependencies": [],
			"missing_dependencies": [],
		}
		modules.append(module_record)
		modules_by_key[module_key] = module_record

	for source_record: Dictionary in plan.get_dependency_records():
		var dependency_record: Dictionary = (
			_make_plan_dependency_diagnostic_record(source_record)
		)
		var module_key: String = _GF_VARIANT_ACCESS_SCRIPT.get_option_string(
			source_record,
			"module_key"
		)
		var module_record: Dictionary = (
			_GF_VARIANT_ACCESS_SCRIPT.get_option_dictionary(
				modules_by_key,
				module_key
			)
		)
		if _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(
			dependency_record,
			"resolved"
		):
			resolved_dependencies.append(dependency_record)
			if not module_record.is_empty():
				var module_resolved: Array = (
					_GF_VARIANT_ACCESS_SCRIPT.get_option_array(
						module_record,
						"resolved_dependencies"
					)
				)
				module_resolved.append(dependency_record)
		else:
			missing_dependencies.append(dependency_record)
			if not module_record.is_empty():
				var module_missing: Array = (
					_GF_VARIANT_ACCESS_SCRIPT.get_option_array(
						module_record,
						"missing_dependencies"
					)
				)
				module_missing.append(dependency_record)

	for diagnostic: Dictionary in plan.get_diagnostics():
		_append_lifecycle_plan_dependency_issue(report, diagnostic)

	return report.to_dict(
		{
			"module_count": modules.size(),
			"modules": modules,
			"resolved_dependencies": resolved_dependencies,
			"missing_dependencies": missing_dependencies,
			"diagnostics_truncated": plan.were_diagnostics_truncated(),
		},
		_get_dependency_diagnostics_report_options()
	)


func _make_plan_dependency_diagnostic_record(
	source: Dictionary
) -> Dictionary:
	var status: String = _GF_VARIANT_ACCESS_SCRIPT.get_option_string(
		source,
		"status",
		"invalid"
	)
	var scope: String = _GF_VARIANT_ACCESS_SCRIPT.get_option_string(
		source,
		"scope",
		"missing"
	)
	if status == "parent_cycle":
		scope = "parent_cycle"
	var dependency_script: Script = _get_dictionary_script(
		source,
		"dependency_script"
	)
	var resolved_instance: Object = _get_dictionary_object(
		source,
		"resolved_instance"
	)
	var registered_script: Script = _get_dictionary_script(
		source,
		"registered_script"
	)
	return {
		"module_kind": _GF_VARIANT_ACCESS_SCRIPT.get_option_string(
			source,
			"module_kind"
		),
		"module": _GF_VARIANT_ACCESS_SCRIPT.get_option_string(
			source,
			"module_key"
		),
		"kind": _GF_VARIANT_ACCESS_SCRIPT.get_option_string(
			source,
			"dependency_kind"
		),
		"script": _get_script_debug_key(dependency_script),
		"resolved": _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(
			source,
			"resolved"
		),
		"status": status,
		"scope": scope,
		"resolved_instance": _get_instance_debug_key(resolved_instance),
		"architecture_depth": _GF_VARIANT_ACCESS_SCRIPT.get_option_int(
			source,
			"architecture_depth",
			-1
		),
		"resolution_kind": _GF_VARIANT_ACCESS_SCRIPT.get_option_string(
			source,
			"resolution_kind"
		),
		"registered_script": _get_script_debug_key(registered_script),
		"parent_chain_cycle_detected": (
			_GF_VARIANT_ACCESS_SCRIPT.get_option_bool(
				source,
				"parent_chain_cycle_detected"
			)
		),
		"cycle_architecture": _GF_VARIANT_ACCESS_SCRIPT.get_option_string(
			source,
			"cycle_architecture"
		),
		"cycle_depth": _GF_VARIANT_ACCESS_SCRIPT.get_option_int(
			source,
			"cycle_depth",
			-1
		),
		"cycle_start_depth": _GF_VARIANT_ACCESS_SCRIPT.get_option_int(
			source,
			"cycle_start_depth",
			-1
		),
		"reason": _GF_VARIANT_ACCESS_SCRIPT.get_option_string(
			source,
			"reason"
		),
	}


func _append_lifecycle_plan_dependency_issue(
	report: DependencyDiagnosticsReport,
	diagnostic: Dictionary
) -> void:
	var source_code: String = _GF_VARIANT_ACCESS_SCRIPT.get_option_string(
		diagnostic,
		"code",
		"invalid_dependency_resolution"
	)
	var dependency_kind: String = (
		_GF_VARIANT_ACCESS_SCRIPT.get_option_string(
			diagnostic,
			"dependency_kind"
		)
	)
	var public_code: StringName = StringName(source_code)
	if source_code == "missing_dependency":
		public_code = StringName(
			"missing_%s_dependency" % _dependency_kind_to_singular(
				dependency_kind
			)
		)
	elif source_code == "parent_dependency_cycle":
		public_code = &"dependency_parent_chain_cycle"
	var metadata: Dictionary = diagnostic.duplicate(true)
	for field_name: String in [
		"code",
		"severity",
		"module_key",
		"dependency_key",
		"message",
	]:
		var _removed_field: bool = metadata.erase(field_name)
	var _issue: Dictionary = report.add_error(
		public_code,
		_GF_VARIANT_ACCESS_SCRIPT.get_option_string(
			diagnostic,
			"message",
			"Architecture lifecycle dependency plan is invalid."
		),
		_GF_VARIANT_ACCESS_SCRIPT.get_option_string(
			diagnostic,
			"module_key"
		),
		_GF_VARIANT_ACCESS_SCRIPT.get_option_string(
			diagnostic,
			"dependency_key"
		),
		metadata
	)


func _get_dependency_diagnostics_report_options() -> Dictionary:
	return {
		"include_subject": false,
		"include_metadata": false,
		"include_info_count": false,
		"include_issue_count": false,
		"next_actions": _get_dependency_diagnostics_next_actions(),
		"fallback_action": (
			"Review the first reported architecture dependency issue."
		),
	}


func _get_dependency_script_array(
	dependencies: Dictionary,
	dependency_kind: String
) -> Array:
	var raw_value: Variant = _GF_VARIANT_ACCESS_SCRIPT.get_option_value(
		dependencies,
		dependency_kind,
		[]
	)
	if raw_value is Array:
		var dependency_scripts: Array = raw_value
		return dependency_scripts
	return []


func _variant_to_object(value: Variant) -> Object:
	if value is Object:
		var object_value: Object = value
		return object_value
	return null


func _variant_to_binding(value: Variant) -> GFBinding:
	if value is GFBinding:
		var binding: GFBinding = value
		return binding
	return null


func _variant_to_dictionary(value: Variant) -> Dictionary:
	if value is Dictionary:
		var dictionary_value: Dictionary = value
		return dictionary_value
	return {}


func _variant_to_script(value: Variant) -> Script:
	if value is Script:
		var script_value: Script = value
		return script_value
	return null


func _get_dictionary_object(source: Dictionary, field_name: Variant) -> Object:
	return _variant_to_object(_GF_VARIANT_ACCESS_SCRIPT.get_option_value(source, field_name))


func _get_dictionary_binding(source: Dictionary, field_name: Variant) -> GFBinding:
	return _variant_to_binding(_GF_VARIANT_ACCESS_SCRIPT.get_option_value(source, field_name))


func _get_dictionary_script(source: Dictionary, field_name: Variant) -> Script:
	return _variant_to_script(_GF_VARIANT_ACCESS_SCRIPT.get_option_value(source, field_name))


func _get_object_int_property(instance: Object, property_name: StringName, default_value: int) -> int:
	return _GF_VARIANT_ACCESS_SCRIPT.to_int(_get_object_property(instance, property_name, default_value), default_value)


func _get_object_bool_property(instance: Object, property_name: StringName, default_value: bool = false) -> bool:
	return _GF_VARIANT_ACCESS_SCRIPT.to_bool(_get_object_property(instance, property_name, default_value), default_value)


func _get_object_property(instance: Object, property_name: StringName, default_value: Variant = null) -> Variant:
	if instance == null:
		return default_value
	if not String(property_name) in instance:
		return default_value
	return instance.get_indexed(NodePath(String(property_name)))


func _get_instance_script(instance: Object) -> Script:
	if instance == null:
		return null
	var raw_script: Variant = instance.get_script()
	return _variant_to_script(raw_script)


func _get_scene_tree_or_null() -> SceneTree:
	var main_loop: Variant = Engine.get_main_loop()
	if main_loop is SceneTree:
		var scene_tree: SceneTree = main_loop
		return scene_tree
	return null


func _dependency_map_to_keys(dependencies: Dictionary) -> Dictionary:
	return {
		"models": _script_array_to_debug_keys(_get_dependency_script_array(dependencies, "models")),
		"systems": _script_array_to_debug_keys(_get_dependency_script_array(dependencies, "systems")),
		"utilities": _script_array_to_debug_keys(_get_dependency_script_array(dependencies, "utilities")),
		"factories": _script_array_to_debug_keys(_get_dependency_script_array(dependencies, "factories")),
	}


func _script_array_to_debug_keys(scripts: Array) -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	for script_variant: Variant in scripts:
		if not script_variant is Script:
			continue
		var script: Script = script_variant
		_append_packed_string(result, _get_script_debug_key(script))
	result.sort()
	return result


func _append_packed_string(target: PackedStringArray, value: String) -> void:
	var _added: bool = target.append(value)


func _call_module_void(instance: Object, method_name: StringName, arguments: Array = []) -> void:
	if instance == null or not instance.has_method(method_name):
		return
	var _result: Variant = instance.callv(method_name, arguments)


func _call_module_init(instance: Object) -> void:
	_lifecycle_hook_depth += 1
	if instance is GFModel:
		var model: GFModel = instance
		model.init()
	elif instance is GFSystem:
		var system: GFSystem = instance
		system.init()
	elif instance is GFUtility:
		var utility: GFUtility = instance
		utility.init()
	_lifecycle_hook_depth -= 1


func _call_module_async_init(instance: Object, async_scope: GFAsyncScope) -> void:
	var async_init_callback: Callable = Callable()
	if instance is GFModel:
		var model: GFModel = instance
		async_init_callback = Callable(model, &"async_init")
	elif instance is GFSystem:
		var system: GFSystem = instance
		async_init_callback = Callable(system, &"async_init")
	elif instance is GFUtility:
		var utility: GFUtility = instance
		async_init_callback = Callable(utility, &"async_init")
	if async_init_callback.is_valid():
		_lifecycle_hook_depth += 1
		await async_init_callback.call(async_scope)
		_lifecycle_hook_depth -= 1


func _call_module_ready(instance: Object) -> void:
	_lifecycle_hook_depth += 1
	if instance is GFModel:
		var model: GFModel = instance
		model.ready()
	elif instance is GFSystem:
		var system: GFSystem = instance
		system.ready()
	elif instance is GFUtility:
		var utility: GFUtility = instance
		utility.ready()
	_lifecycle_hook_depth -= 1


func _call_module_begin_activation(
	instance: Object,
	scope: GFAsyncScope
) -> GFAsyncCompletion:
	_lifecycle_hook_depth += 1
	var completion: GFAsyncCompletion = null
	if instance is GFModel:
		var model: GFModel = instance
		completion = model.begin_activation(scope)
	elif instance is GFSystem:
		var system: GFSystem = instance
		completion = system.begin_activation(scope)
	elif instance is GFUtility:
		var utility: GFUtility = instance
		completion = utility.begin_activation(scope)
	_lifecycle_hook_depth -= 1
	return completion


func _call_module_begin_quiesce(
	instance: Object,
	scope: GFAsyncScope
) -> GFAsyncCompletion:
	_lifecycle_hook_depth += 1
	var completion: GFAsyncCompletion = null
	if instance is GFModel:
		var model: GFModel = instance
		completion = model.begin_quiesce(scope)
	elif instance is GFSystem:
		var system: GFSystem = instance
		completion = system.begin_quiesce(scope)
	elif instance is GFUtility:
		var utility: GFUtility = instance
		completion = utility.begin_quiesce(scope)
	_lifecycle_hook_depth -= 1
	return completion


func _call_module_dispose(instance: Object) -> void:
	_lifecycle_hook_depth += 1
	if instance is GFModel:
		var model: GFModel = instance
		model.dispose()
	elif instance is GFSystem:
		var system: GFSystem = instance
		system.dispose()
	elif instance is GFUtility:
		var utility: GFUtility = instance
		utility.dispose()
	_lifecycle_hook_depth -= 1


func _call_module_release_dependencies(instance: Object) -> void:
	if instance is GFModel:
		var model: GFModel = instance
		model.release_dependencies()
	elif instance is GFSystem:
		var system: GFSystem = instance
		system.release_dependencies()
	elif instance is GFUtility:
		var utility: GFUtility = instance
		utility.release_dependencies()


func _get_registered_instance_with_parent_lookup(
	registry_kind: String,
	script_cls: Script,
	require_ready: bool,
	report_strict_miss: bool = true
) -> Object:
	var current: GFArchitecture = self
	var visited: Dictionary = _create_parent_lookup_visited()
	while current != null:
		var module_registry: ModuleRegistry = current._get_module_registry_by_kind(registry_kind)
		if module_registry == null:
			return null
		var instance: Object = current._get_local_registered_instance(module_registry, script_cls)
		if instance != null:
			return instance if not require_ready or current._is_module_ready_for_lookup(instance) else null
		if current.strict_dependency_lookup:
			if report_strict_miss:
				current._report_strict_lookup_miss(
					script_cls,
					module_registry.label
				)
			return null
		if not current._should_fallback_after_local_module_miss(module_registry, script_cls):
			return null
		current = _get_next_parent_for_lookup(current, visited, "get_%s" % module_registry._label_key())
	return null


func _get_module_registry_by_kind(registry_kind: String) -> ModuleRegistry:
	match registry_kind:
		"model", "models":
			return _model_registry
		"system", "systems":
			return _system_registry
		"utility", "utilities":
			return _utility_registry
		_:
			return null


func _get_module_registry_for_access_kind(module_kind: ModuleKind) -> ModuleRegistry:
	match module_kind:
		ModuleKind.MODEL:
			return _model_registry
		ModuleKind.SYSTEM:
			return _system_registry
		ModuleKind.UTILITY:
			return _utility_registry
		_:
			return null


func _should_fallback_after_local_module_miss(module_registry: ModuleRegistry, script_cls: Script) -> bool:
	if _has_unresolved_alias(module_registry, script_cls):
		return false
	return not _has_assignable_instance(module_registry, script_cls)


func _create_parent_lookup_visited() -> Dictionary:
	return {
		get_instance_id(): 0,
		"depth": 0,
		_PARENT_CHAIN_CYCLE_DETECTED_KEY: false,
	}


func _get_next_parent_for_lookup(
	current: GFArchitecture,
	visited: Dictionary,
	context: String,
	report_cycle_error: bool = true
) -> GFArchitecture:
	if current == null or current.strict_dependency_lookup:
		return null
	var parent: GFArchitecture = current._parent_architecture
	if parent == null:
		return null
	var next_depth: int = _GF_VARIANT_ACCESS_SCRIPT.get_option_int(visited, "depth", 0) + 1
	if _parent_lookup_visited_has_architecture(visited, parent):
		_record_parent_lookup_cycle(visited, parent, next_depth)
		if report_cycle_error:
			_report_parent_lookup_cycle(context, parent)
		return null
	visited[parent.get_instance_id()] = next_depth
	visited["depth"] = next_depth
	return parent


func _parent_lookup_visited_has_architecture(visited: Dictionary, architecture: GFArchitecture) -> bool:
	return architecture != null and visited.has(architecture.get_instance_id())


func _record_parent_lookup_cycle(
	visited: Dictionary,
	cycle_architecture: GFArchitecture,
	cycle_depth: int
) -> void:
	if cycle_architecture == null:
		return
	if _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(visited, _PARENT_CHAIN_CYCLE_DETECTED_KEY, false):
		return
	var cycle_instance_id: int = cycle_architecture.get_instance_id()
	visited[_PARENT_CHAIN_CYCLE_DETECTED_KEY] = true
	visited[_PARENT_CHAIN_CYCLE_ARCHITECTURE_KEY] = _get_architecture_debug_key(cycle_architecture)
	visited[_PARENT_CHAIN_CYCLE_DEPTH_KEY] = cycle_depth
	visited[_PARENT_CHAIN_CYCLE_START_DEPTH_KEY] = _get_parent_lookup_visited_depth(visited, cycle_instance_id)


func _get_parent_lookup_visited_depth(visited: Dictionary, architecture_instance_id: int) -> int:
	if not visited.has(architecture_instance_id):
		return -1
	var raw_depth: Variant = visited[architecture_instance_id]
	if raw_depth is int:
		var depth: int = raw_depth
		return depth
	return -1


func _has_parent_lookup_cycle(visited: Dictionary) -> bool:
	return _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(visited, _PARENT_CHAIN_CYCLE_DETECTED_KEY, false)


func _make_parent_lookup_cycle_status(visited: Dictionary, architecture_depth: int) -> Dictionary:
	return {
		"resolved": false,
		"scope": "parent_cycle",
		"architecture_depth": architecture_depth,
		_PARENT_CHAIN_CYCLE_DETECTED_KEY: true,
		_PARENT_CHAIN_CYCLE_ARCHITECTURE_KEY: _GF_VARIANT_ACCESS_SCRIPT.get_option_string(visited, _PARENT_CHAIN_CYCLE_ARCHITECTURE_KEY, ""),
		_PARENT_CHAIN_CYCLE_DEPTH_KEY: _GF_VARIANT_ACCESS_SCRIPT.get_option_int(visited, _PARENT_CHAIN_CYCLE_DEPTH_KEY, -1),
		_PARENT_CHAIN_CYCLE_START_DEPTH_KEY: _GF_VARIANT_ACCESS_SCRIPT.get_option_int(visited, _PARENT_CHAIN_CYCLE_START_DEPTH_KEY, -1),
	}


func _report_parent_lookup_cycle(context: String, cycle_architecture: GFArchitecture) -> void:
	push_error("[GFArchitecture] %s 失败：父级架构链存在循环引用：%s。" % [
		context,
		_get_architecture_debug_key(cycle_architecture),
	])


func _get_architecture_debug_key(architecture: GFArchitecture) -> String:
	if architecture == null:
		return ""
	return "GFArchitecture:%d" % architecture.get_instance_id()


func _dependency_kind_to_singular(dependency_kind: String) -> String:
	match dependency_kind:
		"models":
			return "model"
		"systems":
			return "system"
		"utilities":
			return "utility"
		"factories":
			return "factory"
		_:
			return "dependency"


func _get_dependency_diagnostics_next_actions() -> Dictionary:
	return {
		"missing_model_dependency": "Register the required Model locally or in an allowed parent architecture.",
		"missing_system_dependency": "Register the required System locally or in an allowed parent architecture.",
		"missing_utility_dependency": "Register the required Utility locally or in an allowed parent architecture.",
		"missing_factory_dependency": "Register the required factory before the dependent module requests it.",
		"stale_alias_dependency": "Repair or remove the stale local alias before resolving the dependency.",
		"ambiguous_dependency": "Register an explicit alias that selects one local implementation.",
		"dependency_parent_chain_cycle": "Repair the architecture parent chain before compiling lifecycle dependencies.",
		"dependency_cycle": "Remove the local lifecycle dependency cycle.",
		"invalid_dependency_hook_return": "Return Array[Script] from the typed dependency hook.",
		"invalid_dependency_type": "Declared dependencies should contain only Script values.",
		"invalid_dependency_resolution": "Repair the dependency resolver contract before initialization.",
	}


func _reset_project_installers() -> void:
	var was_running: bool = _project_installers_running
	_project_installers_applied = false
	_project_installers_running = false
	if was_running:
		project_installers_finished.emit()


func _assign_parent_architecture(parent_architecture: GFArchitecture, context: String) -> void:
	if _runtime.get_state() not in [
		GFKernelRuntime.LifecycleState.NEW,
		GFKernelRuntime.LifecycleState.FAILED,
	]:
		push_error(
			"[GFArchitecture] %s 失败：生命周期计划开始后父级架构关系不可变。" % (
				context
			)
		)
		return
	if parent_architecture == null:
		_parent_architecture = null
		return
	if parent_architecture == self:
		push_error("[GFArchitecture] %s 失败：父级架构不能是自身。" % context)
		return
	if _parent_chain_contains(parent_architecture, self):
		push_error("[GFArchitecture] %s 失败：父级架构会形成循环引用。" % context)
		return
	_parent_architecture = parent_architecture


func _parent_chain_contains(parent_architecture: GFArchitecture, expected: GFArchitecture) -> bool:
	var visited: Dictionary = {}
	var current: GFArchitecture = parent_architecture
	while current != null:
		if current == expected:
			return true
		var instance_id: int = current.get_instance_id()
		if visited.has(instance_id):
			return false
		visited[instance_id] = true
		current = current.get_parent_architecture()
	return false


func _get_modules_by_lifecycle_priority(registry: Dictionary, reverse: bool = false) -> Array[Object]:
	var entries: Array[Dictionary] = []
	var order: int = 0
	for instance: Object in registry.values():
		entries.append({
			"instance": instance,
			"priority": _get_module_priority(instance, &"lifecycle_priority"),
			"order": order,
		})
		order += 1

	entries.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		var left_priority: int = _GF_VARIANT_ACCESS_SCRIPT.get_option_int(left, "priority", 0)
		var right_priority: int = _GF_VARIANT_ACCESS_SCRIPT.get_option_int(right, "priority", 0)
		if left_priority == right_priority:
			var left_order: int = _GF_VARIANT_ACCESS_SCRIPT.get_option_int(left, "order", 0)
			var right_order: int = _GF_VARIANT_ACCESS_SCRIPT.get_option_int(right, "order", 0)
			return left_order > right_order if reverse else left_order < right_order
		return left_priority < right_priority if reverse else left_priority > right_priority
	)

	var result: Array[Object] = []
	for entry: Dictionary in entries:
		var instance: Object = _get_dictionary_object(entry, "instance")
		if instance != null:
			result.append(instance)
	return result


func _get_module_priority(instance: Object, property_name: StringName) -> int:
	if instance == null:
		return 0
	match property_name:
		&"lifecycle_priority":
			return _get_lifecycle_priority(instance)
		_:
			return 0


func _get_lifecycle_priority(instance: Object) -> int:
	if instance is GFModel:
		var model: GFModel = instance
		return model.lifecycle_priority
	if instance is GFSystem:
		var system: GFSystem = instance
		return system.lifecycle_priority
	if instance is GFUtility:
		var utility: GFUtility = instance
		return utility.lifecycle_priority
	return 0


func _collect_module_debug_state(registry: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for script_cls: Script in registry.keys():
		var instance: Object = _get_dictionary_object(registry, script_cls)
		var stage: int = _GF_VARIANT_ACCESS_SCRIPT.get_option_int(_module_lifecycle_stages, instance, 0)
		var module_state: Dictionary = {
			"stage": stage,
			"stage_name": _get_lifecycle_stage_name(stage),
			"ready": stage >= 3,
			"active": stage >= 4,
			"lifecycle_priority": _get_module_priority(instance, &"lifecycle_priority"),
		}
		module_state.merge(_tick_scheduler.get_module_debug_fields(instance), true)
		result[_get_script_debug_key(script_cls, instance)] = module_state
	return result


func _collect_binding_registry_diagnostics(
	module_kind: String,
	module_registry: ModuleRegistry,
	include_entries: bool
) -> Dictionary:
	var result: Dictionary = {
		"kind": module_kind,
		"label": module_registry.label,
		"registered_count": module_registry.instances.size(),
		"alias_count": module_registry.aliases.size(),
		"assignable_cache_count": module_registry.assignable_cache.size(),
		"instance_key_count": module_registry.instance_keys.size(),
		"invalid_alias_count": 0,
	}
	if not include_entries:
		return result

	var entries: Array[Dictionary] = []
	for script_cls: Script in module_registry.instances.keys():
		var instance: Object = _get_dictionary_object(module_registry.instances, script_cls)
		var stage: int = _GF_VARIANT_ACCESS_SCRIPT.get_option_int(_module_lifecycle_stages, instance, 0)
		entries.append({
			"script": _get_script_debug_key(script_cls, instance),
			"instance": _get_instance_debug_key(instance),
			"valid": instance != null,
			"stage": stage,
			"stage_name": _get_lifecycle_stage_name(stage),
			"ready": stage >= 3,
		})

	var aliases: Array[Dictionary] = []
	var invalid_alias_count: int = 0
	for alias_cls: Script in module_registry.aliases.keys():
		var target_cls: Script = _get_dictionary_script(module_registry.aliases, alias_cls)
		var target_registered: bool = target_cls != null and module_registry.instances.has(target_cls)
		if not target_registered:
			invalid_alias_count += 1
		aliases.append({
			"alias": _get_script_debug_key(alias_cls),
			"target": _get_script_debug_key(target_cls),
			"target_registered": target_registered,
		})

	var assignable_cache: Array[Dictionary] = []
	for request_cls: Script in module_registry.assignable_cache.keys():
		var resolved_cls: Script = _get_dictionary_script(module_registry.assignable_cache, request_cls)
		assignable_cache.append({
			"request": _get_script_debug_key(request_cls),
			"resolved": _get_script_debug_key(resolved_cls),
			"resolved_registered": resolved_cls != null and module_registry.instances.has(resolved_cls),
		})

	result["invalid_alias_count"] = invalid_alias_count
	result["entries"] = entries
	result["aliases"] = aliases
	result["assignable_cache"] = assignable_cache
	return result


func _collect_binding_factory_diagnostics(include_entries: bool) -> Dictionary:
	var result: Dictionary = {
		"count": _factories.size(),
		"invalid_count": 0,
	}
	if not include_entries:
		return result

	var entries: Array[Dictionary] = []
	var invalid_count: int = 0
	for script_cls: Script in _factories.keys():
		var binding: Object = _get_dictionary_object(_factories, script_cls)
		var lifetime: int = -1
		if binding != null and "lifetime" in binding:
			lifetime = _get_object_int_property(binding, &"lifetime", -1)
		if binding == null:
			invalid_count += 1
		entries.append({
			"script": _get_script_debug_key(script_cls),
			"valid": binding != null,
			"lifetime": lifetime,
			"lifetime_name": _get_binding_lifetime_name(lifetime),
		})
	result["invalid_count"] = invalid_count
	result["entries"] = entries
	return result


func _append_binding_registry_issues(issues: Array[Dictionary], registries: Dictionary) -> void:
	for registry_key: Variant in registries.keys():
		var registry: Dictionary = _GF_VARIANT_ACCESS_SCRIPT.as_dictionary(registries[registry_key])
		for alias_variant: Variant in _GF_VARIANT_ACCESS_SCRIPT.get_option_array(registry, "aliases"):
			var alias: Dictionary = _GF_VARIANT_ACCESS_SCRIPT.as_dictionary(alias_variant)
			if _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(alias, "target_registered", false):
				continue
			issues.append({
				"kind": "invalid_alias",
				"severity": "error",
				"registry": str(registry_key),
				"alias": _GF_VARIANT_ACCESS_SCRIPT.get_option_string(alias, "alias"),
				"target": _GF_VARIANT_ACCESS_SCRIPT.get_option_string(alias, "target"),
				"message": "Alias target is not registered.",
			})


func _append_binding_factory_issues(issues: Array[Dictionary], factories: Dictionary) -> void:
	for entry_variant: Variant in _GF_VARIANT_ACCESS_SCRIPT.get_option_array(factories, "entries"):
		var entry: Dictionary = _GF_VARIANT_ACCESS_SCRIPT.as_dictionary(entry_variant)
		if _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(entry, "valid", false):
			continue
		issues.append({
			"kind": "invalid_factory_binding",
			"severity": "error",
			"script": _GF_VARIANT_ACCESS_SCRIPT.get_option_string(entry, "script"),
			"message": "Factory binding is missing or invalid.",
		})


func _strip_binding_diagnostic_entries(registries: Dictionary, factories: Dictionary) -> void:
	for registry_key: Variant in registries.keys():
		var registry: Dictionary = _GF_VARIANT_ACCESS_SCRIPT.as_dictionary(registries[registry_key])
		var _removed_entries: bool = registry.erase("entries")
		var _removed_aliases: bool = registry.erase("aliases")
		var _removed_assignable_cache: bool = registry.erase("assignable_cache")
	var _removed_factory_entries: bool = factories.erase("entries")


func _collect_parent_chain_report(max_parent_depth: int) -> Dictionary:
	var entries: Array[Dictionary] = []
	var report: Dictionary = {
		_PARENT_CHAIN_ENTRIES_KEY: entries,
		_PARENT_CHAIN_CYCLE_DETECTED_KEY: false,
		_PARENT_CHAIN_TRUNCATED_KEY: false,
	}
	var visited: Dictionary = _create_parent_lookup_visited()
	var parent: GFArchitecture = _parent_architecture
	var depth: int = 0
	while parent != null and (max_parent_depth <= 0 or depth < max_parent_depth):
		var parent_instance_id: int = parent.get_instance_id()
		if visited.has(parent_instance_id):
			_record_parent_lookup_cycle(visited, parent, depth + 1)
			report[_PARENT_CHAIN_CYCLE_DETECTED_KEY] = true
			report[_PARENT_CHAIN_CYCLE_ARCHITECTURE_KEY] = _GF_VARIANT_ACCESS_SCRIPT.get_option_string(visited, _PARENT_CHAIN_CYCLE_ARCHITECTURE_KEY, "")
			report[_PARENT_CHAIN_CYCLE_DEPTH_KEY] = _GF_VARIANT_ACCESS_SCRIPT.get_option_int(visited, _PARENT_CHAIN_CYCLE_DEPTH_KEY, -1)
			report[_PARENT_CHAIN_CYCLE_START_DEPTH_KEY] = _GF_VARIANT_ACCESS_SCRIPT.get_option_int(visited, _PARENT_CHAIN_CYCLE_START_DEPTH_KEY, -1)
			break
		depth += 1
		visited[parent_instance_id] = depth
		visited["depth"] = depth
		entries.append({
			"depth": depth,
			"lifecycle_state": parent._runtime.get_state_name(),
			"inited": parent._runtime.is_ready(),
			"is_initializing": parent._runtime.is_initializing(),
			"disposed": parent._runtime.is_disposed(),
			"lifecycle_generation": parent._runtime.get_lifecycle_generation(),
			"registry_counts": {
				"models": parent._model_registry.instances.size(),
				"systems": parent._system_registry.instances.size(),
				"utilities": parent._utility_registry.instances.size(),
				"factories": parent._factories.size(),
				"aliases": parent._model_registry.aliases.size() + parent._system_registry.aliases.size() + parent._utility_registry.aliases.size(),
			},
		})
		parent = parent._parent_architecture
	if parent != null and max_parent_depth > 0 and depth >= max_parent_depth:
		report[_PARENT_CHAIN_TRUNCATED_KEY] = true
	report[_PARENT_CHAIN_ENTRIES_KEY] = entries
	return report


func _append_parent_chain_issues(issues: Array[Dictionary], parent_chain_report: Dictionary) -> void:
	if not _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(parent_chain_report, _PARENT_CHAIN_CYCLE_DETECTED_KEY, false):
		return
	issues.append({
		"severity": "error",
		"kind": "parent_chain_cycle",
		"message": "Architecture parent chain contains a cycle.",
		"metadata": {
			"cycle_architecture": _GF_VARIANT_ACCESS_SCRIPT.get_option_string(parent_chain_report, _PARENT_CHAIN_CYCLE_ARCHITECTURE_KEY, ""),
			"cycle_depth": _GF_VARIANT_ACCESS_SCRIPT.get_option_int(parent_chain_report, _PARENT_CHAIN_CYCLE_DEPTH_KEY, -1),
			"cycle_start_depth": _GF_VARIANT_ACCESS_SCRIPT.get_option_int(parent_chain_report, _PARENT_CHAIN_CYCLE_START_DEPTH_KEY, -1),
		},
	})


func _clear_factory_binding(script_cls: Script) -> void:
	if script_cls == null or not _factories.has(script_cls):
		return

	var binding: GFBinding = _get_dictionary_binding(_factories, script_cls)
	var _removed_factory: bool = _factories.erase(script_cls)
	if binding != null:
		binding.dispose_cached_instance()


func _clear_failed_initialization_state() -> void:
	var disposed_instances: Dictionary = _begin_module_disposal_session()
	var cleanup_plan: GFArchitectureLifecyclePlan = (
		_active_lifecycle_plan
		if _active_lifecycle_plan != null
		else _lifecycle_plan_in_progress
	)
	if cleanup_plan != null:
		for instance: Object in cleanup_plan.get_shutdown_order():
			_dispose_module_once(instance, disposed_instances)
	for instance: Object in _get_modules_by_lifecycle_priority(
		_system_registry.instances,
		true
	):
		_dispose_module_once(instance, disposed_instances)
	for instance: Object in _get_modules_by_lifecycle_priority(
		_model_registry.instances,
		true
	):
		_dispose_module_once(instance, disposed_instances)
	for instance: Object in _get_modules_by_lifecycle_priority(
		_utility_registry.instances,
		true
	):
		_dispose_module_once(instance, disposed_instances)
	for binding_variant: Variant in _factories.values():
		var binding: GFBinding = _variant_to_binding(binding_variant)
		if binding != null:
			binding.dispose_cached_instance()

	_model_registry._clear()
	_system_registry._clear()
	_utility_registry._clear()
	_factories.clear()
	_module_lifecycle_stages.clear()
	_services.clear()
	_event_system.clear()
	_time_provider = null
	_active_lifecycle_plan = null
	_lifecycle_plan_in_progress = null
	_activation_scope = null
	_refresh_tick_caches()
	_release_external_dependency_leases(
		_active_external_dependency_leases
	)
	_active_external_dependency_leases.clear()
	_end_module_disposal_session()


func _collect_factory_debug_state() -> Dictionary:
	var result: Dictionary = {}
	for script_cls: Script in _factories.keys():
		var binding: Object = _get_dictionary_object(_factories, script_cls)
		var lifetime: int = -1
		if binding != null and "lifetime" in binding:
			lifetime = _get_object_int_property(binding, &"lifetime", -1)
		result[_get_script_debug_key(script_cls)] = {
			"lifetime": lifetime,
			"lifetime_name": _get_binding_lifetime_name(lifetime),
			"valid": binding != null,
		}
	return result


func _get_lifecycle_stage_name(stage: int) -> String:
	match stage:
		0:
			return "registered"
		1:
			return "init"
		2:
			return "async_init"
		3:
			return "ready"
		4:
			return "active"
		_:
			return "unknown"


func _get_binding_lifetime_name(lifetime: int) -> String:
	match lifetime:
		GFBindingLifetimesBase.Lifetime.TRANSIENT:
			return "transient"
		GFBindingLifetimesBase.Lifetime.SINGLETON:
			return "singleton"
		_:
			return "unknown"


func _validate_factory_lifetime(lifetime: int, context: String) -> bool:
	if (
		lifetime == GFBindingLifetimesBase.Lifetime.TRANSIENT
		or lifetime == GFBindingLifetimesBase.Lifetime.SINGLETON
	):
		return true

	push_error("[GFArchitecture] %s 失败：未知工厂生命周期：%s。" % [context, str(lifetime)])
	return false


func _get_script_debug_key(script_cls: Script, instance: Object = null) -> String:
	if script_cls != null:
		var global_name: StringName = script_cls.get_global_name()
		if global_name != &"":
			return String(global_name)
		if not script_cls.resource_path.is_empty():
			return script_cls.resource_path
	if instance != null:
		var instance_script: Script = _get_instance_script(instance)
		if instance_script != null and not instance_script.resource_path.is_empty():
			return instance_script.resource_path
		return "Instance:%d" % instance.get_instance_id()
	return ""


func _get_instance_debug_key(instance: Object) -> String:
	if instance == null:
		return "null"
	var script: Script = _get_instance_script(instance)
	if script != null:
		return _get_script_debug_key(script, instance)
	return "Instance:%d" % instance.get_instance_id()


# 从脚本类获取用于序列化的稳定字符串键。
# 优先使用 Model.get_save_key()，其次使用 class_name（全局类名）。
func _get_model_key(script_cls: Script, model: GFModel = null) -> String:
	if model != null:
		var save_key: String = String(model.get_save_key())
		if not save_key.is_empty():
			return save_key

	var global_name: StringName = script_cls.get_global_name()
	if global_name != &"":
		return String(global_name)
	push_error("[GFArchitecture] 可序列化 Model 缺少稳定标识：请为脚本声明 class_name 或重写 get_save_key()。")
	return ""


func _begin_topology_mutation(
	operation: StringName,
	module_registry: ModuleRegistry,
	script_cls: Script,
	candidate: Object,
	previous: Object = null
) -> TopologyMutation:
	if _topology_mutation != null:
		return null
	var transaction: TopologyMutation = TopologyMutation.new(
		_next_topology_mutation_id,
		operation,
		module_registry,
		script_cls,
		candidate,
		previous
	)
	_next_topology_mutation_id += 1
	_topology_mutation = transaction
	return transaction


func _stage_topology_service_registration(
	transaction: TopologyMutation,
	service_key: StringName,
	provider: Object
) -> bool:
	if (
		not _is_topology_mutation_current(transaction)
		or provider == null
		or provider != transaction._candidate
	):
		push_error(
			"[GFArchitecture] register_service 失败：拓扑事务期间仅候选模块可暂存自身服务。"
		)
		return false
	if transaction._service_intents.has(service_key):
		return (
			_get_dictionary_object(
				transaction._service_intents,
				service_key
			) == provider
		)
	if (
		transaction._service_intents.size()
		>= _MAX_TOPOLOGY_SERVICE_INTENTS
	):
		push_error(
			"[GFArchitecture] register_service 失败：拓扑事务服务意图超过上限。"
		)
		return false
	var current_present: bool = _services.has(service_key)
	var current_provider: Object = _get_dictionary_object(
		_services,
		service_key
	)
	if (
		current_present
		and current_provider != provider
		and current_provider != transaction._previous
	):
		push_error(
			"[GFArchitecture] register_service 失败：service_key 已由拓扑事务之外的 provider 占用：%s。"
			% String(service_key)
		)
		return false
	transaction._expected_service_presence[service_key] = current_present
	transaction._expected_service_providers[service_key] = current_provider
	transaction._service_intents[service_key] = provider
	return true


func _stage_topology_service_unregistration(
	transaction: TopologyMutation,
	service_key: StringName,
	provider: Object
) -> bool:
	if not _is_topology_mutation_current(transaction):
		return false
	if provider == null:
		push_error(
			"[GFArchitecture] unregister_service 失败：拓扑事务期间必须显式提供 provider。"
		)
		return false
	if provider == transaction._candidate:
		if (
			not transaction._service_intents.has(service_key)
			or _get_dictionary_object(
				transaction._service_intents,
				service_key
			) != provider
		):
			return false
		var _removed_intent: bool = (
			transaction._service_intents.erase(service_key)
		)
		var _removed_presence: bool = (
			transaction._expected_service_presence.erase(service_key)
		)
		var _removed_provider: bool = (
			transaction._expected_service_providers.erase(service_key)
		)
		return true
	if provider == transaction._previous:
		return (
			_services.has(service_key)
			and _get_dictionary_object(_services, service_key) == provider
		)
	push_error(
		"[GFArchitecture] unregister_service 失败：provider 不属于当前拓扑事务。"
	)
	return false


func _validate_topology_service_intents(
	transaction: TopologyMutation
) -> bool:
	if not _is_topology_mutation_current(transaction):
		return false
	for service_key: Variant in transaction._service_intents.keys():
		var expected_present: bool = (
			_GF_VARIANT_ACCESS_SCRIPT.get_option_bool(
				transaction._expected_service_presence,
				service_key,
				false
			)
		)
		if _services.has(service_key) != expected_present:
			push_error(
				"[GFArchitecture] 拓扑事务提交失败：service_key 的存在状态已漂移：%s。"
				% _GF_VARIANT_ACCESS_SCRIPT.to_text(service_key)
			)
			return false
		if (
			expected_present
			and _get_dictionary_object(_services, service_key)
			!= _get_dictionary_object(
				transaction._expected_service_providers,
				service_key
			)
		):
			push_error(
				"[GFArchitecture] 拓扑事务提交失败：service_key 的 provider 已漂移：%s。"
				% _GF_VARIANT_ACCESS_SCRIPT.to_text(service_key)
			)
			return false
	return true


func _commit_topology_service_intents(
	transaction: TopologyMutation
) -> void:
	for service_key: Variant in transaction._service_intents.keys():
		var provider: Object = _get_dictionary_object(
			transaction._service_intents,
			service_key
		)
		if provider != null:
			_services[service_key] = provider


func _is_topology_mutation_current(
	transaction: TopologyMutation
) -> bool:
	return (
		transaction != null
		and transaction == _topology_mutation
		and transaction._owner == TopologyMutation._OWNER_CONTINUATION
		and transaction._phase != TopologyMutation._PHASE_ABORTED
		and transaction._phase != TopologyMutation._PHASE_FINISHED
	)


func _finish_topology_mutation(
	transaction: TopologyMutation
) -> void:
	if not _is_topology_mutation_current(transaction):
		return
	if transaction._outcome == TopologyMutation._OUTCOME_PENDING:
		transaction._outcome = TopologyMutation._OUTCOME_ROLLED_BACK
	_release_topology_external_dependency_leases(transaction)
	transaction._phase = TopologyMutation._PHASE_FINISHED
	_topology_mutation = null
	if transaction._gate.is_pending():
		var _completed_topology: bool = transaction._gate.succeed()


func _abort_topology_mutation(
	_reason: StringName
) -> TopologyMutation:
	var transaction: TopologyMutation = _topology_mutation
	if transaction == null:
		return null
	transaction._owner = TopologyMutation._OWNER_SHUTDOWN
	transaction._outcome = TopologyMutation._OUTCOME_ABORTED
	transaction._phase = TopologyMutation._PHASE_ABORTED
	_topology_mutation = null
	return transaction


func _finalize_aborted_topology_mutation(
	transaction: TopologyMutation,
	reason: StringName
) -> void:
	if transaction != null and transaction._gate.is_pending():
		var _cancelled_topology: bool = transaction._gate.cancel(reason)


func _fail_topology_mutation(
	transaction: TopologyMutation,
	error: String
) -> void:
	if not _is_topology_mutation_current(transaction):
		return
	transaction._outcome = TopologyMutation._OUTCOME_FATAL
	transaction._phase = TopologyMutation._PHASE_ABORTED
	_cleanup_topology_candidate(transaction)
	_topology_mutation = null
	if transaction._gate.is_pending():
		var _failed_topology: bool = transaction._gate.fail(error)


func _cleanup_topology_candidate(
	transaction: TopologyMutation
) -> void:
	_release_topology_external_dependency_leases(transaction)
	if (
		transaction == null
		or transaction._candidate == null
		or transaction._candidate_cleanup_state
		!= TopologyMutation._CLEANUP_PENDING
	):
		return
	transaction._candidate_cleanup_state = TopologyMutation._CLEANUP_CLAIMED
	var module_registry: ModuleRegistry = null
	if transaction._module_registry is ModuleRegistry:
		module_registry = transaction._module_registry
	if (
		module_registry != null
		and _get_dictionary_object(
			module_registry.instances,
			transaction._script_cls
		) == transaction._candidate
	):
		var _removed_candidate: Object = _remove_registered_module(
			module_registry,
			transaction._script_cls,
			true,
			false
		)
		transaction._candidate_cleanup_state = TopologyMutation._CLEANUP_DONE
		return
	_cleanup_uncommitted_module(transaction._candidate)
	transaction._candidate_cleanup_state = TopologyMutation._CLEANUP_DONE


func _rollback_topology_candidate(
	topology_transaction: TopologyMutation,
	runtime_transaction: Dictionary
) -> void:
	_cleanup_topology_candidate(topology_transaction)
	if (
		topology_transaction != null
		and topology_transaction._outcome
		== TopologyMutation._OUTCOME_PENDING
	):
		topology_transaction._outcome = (
			TopologyMutation._OUTCOME_ROLLED_BACK
		)
	_runtime.finish_transaction(runtime_transaction)
	_finish_topology_mutation(topology_transaction)


func _register_initialized_module(
	module_registry: ModuleRegistry,
	script_cls: Script,
	instance: Object
) -> bool:
	var operation_name: String = (
		"register_%s" % module_registry._label_key()
	)
	if not _can_mutate_registration_state(operation_name):
		return false
	if not _validate_registration(
		script_cls,
		instance,
		module_registry.label
	):
		return false
	if module_registry._has_direct(script_cls):
		push_warning(
			"[GFArchitecture] %s：类型已注册，已忽略重复注册；如需替换请使用 replace_%s()。"
			% [
				operation_name,
				module_registry._label_key(),
			]
		)
		return false
	var existing_key: Script = module_registry._get_key_for_instance(
		instance
	)
	if existing_key != null:
		push_error(
			"[GFArchitecture] %s 失败：同一实例已注册为 %s。"
			% [
				operation_name,
				_get_script_debug_key(existing_key, instance),
			]
		)
		return false
	var topology_transaction: TopologyMutation = _begin_topology_mutation(
		&"register",
		module_registry,
		script_cls,
		instance
	)
	if topology_transaction == null:
		return false
	topology_transaction._previous_plan = _active_lifecycle_plan
	var current_serial: int = _runtime.get_lifecycle_generation()
	topology_transaction._lifecycle_serial = current_serial
	var runtime_transaction: Dictionary = _runtime.begin_transaction(
		operation_name
	)
	topology_transaction._candidate_cleanup_state = (
		TopologyMutation._CLEANUP_PENDING
	)
	var candidate_models: Dictionary = _models.duplicate()
	var candidate_utilities: Dictionary = _utilities.duplicate()
	var candidate_systems: Dictionary = _systems.duplicate()
	var candidate_registry: Dictionary = (
		_get_candidate_registry_dictionary(
			module_registry,
			candidate_models,
			candidate_utilities,
			candidate_systems
		)
	)
	candidate_registry[script_cls] = instance
	var candidate_plan: GFArchitectureLifecyclePlan = (
		_compile_candidate_lifecycle_plan(
			candidate_models,
			candidate_utilities,
			candidate_systems,
			"hot register",
			true,
			_create_lifecycle_plan_validity_guard(
				current_serial,
				topology_transaction,
				runtime_transaction
			)
		)
	)
	if (
		candidate_plan == null
		or not _is_topology_mutation_current(topology_transaction)
		or not _is_lifecycle_current(current_serial)
		or not _runtime.is_ready()
		or _runtime.has_failed()
		or _runtime.is_transaction_invalidated(runtime_transaction)
	):
		_rollback_topology_candidate(
			topology_transaction,
			runtime_transaction
		)
		return false
	if not _validate_candidate_plan_stability(
		topology_transaction._previous_plan,
		candidate_plan,
		{},
		"hot register"
	):
		_rollback_topology_candidate(
			topology_transaction,
			runtime_transaction
		)
		return false
	topology_transaction._candidate_plan = candidate_plan
	if not _stage_topology_external_dependency_leases(
		topology_transaction,
		candidate_plan,
		current_serial
	):
		_rollback_topology_candidate(
			topology_transaction,
			runtime_transaction
		)
		return false
	_module_lifecycle_stages[instance] = 0
	var prepared: bool = await _prepare_replacement_module(
		instance,
		current_serial
	)
	if (
		not prepared
		or not _is_lifecycle_current(current_serial)
		or _runtime.is_transaction_invalidated(runtime_transaction)
		or not _is_topology_mutation_current(topology_transaction)
	):
		_rollback_topology_candidate(
			topology_transaction,
			runtime_transaction
		)
		return false
	_module_lifecycle_stages[instance] = 2
	_call_module_ready(instance)
	if (
		not _is_lifecycle_current(current_serial)
		or _runtime.has_failed()
		or _runtime.is_transaction_invalidated(runtime_transaction)
		or not _is_topology_mutation_current(topology_transaction)
	):
		_rollback_topology_candidate(
			topology_transaction,
			runtime_transaction
		)
		return false
	_module_lifecycle_stages[instance] = 3
	topology_transaction._phase = TopologyMutation._PHASE_ACTIVATING
	var activated: bool = await _activate_topology_candidate(
		instance,
		candidate_plan,
		current_serial,
		true,
		topology_transaction
	)
	var committed: bool = (
		activated
		and _is_lifecycle_current(current_serial)
		and _is_topology_mutation_current(topology_transaction)
		and not _runtime.has_failed()
		and not _runtime.is_transaction_invalidated(
			runtime_transaction
		)
		and _has_module_reached_lifecycle_stage(instance, 4)
		and _validate_topology_service_intents(topology_transaction)
	)
	if committed:
		topology_transaction._phase = TopologyMutation._PHASE_COMMITTING
		module_registry.instances[script_cls] = instance
		module_registry._track_instance_key(instance, script_cls)
		module_registry._clear_assignable_cache()
		_commit_topology_service_intents(topology_transaction)
		_promote_topology_external_dependency_leases(
			topology_transaction
		)
		_active_lifecycle_plan = candidate_plan
		topology_transaction._candidate_cleanup_state = (
			TopologyMutation._CLEANUP_TRANSFERRED
		)
		topology_transaction._outcome = TopologyMutation._OUTCOME_COMMITTED
		topology_transaction._phase = TopologyMutation._PHASE_COMMITTED
		_refresh_tick_caches()
	else:
		_cleanup_topology_candidate(topology_transaction)
		topology_transaction._outcome = (
			TopologyMutation._OUTCOME_ROLLED_BACK
		)
	_runtime.finish_transaction(runtime_transaction)
	_finish_topology_mutation(topology_transaction)
	return committed


func _activate_topology_candidate(
	instance: Object,
	candidate_plan: GFArchitectureLifecyclePlan,
	lifecycle_serial: int,
	ephemeral_tick_candidate: bool,
	topology_transaction: TopologyMutation = null
) -> bool:
	if instance == null or candidate_plan == null:
		return false
	var scope: GFAsyncScope = _begin_module_async_scope()
	if _is_topology_mutation_current(topology_transaction):
		topology_transaction._active_scope = scope
	if ephemeral_tick_candidate:
		var _candidate_added: bool = (
			_tick_scheduler.add_lifecycle_candidate(instance)
		)
	var deadline_msec: int = _make_deadline_msec(
		Time.get_ticks_msec(),
		activation_timeout_seconds
	)
	var completion: GFAsyncCompletion = _call_module_begin_activation(
		instance,
		scope
	)
	var activated: bool = false
	if completion != null:
		var wait_report: Dictionary = await _await_lifecycle_completion(
			completion,
			scope,
			null,
			deadline_msec,
			candidate_plan.get_dependency_closure(instance),
			lifecycle_serial
		)
		activated = _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(
			wait_report,
			"succeeded",
			false
		)
		if not activated:
			push_error(
				"[GFArchitecture] 热模块 activation 失败：%s：%s" % [
					_get_instance_debug_key(instance),
					_GF_VARIANT_ACCESS_SCRIPT.get_option_string(
						wait_report,
						"reason",
						"activation failed"
					),
				]
			)
	else:
		push_error(
			"[GFArchitecture] 热模块 activation 失败：%s 返回空 completion。" % (
				_get_instance_debug_key(instance)
			)
		)
	if ephemeral_tick_candidate:
		_tick_scheduler.remove_lifecycle_candidate(instance)
	if scope.is_active():
		scope.complete()
	_untrack_async_scope(scope)
	if (
		topology_transaction != null
		and topology_transaction._active_scope == scope
	):
		topology_transaction._active_scope = null
	if (
		activated
		and (
			not _is_lifecycle_current(lifecycle_serial)
			or _runtime.has_failed()
			or not _is_topology_mutation_current(
				topology_transaction
			)
		)
	):
		activated = false
	if activated:
		_module_lifecycle_stages[instance] = 4
	return activated


func _get_or_create_factory_resolution_context(resolution_context: Dictionary) -> Dictionary:
	if not resolution_context.is_empty():
		return resolution_context
	if not _factory_resolution_context_stack.is_empty():
		return _factory_resolution_context_stack.back()
	return _create_factory_resolution_context()


func _create_factory_resolution_context() -> Dictionary:
	return {
		_FACTORY_RESOLUTION_CREATED_SINGLETONS_KEY: [],
		_FACTORY_RESOLUTION_FAILED_KEY: false,
		_FACTORY_RESOLUTION_STACK_KEY: [],
	}


func _push_factory_resolution_context_if_needed(resolution_context: Dictionary) -> bool:
	if resolution_context.is_empty():
		return false
	if not _factory_resolution_context_stack.is_empty():
		var current_context: Dictionary = _factory_resolution_context_stack.back()
		if is_same(current_context, resolution_context):
			return false
	_factory_resolution_context_stack.append(resolution_context)
	return true


func _create_instance_from_local_factory(
	script_cls: Script,
	requesting_architecture: GFArchitecture,
	resolution_context: Dictionary
) -> Object:
	var binding: GFBinding = _get_dictionary_binding(_factories, script_cls)
	if binding == null:
		_mark_factory_resolution_failed(resolution_context)
		push_error("[GFArchitecture] create_instance 失败：工厂绑定无效。")
		return null

	if _find_factory_resolution_binding_index(resolution_context, binding) >= 0:
		_mark_factory_resolution_failed(resolution_context)
		push_error(
			"[GFArchitecture] create_instance 失败：检测到工厂循环依赖：%s。"
			% _describe_factory_resolution_cycle(resolution_context, binding, script_cls)
		)
		return null

	_push_factory_resolution_entry(resolution_context, binding, script_cls)
	var resolved_instance: Object = binding.get_instance(requesting_architecture, resolution_context)
	_pop_factory_resolution_entry(resolution_context)
	return resolved_instance


func _push_factory_resolution_entry(
	resolution_context: Dictionary,
	binding: GFBinding,
	script_cls: Script
) -> void:
	var resolution_stack: Array = _get_factory_resolution_stack(resolution_context)
	resolution_stack.append({
		_FACTORY_RESOLUTION_BINDING_KEY: binding,
		_FACTORY_RESOLUTION_SCRIPT_KEY: script_cls,
	})
	resolution_context[_FACTORY_RESOLUTION_STACK_KEY] = resolution_stack


func _pop_factory_resolution_entry(resolution_context: Dictionary) -> void:
	var resolution_stack: Array = _get_factory_resolution_stack(resolution_context)
	if resolution_stack.is_empty():
		return
	var _removed_entry: Variant = resolution_stack.pop_back()
	resolution_context[_FACTORY_RESOLUTION_STACK_KEY] = resolution_stack


func _get_factory_resolution_stack(resolution_context: Dictionary) -> Array:
	var stack_value: Variant = resolution_context.get(_FACTORY_RESOLUTION_STACK_KEY, [])
	if stack_value is Array:
		var existing_resolution_stack: Array = stack_value
		return existing_resolution_stack
	var new_resolution_stack: Array = []
	resolution_context[_FACTORY_RESOLUTION_STACK_KEY] = new_resolution_stack
	return new_resolution_stack


func _get_factory_resolution_created_singletons(resolution_context: Dictionary) -> Array:
	var created_value: Variant = resolution_context.get(_FACTORY_RESOLUTION_CREATED_SINGLETONS_KEY, [])
	if created_value is Array:
		var existing_created_singletons: Array = created_value
		return existing_created_singletons
	var new_created_singletons: Array = []
	resolution_context[_FACTORY_RESOLUTION_CREATED_SINGLETONS_KEY] = new_created_singletons
	return new_created_singletons


func _find_factory_resolution_binding_index(resolution_context: Dictionary, binding: GFBinding) -> int:
	var resolution_stack: Array = _get_factory_resolution_stack(resolution_context)
	for index: int in range(resolution_stack.size()):
		var entry: Dictionary = _variant_to_dictionary(resolution_stack[index])
		var entry_binding: GFBinding = _get_dictionary_binding(entry, _FACTORY_RESOLUTION_BINDING_KEY)
		if entry_binding != null and is_same(entry_binding, binding):
			return index
	return -1


func _describe_factory_resolution_cycle(
	resolution_context: Dictionary,
	binding: GFBinding,
	script_cls: Script
) -> String:
	var resolution_stack: Array = _get_factory_resolution_stack(resolution_context)
	var start_index: int = _find_factory_resolution_binding_index(resolution_context, binding)
	if start_index < 0:
		start_index = 0

	var labels: Array[String] = []
	for index: int in range(start_index, resolution_stack.size()):
		var entry: Dictionary = _variant_to_dictionary(resolution_stack[index])
		var entry_script: Script = _get_dictionary_script(entry, _FACTORY_RESOLUTION_SCRIPT_KEY)
		labels.append(_get_factory_resolution_script_label(entry_script))
	labels.append(_get_factory_resolution_script_label(script_cls))
	return " -> ".join(labels)


func _get_factory_resolution_script_label(script_cls: Script) -> String:
	var label: String = _get_script_debug_key(script_cls)
	if not label.is_empty():
		return label
	if script_cls != null:
		return "Script:%d" % script_cls.get_instance_id()
	return "null"


func _mark_factory_resolution_failed(resolution_context: Dictionary) -> void:
	if resolution_context.is_empty():
		return
	resolution_context[_FACTORY_RESOLUTION_FAILED_KEY] = true


func _factory_resolution_context_has_failed(resolution_context: Dictionary) -> bool:
	if resolution_context.is_empty():
		return false
	var failed_value: Variant = resolution_context.get(_FACTORY_RESOLUTION_FAILED_KEY, false)
	return failed_value == true


func _rollback_factory_resolution_context(resolution_context: Dictionary) -> void:
	var created_singletons: Array = _get_factory_resolution_created_singletons(resolution_context)
	for index: int in range(created_singletons.size() - 1, -1, -1):
		var entry: Dictionary = _variant_to_dictionary(created_singletons[index])
		var binding: GFBinding = _get_dictionary_binding(entry, _FACTORY_RESOLUTION_BINDING_KEY)
		var instance: Object = _get_dictionary_object(entry, _FACTORY_RESOLUTION_INSTANCE_KEY)
		if binding != null:
			binding.reject_cached_instance(instance)
	created_singletons.clear()
	resolution_context[_FACTORY_RESOLUTION_CREATED_SINGLETONS_KEY] = created_singletons


func _create_instance_for_requester(
	script_cls: Script,
	requesting_architecture: GFArchitecture,
	resolution_context: Dictionary = {},
	parent_lookup_visited: Dictionary = {}
) -> Object:
	var active_context: Dictionary = _get_or_create_factory_resolution_context(resolution_context)
	var active_parent_lookup_visited: Dictionary = parent_lookup_visited
	if active_parent_lookup_visited.is_empty():
		active_parent_lookup_visited = _create_parent_lookup_visited()
	var is_root_context: bool = resolution_context.is_empty() and _factory_resolution_context_stack.is_empty()
	var pushed_context: bool = _push_factory_resolution_context_if_needed(active_context)
	var resolved_instance: Object = null

	if _factory_resolution_context_has_failed(active_context):
		if pushed_context:
			var _removed_failed_context: Dictionary = (
				_factory_resolution_context_stack.pop_back()
			)
		if is_root_context:
			_rollback_factory_resolution_context(active_context)
		return null

	if _factories.has(script_cls):
		if not _is_runtime_execution_admitted():
			_mark_factory_resolution_failed(active_context)
			push_error(
				(
					"[GFArchitecture] create_instance 失败："
					+ "工厂所属架构未开放运行时准入。"
				)
			)
		else:
			resolved_instance = _create_instance_from_local_factory(
				script_cls,
				requesting_architecture,
				active_context
			)
	elif not strict_dependency_lookup:
		var parent: GFArchitecture = _get_next_parent_for_lookup(self, active_parent_lookup_visited, "create_instance")
		if parent != null:
			resolved_instance = parent._create_instance_for_requester(
				script_cls,
				requesting_architecture,
				active_context,
				active_parent_lookup_visited
			)
		else:
			_mark_factory_resolution_failed(active_context)
			if not _has_parent_lookup_cycle(active_parent_lookup_visited):
				push_error("[GFArchitecture] create_instance 失败：未注册工厂。")
	elif strict_dependency_lookup:
		_mark_factory_resolution_failed(active_context)
		push_error("[GFArchitecture] strict_dependency_lookup：当前架构未注册工厂：%s" % script_cls.resource_path)

	if pushed_context:
		var _removed_context: Dictionary = _factory_resolution_context_stack.pop_back()
	if is_root_context and _factory_resolution_context_has_failed(active_context):
		_rollback_factory_resolution_context(active_context)
		return null
	return resolved_instance


func _compile_lifecycle_plan_or_fail(
	lifecycle_serial: int
) -> GFArchitectureLifecyclePlan:
	var plan: GFArchitectureLifecyclePlan = _compile_candidate_lifecycle_plan(
		_models,
		_utilities,
		_systems,
		"init",
		false,
		_create_lifecycle_plan_validity_guard(lifecycle_serial)
	)
	if plan != null:
		return plan
	if (
		not _runtime.is_initializing()
		or not _is_lifecycle_current(lifecycle_serial)
		or _runtime.has_failed()
	):
		return null
	var reason: String = "[GFArchitecture] 生命周期依赖计划编译失败：%s" % (
		_last_lifecycle_plan_error
		if not _last_lifecycle_plan_error.is_empty()
		else "invalid dependency graph"
	)
	_fail_initialization(reason, lifecycle_serial)
	return null


func _compile_candidate_lifecycle_plan(
	model_instances: Dictionary,
	utility_instances: Dictionary,
	system_instances: Dictionary,
	context: String,
	report_error: bool = true,
	validity_guard: Callable = Callable()
) -> GFArchitectureLifecyclePlan:
	_last_lifecycle_plan_error = ""
	var plan: GFArchitectureLifecyclePlan = (
		_build_candidate_lifecycle_plan_snapshot(
			model_instances,
			utility_instances,
			system_instances,
			validity_guard
		)
	)
	if not _is_lifecycle_plan_compilation_valid(validity_guard):
		return null
	if plan.is_valid():
		return plan
	var diagnostics: Array[Dictionary] = plan.get_diagnostics()
	var detail: String = "invalid dependency graph"
	if not diagnostics.is_empty():
		detail = _GF_VARIANT_ACCESS_SCRIPT.get_option_string(
			diagnostics[0],
			"message",
			detail
		)
	_last_lifecycle_plan_error = detail
	if report_error:
		push_error(
			"[GFArchitecture] %s 失败：生命周期依赖计划无效：%s" % [
				context,
				detail,
			]
		)
	return null


func _build_candidate_lifecycle_plan_snapshot(
	model_instances: Dictionary,
	utility_instances: Dictionary,
	system_instances: Dictionary,
	validity_guard: Callable = Callable()
) -> GFArchitectureLifecyclePlan:
	var plan: GFArchitectureLifecyclePlan = (
		_GF_ARCHITECTURE_LIFECYCLE_PLAN_SCRIPT.new()
	)
	var _compiled: bool = plan.compile(
		model_instances,
		utility_instances,
		system_instances,
		_create_candidate_lifecycle_dependency_resolvers(
			model_instances,
			utility_instances,
			system_instances
		),
		validity_guard
	)
	return plan


func _create_lifecycle_plan_validity_guard(
	lifecycle_serial: int,
	topology_transaction: TopologyMutation = null,
	runtime_transaction: Dictionary = {}
) -> Callable:
	return func() -> bool:
		if (
			not _is_lifecycle_current(lifecycle_serial)
			or _runtime.has_failed()
			or _runtime.is_quiescing()
			or _runtime.is_disposing()
			or _runtime.is_disposed()
		):
			return false
		if (
			not runtime_transaction.is_empty()
			and _runtime.is_transaction_invalidated(runtime_transaction)
		):
			return false
		if topology_transaction != null:
			return (
				_runtime.is_ready()
				and _is_topology_mutation_current(topology_transaction)
			)
		return _runtime.is_initializing()


func _is_lifecycle_plan_compilation_valid(validity_guard: Callable) -> bool:
	if not validity_guard.is_valid():
		return true
	return _GF_VARIANT_ACCESS_SCRIPT.to_bool(validity_guard.call())


func _acquire_external_dependency_leases(
	plan: GFArchitectureLifecyclePlan,
	lifecycle_serial: int
) -> Dictionary:
	var leases: Array[Dictionary] = []
	if plan == null:
		return {
			"ok": false,
			"leases": leases,
		}
	if not Thread.is_main_thread():
		push_error(
			"[GFArchitecture] 外部依赖租约只能在主线程获取。"
		)
		return {
			"ok": false,
			"leases": leases,
		}
	var lease_owners: Array[GFArchitecture] = []
	var owner_ids: Dictionary = {}
	var owner_module_topology_blocks: Dictionary = {}
	for record: Dictionary in plan.get_dependency_records():
		var status: StringName = (
			_GF_VARIANT_ACCESS_SCRIPT.get_option_string_name(
				record,
				"status",
				&"missing"
			)
		)
		var dependency_kind: StringName = (
			_GF_VARIANT_ACCESS_SCRIPT.get_option_string_name(
				record,
				"dependency_kind",
				&""
			)
		)
		if (
			status != &"external"
			or dependency_kind not in [
				&"models",
				&"systems",
				&"utilities",
				&"factories",
			]
		):
			continue
		var blocks_module_topology: bool = (
			dependency_kind != &"factories"
		)
		var architecture_depth: int = (
			_GF_VARIANT_ACCESS_SCRIPT.get_option_int(
				record,
				"architecture_depth",
				0
			)
		)
		if architecture_depth <= 0:
			_release_external_dependency_leases(leases)
			return {
				"ok": false,
				"leases": [],
			}
		var owner: GFArchitecture = _parent_architecture
		for _depth: int in range(architecture_depth):
			if owner == null:
				_release_external_dependency_leases(leases)
				return {
					"ok": false,
					"leases": [],
				}
			var owner_id: int = owner.get_instance_id()
			if not owner_ids.has(owner_id):
				owner_ids[owner_id] = true
				lease_owners.append(owner)
				owner_module_topology_blocks[owner_id] = (
					blocks_module_topology
				)
			elif blocks_module_topology:
				owner_module_topology_blocks[owner_id] = true
			owner = owner._parent_architecture
	for owner: GFArchitecture in lease_owners:
		var lease_id: int = owner._acquire_child_external_dependency_lease(
			self,
			lifecycle_serial,
			_GF_VARIANT_ACCESS_SCRIPT.get_option_bool(
				owner_module_topology_blocks,
				owner.get_instance_id(),
				false
			)
		)
		if lease_id < 0:
			_release_external_dependency_leases(leases)
			return {
				"ok": false,
				"leases": [],
			}
		leases.append({
			"owner_ref": weakref(owner),
			"lease_id": lease_id,
		})
	return {
		"ok": true,
		"leases": leases,
	}


func _get_external_dependency_lease_array(
	report: Dictionary
) -> Array[Dictionary]:
	var leases: Array[Dictionary] = []
	var raw_leases: Variant = report.get("leases", [])
	if not raw_leases is Array:
		return leases
	for raw_lease: Variant in raw_leases:
		if raw_lease is Dictionary:
			var lease: Dictionary = raw_lease
			leases.append(lease)
	return leases


func _acquire_child_external_dependency_lease(
	consumer: GFArchitecture,
	consumer_lifecycle_serial: int,
	blocks_module_topology: bool
) -> int:
	if not Thread.is_main_thread():
		push_error(
			"[GFArchitecture] 子架构外部依赖租约只能在主线程获取。"
		)
		return -1
	if (
		consumer == null
		or not consumer.is_lifecycle_generation_active(
			consumer_lifecycle_serial
		)
		or not _runtime.is_ready()
		or _topology_mutation != null
	):
		return -1
	var lease_id: int = _next_child_external_dependency_lease_id
	_next_child_external_dependency_lease_id += 1
	_child_external_dependency_leases[lease_id] = {
		"consumer_ref": weakref(consumer),
		"consumer_lifecycle_serial": consumer_lifecycle_serial,
		"blocks_module_topology": blocks_module_topology,
	}
	return lease_id


func _release_child_external_dependency_lease(
	lease_id: int,
	consumer: GFArchitecture
) -> void:
	if not Thread.is_main_thread():
		push_error(
			"[GFArchitecture] 子架构外部依赖租约只能在主线程释放。"
		)
		return
	if not _child_external_dependency_leases.has(lease_id):
		return
	var record: Dictionary = _GF_VARIANT_ACCESS_SCRIPT.as_dictionary(
		_child_external_dependency_leases.get(lease_id)
	)
	var consumer_ref_value: Variant = record.get("consumer_ref")
	if consumer_ref_value is WeakRef:
		var consumer_ref: WeakRef = consumer_ref_value
		var current_consumer: Variant = consumer_ref.get_ref()
		if current_consumer != null and current_consumer != consumer:
			return
	var _removed_lease: bool = (
		_child_external_dependency_leases.erase(lease_id)
	)


func _release_external_dependency_leases(
	leases: Array[Dictionary]
) -> void:
	if leases.is_empty():
		return
	var releasing_leases: Array[Dictionary] = leases.duplicate()
	leases.clear()
	for lease: Dictionary in releasing_leases:
		var owner_ref_value: Variant = lease.get("owner_ref")
		if not owner_ref_value is WeakRef:
			continue
		var owner_ref: WeakRef = owner_ref_value
		var owner_value: Variant = owner_ref.get_ref()
		if not owner_value is GFArchitecture:
			continue
		var owner: GFArchitecture = owner_value
		owner._release_child_external_dependency_lease(
			_GF_VARIANT_ACCESS_SCRIPT.get_option_int(
				lease,
				"lease_id",
				-1
			),
			self
		)


func _has_live_child_external_dependency_leases(
	require_module_topology_block: bool = false
) -> bool:
	if not Thread.is_main_thread():
		return true
	var stale_lease_ids: Array[int] = []
	var has_matching_lease: bool = false
	for lease_id: Variant in _child_external_dependency_leases.keys():
		var record: Dictionary = _GF_VARIANT_ACCESS_SCRIPT.as_dictionary(
			_child_external_dependency_leases.get(lease_id)
		)
		var consumer_ref_value: Variant = record.get("consumer_ref")
		if not consumer_ref_value is WeakRef:
			stale_lease_ids.append(
				_GF_VARIANT_ACCESS_SCRIPT.to_int(lease_id, -1)
			)
			continue
		var consumer_ref: WeakRef = consumer_ref_value
		var consumer_value: Variant = consumer_ref.get_ref()
		if not consumer_value is GFArchitecture:
			stale_lease_ids.append(
				_GF_VARIANT_ACCESS_SCRIPT.to_int(lease_id, -1)
			)
			continue
		if (
			not require_module_topology_block
			or _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(
				record,
				"blocks_module_topology",
				false
			)
		):
			has_matching_lease = true
	for stale_lease_id: int in stale_lease_ids:
		var _removed_stale_lease: bool = (
			_child_external_dependency_leases.erase(stale_lease_id)
		)
	return has_matching_lease


func _stage_topology_external_dependency_leases(
	transaction: TopologyMutation,
	plan: GFArchitectureLifecyclePlan,
	lifecycle_serial: int
) -> bool:
	if not _is_topology_mutation_current(transaction):
		return false
	_release_topology_external_dependency_leases(transaction)
	var report: Dictionary = _acquire_external_dependency_leases(
		plan,
		lifecycle_serial
	)
	if not _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(
		report,
		"ok",
		false
	):
		return false
	transaction._candidate_external_dependency_leases = (
		_get_external_dependency_lease_array(report)
	)
	return true


func _promote_topology_external_dependency_leases(
	transaction: TopologyMutation
) -> void:
	if transaction == null:
		return
	var candidate_leases: Array[Dictionary] = (
		transaction._candidate_external_dependency_leases
	)
	transaction._candidate_external_dependency_leases = []
	var previous_leases: Array[Dictionary] = (
		_active_external_dependency_leases
	)
	_active_external_dependency_leases = candidate_leases
	_release_external_dependency_leases(previous_leases)


func _release_topology_external_dependency_leases(
	transaction: TopologyMutation
) -> void:
	if transaction == null:
		return
	_release_external_dependency_leases(
		transaction._candidate_external_dependency_leases
	)


func _validate_candidate_plan_stability(
	previous_plan: GFArchitectureLifecyclePlan,
	candidate_plan: GFArchitectureLifecyclePlan,
	excluded_instances: Dictionary,
	context: String
) -> bool:
	if previous_plan == null or candidate_plan == null:
		push_error(
			"[GFArchitecture] %s 失败：缺少可比较的生命周期计划。"
			% context
		)
		return false
	var previous_index: Dictionary = _index_plan_dependency_signatures(
		previous_plan
	)
	var candidate_index: Dictionary = _index_plan_dependency_signatures(
		candidate_plan
	)
	for instance: Object in previous_plan.get_activation_order():
		if instance == null or excluded_instances.has(instance):
			continue
		if (
			not previous_index.has(instance)
			or not candidate_index.has(instance)
		):
			push_error(
				"[GFArchitecture] %s 失败：既有活动模块离开了候选依赖计划：%s。"
				% [
					context,
					_get_instance_debug_key(instance),
				]
			)
			return false
		var previous_signature: Dictionary = _variant_to_dictionary(
			previous_index.get(instance, {})
		)
		var candidate_signature: Dictionary = _variant_to_dictionary(
			candidate_index.get(instance, {})
		)
		if previous_signature != candidate_signature:
			push_error(
				"[GFArchitecture] %s 失败：既有活动模块的声明或解析目标发生漂移：%s；请构造新的 Architecture 完成重绑定。"
				% [
					context,
					_get_instance_debug_key(instance),
				]
			)
			return false
	return true


func _index_plan_dependency_signatures(
	plan: GFArchitectureLifecyclePlan
) -> Dictionary:
	var result: Dictionary = {}
	if plan == null:
		return result
	for snapshot: Dictionary in plan.get_dependency_snapshot():
		var instance: Object = _get_dictionary_object(
			snapshot,
			"module_instance"
		)
		if instance == null:
			continue
		var stable_snapshot: Dictionary = snapshot.duplicate(true)
		var _removed_snapshot_key: bool = stable_snapshot.erase(
			"module_key"
		)
		result[instance] = {
			"snapshot": stable_snapshot,
			"records": [],
		}
	for record: Dictionary in plan.get_dependency_records():
		var instance: Object = _get_dictionary_object(
			record,
			"module_instance"
		)
		if instance == null or not result.has(instance):
			continue
		var signature: Dictionary = _variant_to_dictionary(
			result.get(instance, {})
		)
		var records_value: Variant = signature.get("records", [])
		if records_value is Array:
			var records: Array = records_value
			var stable_record: Dictionary = record.duplicate(true)
			var _removed_record_key: bool = stable_record.erase(
				"module_key"
			)
			records.append(stable_record)
	return result


func _create_candidate_lifecycle_dependency_resolvers(
	model_instances: Dictionary,
	utility_instances: Dictionary,
	system_instances: Dictionary
) -> Dictionary:
	return {
		&"models": func(script_cls: Script) -> Dictionary:
			return _resolve_candidate_lifecycle_dependency_status(
				"model",
				script_cls,
				model_instances
			),
		&"utilities": func(script_cls: Script) -> Dictionary:
			return _resolve_candidate_lifecycle_dependency_status(
				"utility",
				script_cls,
				utility_instances
			),
		&"systems": func(script_cls: Script) -> Dictionary:
			return _resolve_candidate_lifecycle_dependency_status(
				"system",
				script_cls,
				system_instances
			),
		&"factories": func(script_cls: Script) -> Dictionary:
			return _resolve_candidate_factory_dependency_status(script_cls),
	}


func _resolve_candidate_lifecycle_dependency_status(
	registry_kind: String,
	script_cls: Script,
	candidate_instances: Dictionary
) -> Dictionary:
	if script_cls == null:
		return _make_lifecycle_dependency_status(
			&"missing",
			&"invalid_script"
		)
	var local_status: Dictionary = _resolve_local_lifecycle_dependency_status(
		registry_kind,
		script_cls,
		candidate_instances,
		0
	)
	var local_status_name: StringName = (
		_GF_VARIANT_ACCESS_SCRIPT.get_option_string_name(
			local_status,
			"status",
			&"missing"
		)
	)
	if local_status_name != &"missing":
		return local_status
	if strict_dependency_lookup:
		return _make_lifecycle_dependency_status(
			&"missing",
			&"strict_local_miss"
		)
	return _resolve_parent_lifecycle_dependency_status(
		registry_kind,
		script_cls
	)


func _resolve_local_lifecycle_dependency_status(
	registry_kind: String,
	script_cls: Script,
	candidate_instances: Dictionary,
	architecture_depth: int
) -> Dictionary:
	var module_registry: ModuleRegistry = _get_module_registry_by_kind(
		registry_kind
	)
	if module_registry == null:
		return _make_lifecycle_dependency_status(
			&"missing",
			&"invalid_registry",
			architecture_depth
		)
	if candidate_instances.has(script_cls):
		return _make_lifecycle_dependency_status(
			&"local",
			&"exact",
			architecture_depth,
			_get_dictionary_object(candidate_instances, script_cls),
			script_cls
		)
	if module_registry.aliases.has(script_cls):
		var alias_target: Script = _get_dictionary_script(
			module_registry.aliases,
			script_cls
		)
		if alias_target != null and candidate_instances.has(alias_target):
			return _make_lifecycle_dependency_status(
				&"local",
				&"alias",
				architecture_depth,
				_get_dictionary_object(candidate_instances, alias_target),
				alias_target
			)
		return _make_lifecycle_dependency_status(
			&"stale_alias",
			&"stale_alias",
			architecture_depth,
			null,
			alias_target
		)
	var assignable_instances: Array[Object] = []
	var assignable_scripts: Array[Script] = []
	for registered_script: Script in candidate_instances.keys():
		if not GFScriptTypeInspector.script_extends_or_equals(
			registered_script,
			script_cls
		):
			continue
		var match_instance: Object = _get_dictionary_object(
			candidate_instances,
			registered_script
		)
		if match_instance != null:
			assignable_instances.append(match_instance)
			assignable_scripts.append(registered_script)
	if assignable_instances.size() == 1:
		return _make_lifecycle_dependency_status(
			&"local",
			&"assignable",
			architecture_depth,
			assignable_instances[0],
			assignable_scripts[0]
		)
	if assignable_instances.size() > 1:
		return _make_lifecycle_dependency_status(
			&"ambiguous",
			&"ambiguous_assignable",
			architecture_depth
		)
	return _make_lifecycle_dependency_status(
		&"missing",
		&"local_miss",
		architecture_depth
	)


func _resolve_parent_lifecycle_dependency_status(
	registry_kind: String,
	script_cls: Script
) -> Dictionary:
	var parent_chain_issue: Dictionary = (
		_get_lifecycle_parent_chain_issue()
	)
	if not parent_chain_issue.is_empty():
		return parent_chain_issue
	var visited: Dictionary = {get_instance_id(): 0}
	var current: GFArchitecture = _parent_architecture
	var architecture_depth: int = 1
	while current != null:
		if visited.has(current.get_instance_id()):
			return {
				"status": &"parent_cycle",
				"scope": &"missing",
				"architecture_depth": architecture_depth,
				"resolution_kind": &"parent_cycle",
				"cycle_architecture": current._get_architecture_debug_key(
					current
				),
				"cycle_depth": architecture_depth,
				"cycle_start_depth": (
					_GF_VARIANT_ACCESS_SCRIPT.get_option_int(
						visited,
						current.get_instance_id(),
						-1
					)
				),
			}
		visited[current.get_instance_id()] = architecture_depth
		if (
			not current._runtime.is_ready()
			or current._topology_mutation != null
		):
			return _make_lifecycle_dependency_status(
				&"missing",
				&"inactive_parent",
				architecture_depth
			)
		var module_registry: ModuleRegistry = (
			current._get_module_registry_by_kind(registry_kind)
		)
		if module_registry == null:
			return _make_lifecycle_dependency_status(
				&"missing",
				&"invalid_registry",
				architecture_depth
			)
		var local_status: Dictionary = (
			current._resolve_local_lifecycle_dependency_status(
				registry_kind,
				script_cls,
				module_registry.instances,
				architecture_depth
			)
		)
		var status_name: StringName = (
			_GF_VARIANT_ACCESS_SCRIPT.get_option_string_name(
				local_status,
				"status",
				&"missing"
			)
		)
		if status_name == &"local":
			var instance: Object = _get_dictionary_object(
				local_status,
				"instance"
			)
			if instance == null or not current.is_module_active(instance):
				return _make_lifecycle_dependency_status(
					&"missing",
					&"inactive_parent_module",
					architecture_depth
				)
			local_status["status"] = &"external"
			local_status["scope"] = &"parent"
			return local_status
		if status_name != &"missing":
			return local_status
		if current.strict_dependency_lookup:
			return _make_lifecycle_dependency_status(
				&"missing",
				&"strict_parent_miss",
				architecture_depth
			)
		current = current._parent_architecture
		architecture_depth += 1
	return _make_lifecycle_dependency_status(
		&"missing",
		&"parent_miss",
		architecture_depth
	)


func _resolve_candidate_factory_dependency_status(
	script_cls: Script
) -> Dictionary:
	if script_cls == null:
		return _make_lifecycle_dependency_status(
			&"missing",
			&"invalid_script"
		)
	if _factories.has(script_cls):
		return _make_lifecycle_dependency_status(
			&"local",
			&"exact_factory"
		)
	if strict_dependency_lookup:
		return _make_lifecycle_dependency_status(
			&"missing",
			&"strict_local_miss"
		)
	var parent_chain_issue: Dictionary = (
		_get_lifecycle_parent_chain_issue()
	)
	if not parent_chain_issue.is_empty():
		return parent_chain_issue
	var visited: Dictionary = {get_instance_id(): 0}
	var current: GFArchitecture = _parent_architecture
	var architecture_depth: int = 1
	while current != null:
		if visited.has(current.get_instance_id()):
			return {
				"status": &"parent_cycle",
				"scope": &"missing",
				"architecture_depth": architecture_depth,
				"resolution_kind": &"parent_cycle",
				"cycle_architecture": current._get_architecture_debug_key(
					current
				),
				"cycle_depth": architecture_depth,
				"cycle_start_depth": (
					_GF_VARIANT_ACCESS_SCRIPT.get_option_int(
						visited,
						current.get_instance_id(),
						-1
					)
				),
			}
		visited[current.get_instance_id()] = architecture_depth
		if (
			not current._runtime.is_ready()
			or current._topology_mutation != null
		):
			return _make_lifecycle_dependency_status(
				&"missing",
				&"inactive_parent",
				architecture_depth
			)
		if current._factories.has(script_cls):
			var external_status: Dictionary = (
				_make_lifecycle_dependency_status(
					&"external",
					&"exact_factory",
					architecture_depth
				)
			)
			external_status["scope"] = &"parent"
			return external_status
		if current.strict_dependency_lookup:
			return _make_lifecycle_dependency_status(
				&"missing",
				&"strict_parent_miss",
				architecture_depth
			)
		current = current._parent_architecture
		architecture_depth += 1
	return _make_lifecycle_dependency_status(
		&"missing",
		&"parent_miss",
		architecture_depth
	)


func _get_lifecycle_parent_chain_issue() -> Dictionary:
	var visited: Dictionary = {get_instance_id(): 0}
	var current: GFArchitecture = _parent_architecture
	var architecture_depth: int = 1
	while (
		current != null
		and architecture_depth <= _MAX_LIFECYCLE_PARENT_DEPTH
	):
		var instance_id: int = current.get_instance_id()
		if visited.has(instance_id):
			return {
				"status": &"parent_cycle",
				"scope": &"missing",
				"architecture_depth": architecture_depth,
				"resolution_kind": &"parent_cycle",
				"cycle_architecture": _get_architecture_debug_key(current),
				"cycle_depth": architecture_depth,
				"cycle_start_depth": (
					_GF_VARIANT_ACCESS_SCRIPT.get_option_int(
						visited,
						instance_id,
						-1
					)
				),
			}
		visited[instance_id] = architecture_depth
		current = current._parent_architecture
		architecture_depth += 1
	if current != null:
		return _make_lifecycle_dependency_status(
			&"missing",
			&"parent_chain_truncated",
			_MAX_LIFECYCLE_PARENT_DEPTH
		)
	return {}


func _make_lifecycle_dependency_status(
	status: StringName,
	resolution_kind: StringName,
	architecture_depth: int = 0,
	instance: Object = null,
	registered_script: Script = null
) -> Dictionary:
	var result: Dictionary = {
		"status": status,
		"scope": (
			&"local"
			if status == &"local"
			else (&"parent" if status == &"external" else &"missing")
		),
		"architecture_depth": maxi(architecture_depth, 0),
		"resolution_kind": resolution_kind,
	}
	if instance != null:
		result["instance"] = instance
	if registered_script != null:
		result["registered_script"] = registered_script
	return result


func _advance_lifecycle_plan_to_stage(
	plan: GFArchitectureLifecyclePlan,
	target_stage: int,
	lifecycle_serial: int,
	cancellation_token: GFCancellationToken = null
) -> bool:
	if plan == null or not plan.is_valid():
		return false
	for instance: Object in plan.get_activation_order():
		if not _is_lifecycle_current(lifecycle_serial) or _runtime.has_failed():
			return false
		if cancellation_token != null and cancellation_token.is_cancel_requested():
			_fail_initialization(
				"[GFArchitecture] 初始化已取消：%s。" % String(
					cancellation_token.get_cancel_reason()
				),
				lifecycle_serial
			)
			return false
		var module_registry: ModuleRegistry = _get_module_registry_for_instance(instance)
		if module_registry == null:
			_fail_initialization(
				"[GFArchitecture] 生命周期计划包含已离开注册表的模块。",
				lifecycle_serial
			)
			return false
		var current_stage: int = _GF_VARIANT_ACCESS_SCRIPT.get_option_int(
			_module_lifecycle_stages,
			instance,
			0
		)
		if current_stage >= target_stage:
			continue
		var advanced: bool = await _advance_module_to_stage(
			module_registry,
			instance,
			target_stage,
			lifecycle_serial,
			cancellation_token
		)
		if not advanced and current_stage < target_stage:
			if (
				_runtime.is_initializing()
				and _is_lifecycle_current(lifecycle_serial)
				and not _runtime.has_failed()
			):
				_fail_initialization(
					"[GFArchitecture] 生命周期阶段推进失败：%s 未完成 stage=%d。" % [
						_get_instance_debug_key(instance),
						target_stage,
					],
					lifecycle_serial
				)
			return false
	return _all_registered_modules_reached_stage(target_stage)


func _get_module_registry_for_instance(instance: Object) -> ModuleRegistry:
	if _module_registry_contains_instance(_model_registry, instance):
		return _model_registry
	if _module_registry_contains_instance(_utility_registry, instance):
		return _utility_registry
	if _module_registry_contains_instance(_system_registry, instance):
		return _system_registry
	return null


func _activate_lifecycle_plan(
	plan: GFArchitectureLifecyclePlan,
	lifecycle_serial: int,
	cancellation_token: GFCancellationToken
) -> bool:
	var started_at_msec: int = Time.get_ticks_msec()
	var deadline_msec: int = _make_deadline_msec(
		started_at_msec,
		activation_timeout_seconds
	)
	_activation_scope = _begin_module_async_scope()
	for instance: Object in plan.get_activation_order():
		if not _runtime.is_activating() or not _is_lifecycle_current(lifecycle_serial):
			return false
		if cancellation_token != null and cancellation_token.is_cancel_requested():
			var cancel_reason: String = String(cancellation_token.get_cancel_reason())
			_cancel_module_async_scope(_activation_scope, cancel_reason)
			_fail_initialization(
				"[GFArchitecture] activation 已取消：%s。" % cancel_reason,
				lifecycle_serial
			)
			return false
		var completion: GFAsyncCompletion = _call_module_begin_activation(
			instance,
			_activation_scope
		)
		if completion == null:
			_fail_initialization(
				"[GFArchitecture] activation 失败：%s 返回了空 completion。" % (
					_get_instance_debug_key(instance)
				),
				lifecycle_serial
			)
			return false
		var wait_report: Dictionary = await _await_lifecycle_completion(
			completion,
			_activation_scope,
			cancellation_token,
			deadline_msec,
			plan.get_dependency_closure(instance),
			lifecycle_serial
		)
		if cancellation_token != null and cancellation_token.is_cancel_requested():
			var post_activation_cancel_reason: String = String(
				cancellation_token.get_cancel_reason()
			)
			_cancel_module_async_scope(
				_activation_scope,
				post_activation_cancel_reason
			)
			_fail_initialization(
				"[GFArchitecture] activation 已取消：%s。" % (
					post_activation_cancel_reason
				),
				lifecycle_serial
			)
			return false
		if not _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(wait_report, "succeeded", false):
			var failure_reason: String = _GF_VARIANT_ACCESS_SCRIPT.get_option_string(
				wait_report,
				"reason",
				"activation did not succeed"
			)
			_fail_initialization(
				"[GFArchitecture] activation 失败：%s：%s" % [
					_get_instance_debug_key(instance),
					failure_reason,
				],
				lifecycle_serial
			)
			return false
		_module_lifecycle_stages[instance] = 4
	if _activation_scope != null:
		_activation_scope.complete()
		_untrack_async_scope(_activation_scope)
		_activation_scope = null
	return true


func _await_lifecycle_completion(
	completion: GFAsyncCompletion,
	scope: GFAsyncScope,
	cancellation_token: GFCancellationToken,
	deadline_msec: int,
	allowed_instances: Dictionary,
	lifecycle_serial: int
) -> Dictionary:
	if completion == null:
		return {
			"succeeded": false,
			"status": "failed",
			"reason": "Lifecycle hook returned a null completion.",
		}
	var scene_tree: SceneTree = _get_scene_tree_or_null()
	var last_tick_msec: int = Time.get_ticks_msec()
	while completion.is_pending():
		if not _is_lifecycle_current(lifecycle_serial):
			var _interrupted_completion: bool = completion.cancel(
				&"lifecycle_interrupted"
			)
			return {
				"succeeded": false,
				"status": "interrupted",
				"reason": "Architecture lifecycle generation changed.",
			}
		if cancellation_token != null and cancellation_token.is_cancel_requested():
			var external_reason: StringName = cancellation_token.get_cancel_reason()
			if scope != null:
				var _cancelled_scope: bool = scope.cancel(String(external_reason))
			var _cancelled_completion: bool = completion.cancel(external_reason)
			return {
				"succeeded": false,
				"status": "cancelled",
				"reason": String(external_reason),
			}
		if scope != null and scope.is_cancel_requested():
			var scope_reason: StringName = scope.get_cancel_reason()
			var _cancelled_scoped_completion: bool = completion.cancel(scope_reason)
			return {
				"succeeded": false,
				"status": "cancelled",
				"reason": String(scope_reason),
			}
		var now_msec: int = Time.get_ticks_msec()
		if deadline_msec >= 0 and now_msec >= deadline_msec:
			if scope != null:
				var _timed_out_scope: bool = scope.cancel("lifecycle_timeout")
			var _timed_out_completion: bool = completion.cancel(&"lifecycle_timeout")
			return {
				"succeeded": false,
				"status": "timed_out",
				"reason": "Lifecycle deadline exceeded.",
			}
		if scene_tree == null:
			var _unavailable_completion: bool = completion.fail(
				"Pending lifecycle completion requires an active SceneTree."
			)
			return {
				"succeeded": false,
				"status": "failed",
				"reason": "Pending lifecycle completion requires an active SceneTree.",
			}
		var delta: float = float(maxi(now_msec - last_tick_msec, 0)) / 1000.0
		last_tick_msec = now_msec
		_tick_scheduler.drive_lifecycle_tick(delta, allowed_instances)
		if not completion.is_pending():
			continue
		await scene_tree.process_frame
	if not _is_lifecycle_current(lifecycle_serial):
		var _interrupted_terminal_completion: bool = completion.cancel(
			&"lifecycle_interrupted"
		)
		return {
			"succeeded": false,
			"status": "interrupted",
			"reason": "Architecture lifecycle generation changed.",
		}
	if cancellation_token != null and cancellation_token.is_cancel_requested():
		var terminal_external_reason: StringName = (
			cancellation_token.get_cancel_reason()
		)
		if scope != null:
			var _cancelled_terminal_scope: bool = scope.cancel(
				String(terminal_external_reason)
			)
		var _cancelled_terminal_completion: bool = completion.cancel(
			terminal_external_reason
		)
		return {
			"succeeded": false,
			"status": "cancelled",
			"reason": String(terminal_external_reason),
		}
	if scope != null and scope.is_cancel_requested():
		var terminal_scope_reason: StringName = scope.get_cancel_reason()
		var _cancelled_terminal_scoped_completion: bool = (
			completion.cancel(terminal_scope_reason)
		)
		return {
			"succeeded": false,
			"status": "cancelled",
			"reason": String(terminal_scope_reason),
		}
	if deadline_msec >= 0 and Time.get_ticks_msec() >= deadline_msec:
		if scope != null:
			var _timed_out_terminal_scope: bool = scope.cancel(
				"lifecycle_timeout"
			)
		var _timed_out_terminal_completion: bool = completion.cancel(
			&"lifecycle_timeout"
		)
		return {
			"succeeded": false,
			"status": "timed_out",
			"reason": "Lifecycle deadline exceeded.",
		}
	if completion.is_successful():
		return {
			"succeeded": true,
			"status": "succeeded",
			"reason": "",
		}
	if completion.is_cancelled():
		return {
			"succeeded": false,
			"status": "cancelled",
			"reason": String(completion.get_cancel_reason()),
		}
	return {
		"succeeded": false,
		"status": "failed",
		"reason": completion.get_error(),
	}


func _make_deadline_msec(started_at_msec: int, timeout_seconds: float) -> int:
	if timeout_seconds <= 0.0:
		return -1
	var timeout_msec: float = ceil(timeout_seconds * 1000.0)
	return started_at_msec + int(timeout_msec)


func _await_topology_stability(
	cancellation_token: GFCancellationToken,
	deadline_msec: int
) -> Dictionary:
	if cancellation_token != null and cancellation_token.is_cancel_requested():
		return {
			"succeeded": false,
			"status": "cancelled",
			"reason": String(cancellation_token.get_cancel_reason()),
		}
	if deadline_msec >= 0 and Time.get_ticks_msec() >= deadline_msec:
		return {
			"succeeded": false,
			"status": "timed_out",
			"reason": "Shutdown deadline exceeded before topology stability.",
		}
	var transaction: TopologyMutation = _topology_mutation
	if transaction == null:
		return {
			"succeeded": true,
			"status": "succeeded",
			"reason": "",
		}
	var completion: GFAsyncCompletion = transaction._gate
	if completion == null:
		return {
			"succeeded": false,
			"status": "failed",
			"reason": "Active topology transaction has no completion gate.",
		}
	var scene_tree: SceneTree = _get_scene_tree_or_null()
	while (
		_is_topology_mutation_current(transaction)
		and completion.is_pending()
	):
		if cancellation_token != null and cancellation_token.is_cancel_requested():
			return {
				"succeeded": false,
				"status": "cancelled",
				"reason": String(cancellation_token.get_cancel_reason()),
			}
		if deadline_msec >= 0 and Time.get_ticks_msec() >= deadline_msec:
			return {
				"succeeded": false,
				"status": "timed_out",
				"reason": "Shutdown deadline exceeded while waiting for an accepted topology transaction.",
			}
		if scene_tree == null:
			return {
				"succeeded": false,
				"status": "failed",
				"reason": "Pending topology transaction requires an active SceneTree.",
			}
		await scene_tree.process_frame
	if cancellation_token != null and cancellation_token.is_cancel_requested():
		return {
			"succeeded": false,
			"status": "cancelled",
			"reason": String(cancellation_token.get_cancel_reason()),
		}
	if deadline_msec >= 0 and Time.get_ticks_msec() >= deadline_msec:
		return {
			"succeeded": false,
			"status": "timed_out",
			"reason": "Shutdown deadline exceeded while waiting for an accepted topology transaction.",
		}
	if (
		completion.is_successful()
		and not _is_topology_mutation_current(transaction)
	):
		return {
			"succeeded": true,
			"status": "succeeded",
			"reason": "",
		}
	if completion.is_cancelled():
		return {
			"succeeded": false,
			"status": "cancelled",
			"reason": String(completion.get_cancel_reason()),
		}
	return {
		"succeeded": false,
		"status": "failed",
		"reason": completion.get_error(),
	}


func _make_topology_wait_shutdown_report(
	topology_wait_report: Dictionary
) -> Dictionary:
	var status: String = _GF_VARIANT_ACCESS_SCRIPT.get_option_string(
		topology_wait_report,
		"status",
		"failed"
	)
	var reason: String = _GF_VARIANT_ACCESS_SCRIPT.get_option_string(
		topology_wait_report,
		"reason",
		"Accepted topology transaction did not reach a stable point."
	)
	var unfinished_modules: Array[Dictionary] = []
	if _active_lifecycle_plan != null:
		_append_unfinished_modules(
			unfinished_modules,
			_active_lifecycle_plan.get_shutdown_order(),
			0,
			reason
		)
	_append_topology_mutation_unfinished(
		unfinished_modules,
		_topology_mutation,
		reason
	)
	return {
		"status": status,
		"reason": reason,
		"module_results": [],
		"unfinished_modules": unfinished_modules,
	}


func _append_topology_mutation_unfinished(
	target: Array[Dictionary],
	transaction: TopologyMutation,
	reason: String
) -> void:
	if (
		transaction == null
		or transaction._candidate == null
		or transaction._outcome == TopologyMutation._OUTCOME_COMMITTED
		or transaction._candidate_cleanup_state
		!= TopologyMutation._CLEANUP_PENDING
	):
		return
	var candidate_stage: int = _GF_VARIANT_ACCESS_SCRIPT.get_option_int(
		_module_lifecycle_stages,
		transaction._candidate,
		0
	)
	var candidate_id: int = transaction._candidate.get_instance_id()
	for existing: Dictionary in target:
		if _GF_VARIANT_ACCESS_SCRIPT.get_option_int(
			existing,
			"instance_id"
		) == candidate_id:
			return
	var entry: Dictionary = _make_shutdown_module_entry(
		transaction._candidate,
		"skipped",
		"%s (topology_phase=%s, lifecycle_stage=%d)" % [
			reason,
			String(transaction._phase),
			candidate_stage,
		],
		0
	)
	target.append(entry)


func _quiesce_active_modules(
	cancellation_token: GFCancellationToken,
	deadline_msec: int
) -> Dictionary:
	var module_results: Array[Dictionary] = []
	var unfinished_modules: Array[Dictionary] = []
	var top_status: String = "succeeded"
	var top_reason: String = ""
	var lifecycle_serial: int = _runtime.get_lifecycle_generation()
	var shutdown_order: Array[Object] = []
	if _active_lifecycle_plan != null:
		shutdown_order = _active_lifecycle_plan.get_shutdown_order()
	if cancellation_token != null and cancellation_token.is_cancel_requested():
		var initial_cancel_reason: String = String(
			cancellation_token.get_cancel_reason()
		)
		_append_unfinished_modules(
			unfinished_modules,
			shutdown_order,
			0,
			"Shutdown was cancelled before module quiesce."
		)
		return {
			"status": "cancelled",
			"reason": initial_cancel_reason,
			"module_results": module_results,
			"unfinished_modules": unfinished_modules,
		}
	if deadline_msec >= 0 and Time.get_ticks_msec() >= deadline_msec:
		var initial_timeout_reason: String = (
			"Architecture shutdown deadline exceeded before module quiesce."
		)
		_append_unfinished_modules(
			unfinished_modules,
			shutdown_order,
			0,
			initial_timeout_reason
		)
		return {
			"status": "timed_out",
			"reason": initial_timeout_reason,
			"module_results": module_results,
			"unfinished_modules": unfinished_modules,
		}
	for index: int in range(shutdown_order.size()):
		var instance: Object = shutdown_order[index]
		if instance == null:
			continue
		if cancellation_token != null and cancellation_token.is_cancel_requested():
			top_status = "cancelled"
			top_reason = String(cancellation_token.get_cancel_reason())
			_append_unfinished_modules(
				unfinished_modules,
				shutdown_order,
				index,
				"Shutdown was cancelled before module quiesce."
			)
			break
		var module_started_at_msec: int = Time.get_ticks_msec()
		if deadline_msec >= 0 and module_started_at_msec >= deadline_msec:
			top_status = "timed_out"
			top_reason = "Architecture shutdown deadline exceeded."
			_append_unfinished_modules(
				unfinished_modules,
				shutdown_order,
				index,
				top_reason
			)
			break
		var completion: GFAsyncCompletion = _call_module_begin_quiesce(
			instance,
			_shutdown_scope
		)
		var allowed_instances: Dictionary = {instance: true}
		if _active_lifecycle_plan != null:
			allowed_instances = _active_lifecycle_plan.get_dependency_closure(instance)
		var wait_report: Dictionary = await _await_lifecycle_completion(
			completion,
			_shutdown_scope,
			cancellation_token,
			deadline_msec,
			allowed_instances,
			lifecycle_serial
		)
		var module_status: String = _GF_VARIANT_ACCESS_SCRIPT.get_option_string(
			wait_report,
			"status",
			"failed"
		)
		var module_reason: String = _GF_VARIANT_ACCESS_SCRIPT.get_option_string(
			wait_report,
			"reason",
			""
		)
		var module_entry: Dictionary = _make_shutdown_module_entry(
			instance,
			module_status,
			module_reason,
			Time.get_ticks_msec() - module_started_at_msec
		)
		module_results.append(module_entry)
		if module_status != "succeeded":
			unfinished_modules.append(module_entry.duplicate(true))
		if module_status == "timed_out":
			top_status = "timed_out"
			top_reason = module_reason
			_append_unfinished_modules(
				unfinished_modules,
				shutdown_order,
				index + 1,
				"Skipped after shutdown timeout."
			)
			break
		if (
			module_status == "cancelled"
			and (
				(_shutdown_scope != null and _shutdown_scope.is_cancel_requested())
				or (
					cancellation_token != null
					and cancellation_token.is_cancel_requested()
				)
			)
		):
			top_status = "cancelled"
			top_reason = module_reason
			_append_unfinished_modules(
				unfinished_modules,
				shutdown_order,
				index + 1,
				"Skipped after shutdown cancellation."
			)
			break
		if module_status != "succeeded":
			top_status = "failed"
			if top_reason.is_empty():
				top_reason = "%s failed to quiesce: %s" % [
					_get_instance_debug_key(instance),
					module_reason,
				]
	if cancellation_token != null and cancellation_token.is_cancel_requested():
		top_status = "cancelled"
		top_reason = String(cancellation_token.get_cancel_reason())
	elif deadline_msec >= 0 and Time.get_ticks_msec() >= deadline_msec:
		top_status = "timed_out"
		top_reason = "Architecture shutdown deadline exceeded."
	return {
		"status": top_status,
		"reason": top_reason,
		"module_results": module_results,
		"unfinished_modules": unfinished_modules,
	}


func _append_unfinished_modules(
	target: Array[Dictionary],
	shutdown_order: Array[Object],
	start_index: int,
	reason: String
) -> void:
	for index: int in range(start_index, shutdown_order.size()):
		var instance: Object = shutdown_order[index]
		if instance == null:
			continue
		target.append(
			_make_shutdown_module_entry(instance, "skipped", reason, 0)
		)


func _make_shutdown_module_entry(
	instance: Object,
	status: String,
	reason: String,
	duration_msec: int
) -> Dictionary:
	return {
		"kind": _get_module_label_for_instance(instance),
		"script": _get_instance_debug_key(instance),
		"instance_id": instance.get_instance_id() if instance != null else 0,
		"status": status,
		"reason": reason,
		"duration_msec": maxi(duration_msec, 0),
	}


func _make_shutdown_result(
	report: Dictionary,
	started_at_msec: int,
	completed_at_msec: int
) -> GFArchitectureShutdownResult:
	var status_name: String = _GF_VARIANT_ACCESS_SCRIPT.get_option_string(
		report,
		"status",
		"failed"
	)
	var reason: String = _GF_VARIANT_ACCESS_SCRIPT.get_option_string(
		report,
		"reason",
		"Architecture shutdown failed."
	)
	var module_results: Array[Dictionary] = _get_shutdown_report_entries(
		report,
		"module_results"
	)
	var unfinished_modules: Array[Dictionary] = _get_shutdown_report_entries(
		report,
		"unfinished_modules"
	)
	var status: GFArchitectureShutdownResult.Status = (
		GFArchitectureShutdownResult.Status.SUCCEEDED
	)
	var error_code: Error = OK
	var cancel_reason: String = ""
	match status_name:
		"succeeded":
			status = GFArchitectureShutdownResult.Status.SUCCEEDED
		"cancelled":
			status = GFArchitectureShutdownResult.Status.CANCELLED
			error_code = ERR_SKIP
			cancel_reason = reason
		"timed_out":
			status = GFArchitectureShutdownResult.Status.TIMED_OUT
			error_code = ERR_TIMEOUT
		_:
			status = GFArchitectureShutdownResult.Status.FAILED
			error_code = FAILED
	return _GF_ARCHITECTURE_SHUTDOWN_RESULT_SCRIPT.create(
		status,
		started_at_msec,
		completed_at_msec,
		module_results,
		unfinished_modules,
		_shutdown_duplicate_request_count,
		error_code,
		reason,
		cancel_reason
	)


func _get_shutdown_report_entries(
	report: Dictionary,
	key: String
) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var raw_entries: Variant = report.get(key, [])
	if not raw_entries is Array:
		return result
	for raw_entry: Variant in raw_entries:
		if raw_entry is Dictionary:
			var entry: Dictionary = raw_entry
			result.append(entry)
	return result


func _snapshot_forced_unfinished_modules(
	reason: String
) -> Array[Dictionary]:
	var unfinished_modules: Array[Dictionary] = []
	var seen_instances: Dictionary = {}
	var snapshot_plan: GFArchitectureLifecyclePlan = (
		_active_lifecycle_plan
		if _active_lifecycle_plan != null
		else _lifecycle_plan_in_progress
	)
	if snapshot_plan != null:
		for instance: Object in snapshot_plan.get_shutdown_order():
			if instance == null or seen_instances.has(instance):
				continue
			var lifecycle_stage: int = (
				_GF_VARIANT_ACCESS_SCRIPT.get_option_int(
					_module_lifecycle_stages,
					instance,
					0
				)
			)
			if lifecycle_stage <= 0:
				continue
			seen_instances[instance] = true
			unfinished_modules.append(
				_make_shutdown_module_entry(
					instance,
					"skipped",
					"%s (lifecycle_stage=%d)" % [
						reason,
						lifecycle_stage,
					],
					0
				)
			)
	_append_topology_mutation_unfinished(
		unfinished_modules,
		_topology_mutation,
		reason
	)
	return unfinished_modules


func _force_dispose_internal() -> void:
	_fail_active_factory_resolution_contexts()
	if not _runtime.begin_dispose():
		return
	var disposed_instances: Dictionary = _begin_module_disposal_session()
	var aborted_topology: TopologyMutation = _abort_topology_mutation(
		&"architecture_disposed"
	)
	if (
		aborted_topology != null
		and aborted_topology._active_scope != null
		and aborted_topology._active_scope.is_active()
	):
		var _cancelled_topology_scope: bool = (
			aborted_topology._active_scope.cancel(
				"[GFArchitecture] 架构已 dispose。"
			)
		)
	_cancel_active_async_scopes("[GFArchitecture] 架构已 dispose。")
	_cleanup_topology_candidate(aborted_topology)
	_finalize_aborted_topology_mutation(
		aborted_topology,
		&"architecture_disposed"
	)
	_lifecycle_hook_depth += 1
	_on_dispose()
	_lifecycle_hook_depth -= 1
	var disposal_plan: GFArchitectureLifecyclePlan = (
		_active_lifecycle_plan
		if _active_lifecycle_plan != null
		else _lifecycle_plan_in_progress
	)
	if disposal_plan != null:
		for instance: Object in disposal_plan.get_shutdown_order():
			_dispose_module_once(instance, disposed_instances)
	for instance: Object in _get_modules_by_lifecycle_priority(
		_system_registry.instances,
		true
	):
		_dispose_module_once(instance, disposed_instances)
	for instance: Object in _get_modules_by_lifecycle_priority(
		_model_registry.instances,
		true
	):
		_dispose_module_once(instance, disposed_instances)
	for instance: Object in _get_modules_by_lifecycle_priority(
		_utility_registry.instances,
		true
	):
		_dispose_module_once(instance, disposed_instances)
	for binding_variant: Variant in _factories.values():
		var binding: GFBinding = _variant_to_binding(binding_variant)
		if binding != null:
			binding.dispose_cached_instance()
	_model_registry._clear()
	_system_registry._clear()
	_utility_registry._clear()
	_factories.clear()
	_module_lifecycle_stages.clear()
	_services.clear()
	_event_system.clear()
	_time_provider = null
	last_initialization_error = ""
	_reset_project_installers()
	_active_lifecycle_plan = null
	_lifecycle_plan_in_progress = null
	_activation_scope = null
	_shutdown_scope = null
	_refresh_tick_caches()
	_release_external_dependency_leases(
		_active_external_dependency_leases
	)
	_active_external_dependency_leases.clear()
	_child_external_dependency_leases.clear()
	_parent_architecture = null
	_runtime.finish_dispose()
	_end_module_disposal_session()


func _dispose_module_once(
	instance: Object,
	disposed_instances: Dictionary
) -> void:
	if instance == null or disposed_instances.has(instance):
		return
	disposed_instances[instance] = true
	_event_system.unregister_owner(instance)
	_unregister_services_for_owner(instance)
	_call_module_dispose(instance)
	_release_module_dependencies(instance)


func _begin_module_disposal_session() -> Dictionary:
	_module_disposal_session_depth += 1
	return _module_disposal_claims


func _end_module_disposal_session() -> void:
	_module_disposal_session_depth = maxi(
		_module_disposal_session_depth - 1,
		0
	)
	if _module_disposal_session_depth == 0:
		_module_disposal_claims.clear()


func _publish_shutdown_result(result: GFArchitectureShutdownResult) -> void:
	if result == null:
		return
	if _shutdown_completion == null:
		_shutdown_completion = GFAsyncCompletion.new()
	elif not _shutdown_completion.is_pending():
		return
	_last_shutdown_result = result.duplicate_result()
	if _shutdown_completion.is_pending():
		var _completed_shutdown: bool = _shutdown_completion.succeed(
			result.duplicate_result()
		)
	shutdown_finished.emit(result.duplicate_result())


func _all_registered_modules_reached_stage(target_stage: int) -> bool:
	return (
		_module_registry_reached_stage(_model_registry, target_stage)
		and _module_registry_reached_stage(_utility_registry, target_stage)
		and _module_registry_reached_stage(_system_registry, target_stage)
	)


func _module_registry_reached_stage(module_registry: ModuleRegistry, target_stage: int) -> bool:
	for instance: Object in module_registry.instances.values():
		var current_stage: int = _GF_VARIANT_ACCESS_SCRIPT.get_option_int(_module_lifecycle_stages, instance, 0)
		if current_stage < target_stage:
			return false
	return true


func _advance_module_to_stage(
	module_registry: ModuleRegistry,
	instance: Object,
	target_stage: int,
	lifecycle_serial: int,
	cancellation_token: GFCancellationToken = null
) -> bool:
	if instance == null:
		return false

	var current_stage: int = _GF_VARIANT_ACCESS_SCRIPT.get_option_int(_module_lifecycle_stages, instance, 0)
	while current_stage < target_stage:
		if not _is_lifecycle_current(lifecycle_serial) or _runtime.has_failed():
			return false
		if not _module_registry_contains_instance(module_registry, instance):
			return false

		current_stage += 1
		_bind_dependency_scope_if_needed(instance, lifecycle_serial)
		match current_stage:
			1:
				_call_module_init(instance)
			2:
				var async_completed: bool = await _await_module_async_init(
					instance,
					lifecycle_serial,
					cancellation_token
				)
				if not async_completed:
					return false
			3:
				_call_module_ready(instance)

		if not _is_lifecycle_current(lifecycle_serial) or _runtime.has_failed():
			return false
		if not _module_registry_contains_instance(module_registry, instance):
			return false

		_module_lifecycle_stages[instance] = current_stage
	return current_stage >= target_stage


func _await_module_async_init(
	instance: Object,
	lifecycle_serial: int,
	cancellation_token: GFCancellationToken = null
) -> bool:
	var async_scope: GFAsyncScope = _begin_module_async_scope()
	var scene_tree: SceneTree = _get_scene_tree_or_null()
	if scene_tree == null:
		if cancellation_token != null and cancellation_token.is_cancel_requested():
			var pre_cancel_reason: String = String(
				cancellation_token.get_cancel_reason()
			)
			_cancel_module_async_scope(async_scope, pre_cancel_reason)
			_fail_initialization(
				"[GFArchitecture] 初始化已取消：%s。" % pre_cancel_reason,
				lifecycle_serial
			)
			return false
		await _call_module_async_init(instance, async_scope)
		if cancellation_token != null and cancellation_token.is_cancel_requested():
			var post_cancel_reason: String = String(
				cancellation_token.get_cancel_reason()
			)
			_cancel_module_async_scope(async_scope, post_cancel_reason)
			_fail_initialization(
				"[GFArchitecture] 初始化已取消：%s。" % post_cancel_reason,
				lifecycle_serial
			)
			return false
		return _complete_module_async_scope(async_scope, lifecycle_serial)

	var completion_state: Dictionary = {
		"done": false,
		"write_blocked": false,
	}
	_GF_ASYNC_CALL_SCRIPT.run_detached(Callable(self, &"_complete_module_async_init"), [instance, completion_state, async_scope])
	var start_msec: int = Time.get_ticks_msec()
	var timeout_msec: int = (
		int(module_async_init_timeout_seconds * 1000.0)
		if module_async_init_timeout_seconds > 0.0
		else -1
	)
	while not _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(completion_state, "done", false):
		if not _is_lifecycle_current(lifecycle_serial) or _runtime.has_failed():
			_cancel_module_async_scope(async_scope, last_initialization_error)
			return false
		if cancellation_token != null and cancellation_token.is_cancel_requested():
			var cancel_reason: String = String(
				cancellation_token.get_cancel_reason()
			)
			_cancel_module_async_scope(async_scope, cancel_reason)
			_fail_initialization(
				"[GFArchitecture] 初始化已取消：%s。" % cancel_reason,
				lifecycle_serial
			)
			return false
		if async_scope.is_cancel_requested():
			return false
		var elapsed_msec: int = Time.get_ticks_msec() - start_msec
		if timeout_msec >= 0 and elapsed_msec >= timeout_msec:
			completion_state["write_blocked"] = true
			_begin_stale_async_write_block()
			var timeout_reason: String = "[GFArchitecture] async_init 超时：%s 超过 %.2f 秒。" % [
				_get_instance_debug_key(instance),
				module_async_init_timeout_seconds,
			]
			_cancel_module_async_scope(async_scope, timeout_reason)
			_fail_initialization(timeout_reason, lifecycle_serial)
			return false
		await scene_tree.process_frame
	return _complete_module_async_scope(async_scope, lifecycle_serial)


func _complete_module_async_init(instance: Object, completion_state: Dictionary, async_scope: GFAsyncScope) -> void:
	await _call_module_async_init(instance, async_scope)
	if _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(completion_state, "write_blocked", false):
		_end_stale_async_write_block()
	_untrack_async_scope(async_scope)
	completion_state["done"] = true


func _fail_initialization(reason: String, lifecycle_serial: int) -> void:
	if not _runtime.fail_initialization(lifecycle_serial):
		return

	_initialization_failure_settlement_in_progress = true
	_fail_active_factory_resolution_contexts()
	last_initialization_error = reason
	_cancel_active_async_scopes(reason)
	var installers_were_running: bool = _stop_project_installers_after_failure()
	_clear_failed_initialization_state()
	if installers_were_running:
		project_installers_finished.emit()
	push_error(reason)
	initialization_failed.emit(reason)
	initialization_finished.emit()
	_initialization_failure_settlement_in_progress = false


func _track_registered_module(instance: Object) -> void:
	if instance == null:
		return
	if not _module_lifecycle_stages.has(instance):
		_module_lifecycle_stages[instance] = 0


func _module_registry_contains_instance(module_registry: ModuleRegistry, instance: Object) -> bool:
	if instance == null:
		return false
	return module_registry._get_key_for_instance(instance) != null


func _register_module(module_registry: ModuleRegistry, script_cls: Script, instance: Object) -> bool:
	return (
		_register_module_checked(module_registry, script_cls, instance)
		== _REQUIRED_REGISTRATION_ACCEPTED
	)


func _register_module_checked(
	module_registry: ModuleRegistry,
	script_cls: Script,
	instance: Object
) -> int:
	var _disposal_claims: Dictionary = _begin_module_disposal_session()
	var outcome: int = _register_module_checked_in_disposal_session(
		module_registry,
		script_cls,
		instance
	)
	_end_module_disposal_session()
	return outcome


func _register_module_checked_in_disposal_session(
	module_registry: ModuleRegistry,
	script_cls: Script,
	instance: Object
) -> int:
	if not _can_mutate_registration_state("register_%s" % module_registry._label_key()):
		return _REQUIRED_REGISTRATION_REJECTED_CALLER_OWNS
	if not _validate_registration(script_cls, instance, module_registry.label):
		return _REQUIRED_REGISTRATION_REJECTED_CALLER_OWNS
	if module_registry._has_direct(script_cls):
		var method_name: String = "register_%s" % module_registry._label_key()
		var replacement_name: String = "replace_%s" % module_registry._label_key()
		push_warning("[GFArchitecture] %s：类型已注册，已忽略重复注册。启用扩展的 Installer 会先于项目 Installer 自动装配其模块；项目通常只注册自身模块。若需要替换，请使用 %s()。" % [
			method_name,
			replacement_name,
		])
		var registered_instance: Object = _get_dictionary_object(
			module_registry.instances,
			script_cls
		)
		if (
			registered_instance == instance
			or module_registry._get_key_for_instance(instance) != null
		):
			return _REQUIRED_REGISTRATION_REJECTED_ARCHITECTURE_OWNS
		return _REQUIRED_REGISTRATION_REJECTED_CALLER_OWNS

	var existing_key: Script = module_registry._get_key_for_instance(instance)
	if existing_key != null:
		push_error("[GFArchitecture] register_%s 失败：同一实例已注册为 %s，禁止用多个脚本键重复注册同一模块。" % [
			module_registry._label_key(),
			_get_script_debug_key(existing_key, instance),
		])
		return _REQUIRED_REGISTRATION_REJECTED_ARCHITECTURE_OWNS

	var transaction: Dictionary = _runtime.begin_transaction("register_%s" % module_registry._label_key())
	var injected_dependencies: bool = _inject_dependencies_if_needed(
		instance,
		_get_active_lifecycle_serial_or_unbound()
	)
	if not injected_dependencies:
		_cleanup_registration_candidate_if_unretained(instance)
		_runtime.finish_transaction(transaction)
		return _REQUIRED_REGISTRATION_REJECTED_ARCHITECTURE_SETTLED
	if _module_disposal_claims.has(instance):
		_runtime.finish_transaction(transaction)
		return _REQUIRED_REGISTRATION_REJECTED_ARCHITECTURE_SETTLED
	if not _registration_candidate_is_live(instance):
		_runtime.finish_transaction(transaction)
		return _REQUIRED_REGISTRATION_REJECTED_ARCHITECTURE_SETTLED
	if not _required_plan_candidate_matches_declaration(
		module_registry,
		script_cls,
		instance
	):
		_cleanup_registration_candidate_if_unretained(instance)
		_runtime.finish_transaction(transaction)
		return _REQUIRED_REGISTRATION_REJECTED_ARCHITECTURE_SETTLED
	if _runtime.is_transaction_invalidated(transaction):
		push_error("[GFArchitecture] register_%s 失败：依赖注入期间注册事务已失效。" % module_registry._label_key())
		_cleanup_registration_candidate_if_unretained(instance)
		_runtime.finish_transaction(transaction)
		return _REQUIRED_REGISTRATION_REJECTED_ARCHITECTURE_SETTLED
	if not _can_mutate_registration_state("register_%s" % module_registry._label_key()):
		_cleanup_registration_candidate_if_unretained(instance)
		_runtime.finish_transaction(transaction)
		return _REQUIRED_REGISTRATION_REJECTED_ARCHITECTURE_SETTLED
	if module_registry._has_direct(script_cls):
		var reentrant_instance: Object = _get_dictionary_object(module_registry.instances, script_cls)
		_runtime.finish_transaction(transaction)
		if reentrant_instance == instance:
			return _REQUIRED_REGISTRATION_ACCEPTED
		push_error("[GFArchitecture] register_%s 失败：依赖注入期间同一脚本键已被重入注册。" % module_registry._label_key())
		_cleanup_registration_candidate_if_unretained(instance)
		return _REQUIRED_REGISTRATION_REJECTED_ARCHITECTURE_SETTLED
	var reentrant_key: Script = module_registry._get_key_for_instance(instance)
	if reentrant_key != null:
		_runtime.finish_transaction(transaction)
		push_error("[GFArchitecture] register_%s 失败：依赖注入期间同一实例已被重入注册。" % module_registry._label_key())
		return _REQUIRED_REGISTRATION_REJECTED_ARCHITECTURE_OWNS
	module_registry.instances[script_cls] = instance
	module_registry._track_instance_key(instance, script_cls)
	module_registry._clear_assignable_cache()
	_track_registered_module(instance)
	_runtime.finish_transaction(transaction)
	return _REQUIRED_REGISTRATION_ACCEPTED


func _register_required_plan_module(
	module_registry: ModuleRegistry,
	script_cls: Script,
	instance: Object,
	release_owned_candidate_on_rejection: bool
) -> Error:
	var _disposal_claims: Dictionary = _begin_module_disposal_session()
	var registration_error: Error = _register_required_plan_module_in_disposal_session(
		module_registry,
		script_cls,
		instance,
		release_owned_candidate_on_rejection
	)
	_end_module_disposal_session()
	return registration_error


func _register_required_plan_module_in_disposal_session(
	module_registry: ModuleRegistry,
	script_cls: Script,
	instance: Object,
	release_owned_candidate_on_rejection: bool
) -> Error:
	if _module_disposal_claims.has(instance):
		return ERR_CANT_CREATE
	if script_cls == null:
		if (
			release_owned_candidate_on_rejection
			and instance != null
			and is_instance_valid(instance)
		):
			_cleanup_required_source_owned_candidate(instance)
		return ERR_INVALID_PARAMETER
	if not _registration_candidate_is_live(instance):
		return ERR_INVALID_DATA
	if not _required_plan_candidate_matches_declaration(
		module_registry,
		script_cls,
		instance
	):
		if release_owned_candidate_on_rejection:
			_cleanup_required_source_owned_candidate(instance)
		return ERR_INVALID_DATA
	var outcome: int = _register_module_checked(
		module_registry,
		script_cls,
		instance
	)
	if outcome == _REQUIRED_REGISTRATION_ACCEPTED:
		return OK
	if (
		outcome == _REQUIRED_REGISTRATION_REJECTED_CALLER_OWNS
		and release_owned_candidate_on_rejection
	):
		_cleanup_required_source_owned_candidate(instance)
	return ERR_CANT_CREATE


func _required_plan_candidate_matches_declaration(
	module_registry: ModuleRegistry,
	script_cls: Script,
	instance: Object
) -> bool:
	if not _instance_matches_registration_label(instance, module_registry.label):
		return false
	var instance_script: Script = _get_instance_script(instance)
	if instance_script == null:
		return false
	return GFScriptTypeInspector.script_extends_or_equals(
		instance_script,
		script_cls
	)


func _cleanup_registration_candidate_if_unretained(instance: Object) -> void:
	if _required_plan_candidate_is_retained_by_architecture(instance):
		return
	_cleanup_uncommitted_module(instance)


func _cleanup_required_source_owned_candidate(instance: Object) -> void:
	if not _registration_candidate_is_live(instance):
		return
	if _required_plan_candidate_is_retained_by_architecture(instance):
		return
	var disposed_instances: Dictionary = (
		_module_disposal_claims
		if _module_disposal_session_depth > 0
		else {}
	)
	if disposed_instances.has(instance):
		return
	disposed_instances[instance] = true
	_event_system.unregister_owner(instance)
	_unregister_services_for_owner(instance)
	var _removed_stage: bool = _module_lifecycle_stages.erase(instance)
	_lifecycle_hook_depth += 1
	if instance.has_method("dispose"):
		var _dispose_result: Variant = instance.call("dispose")
	_lifecycle_hook_depth -= 1
	if not is_instance_valid(instance):
		return
	_release_module_dependencies(instance)
	if not is_instance_valid(instance):
		return
	if instance is Node:
		var rejected_node: Node = instance
		if (
			rejected_node.get_parent() == null
			and not rejected_node.is_queued_for_deletion()
		):
			rejected_node.free()
		return
	if not instance is RefCounted:
		instance.free()


func _required_plan_candidate_is_retained_by_architecture(instance: Object) -> bool:
	if _get_module_registry_for_instance(instance) != null:
		return true
	for binding_variant: Variant in _factories.values():
		var binding: GFBinding = _variant_to_binding(binding_variant)
		if binding != null and binding.retains_instance_for_framework(instance):
			return true
	return false


func _register_required_plan_alias(
	module_registry: ModuleRegistry,
	alias_cls: Script,
	target_cls: Script
) -> bool:
	if alias_cls == null or target_cls == null:
		return false
	if not GFScriptTypeInspector.script_extends_or_equals(target_cls, alias_cls):
		return false
	if module_registry._has_direct(alias_cls):
		return alias_cls == target_cls
	if module_registry.aliases.has(alias_cls):
		return (
			_get_dictionary_script(module_registry.aliases, alias_cls)
			== target_cls
		)
	return _register_module_alias(module_registry, alias_cls, target_cls)


func _replace_module(module_registry: ModuleRegistry, script_cls: Script, instance: Object) -> bool:
	if not _can_mutate_registration_state("replace_%s" % module_registry._label_key()):
		return false
	if not _validate_registration(script_cls, instance, module_registry.label):
		return false

	var existing_key: Script = module_registry._get_key_for_instance(instance)
	if existing_key != null and existing_key != script_cls:
		push_error("[GFArchitecture] replace_%s 失败：同一实例已注册为 %s，不能同时替换到其它脚本键。" % [
			module_registry._label_key(),
			_get_script_debug_key(existing_key, instance),
		])
		return false

	var current_instance: Object = _get_dictionary_object(module_registry.instances, script_cls)
	if current_instance == instance:
		return true

	if _runtime.is_ready():
		return await _replace_initialized_module(module_registry, script_cls, instance)

	return _replace_uninitialized_module(
		module_registry,
		script_cls,
		instance,
		current_instance
	)


func _replace_uninitialized_module(
	module_registry: ModuleRegistry,
	script_cls: Script,
	instance: Object,
	current_instance: Object
) -> bool:
	var transaction: Dictionary = _runtime.begin_transaction("replace_%s" % module_registry._label_key())
	var injected_dependencies: bool = _inject_dependencies_if_needed(
		instance,
		_get_active_lifecycle_serial_or_unbound()
	)
	if not injected_dependencies:
		_cleanup_uncommitted_module_if_unregistered(module_registry, instance)
		_runtime.finish_transaction(transaction)
		return false
	if _runtime.is_transaction_invalidated(transaction):
		_cleanup_uncommitted_module_if_unregistered(module_registry, instance)
		_runtime.finish_transaction(transaction)
		return false
	if not _can_mutate_registration_state("replace_%s" % module_registry._label_key()):
		_cleanup_uncommitted_module_if_unregistered(module_registry, instance)
		_runtime.finish_transaction(transaction)
		return false
	if _get_dictionary_object(module_registry.instances, script_cls) != current_instance:
		_cleanup_uncommitted_module_if_unregistered(module_registry, instance)
		_runtime.finish_transaction(transaction)
		return false
	if module_registry._get_key_for_instance(instance) != null:
		_runtime.finish_transaction(transaction)
		return false

	if current_instance != null:
		var _removed_current_instance: Object = _remove_registered_module(
			module_registry,
			script_cls,
			true,
			false
		)
	if _runtime.is_transaction_invalidated(transaction):
		_cleanup_uncommitted_module_if_unregistered(module_registry, instance)
		_runtime.finish_transaction(transaction)
		return false
	if not _can_mutate_registration_state("replace_%s" % module_registry._label_key()):
		_cleanup_uncommitted_module_if_unregistered(module_registry, instance)
		_runtime.finish_transaction(transaction)
		return false
	if (
		module_registry._has_direct(script_cls)
		or module_registry._get_key_for_instance(instance) != null
	):
		_cleanup_uncommitted_module_if_unregistered(module_registry, instance)
		_runtime.finish_transaction(transaction)
		return false

	module_registry.instances[script_cls] = instance
	module_registry._track_instance_key(instance, script_cls)
	module_registry._clear_assignable_cache()
	_track_registered_module(instance)
	_runtime.finish_transaction(transaction)
	return true


func _replace_initialized_module(module_registry: ModuleRegistry, script_cls: Script, instance: Object) -> bool:
	var previous_instance: Object = _get_dictionary_object(module_registry.instances, script_cls)
	var topology_transaction: TopologyMutation = _begin_topology_mutation(
		&"replace",
		module_registry,
		script_cls,
		instance,
		previous_instance
	)
	if topology_transaction == null:
		return false
	var previous_plan: GFArchitectureLifecyclePlan = _active_lifecycle_plan
	topology_transaction._previous_plan = previous_plan
	var transaction: Dictionary = _runtime.begin_transaction(
		"replace_%s" % module_registry._label_key()
	)
	var lifecycle_serial: int = _runtime.get_lifecycle_generation()
	topology_transaction._lifecycle_serial = lifecycle_serial
	topology_transaction._candidate_cleanup_state = (
		TopologyMutation._CLEANUP_PENDING
	)
	var candidate_models: Dictionary = _models.duplicate()
	var candidate_utilities: Dictionary = _utilities.duplicate()
	var candidate_systems: Dictionary = _systems.duplicate()
	var candidate_registry: Dictionary = _get_candidate_registry_dictionary(
		module_registry,
		candidate_models,
		candidate_utilities,
		candidate_systems
	)
	candidate_registry[script_cls] = instance
	var candidate_plan: GFArchitectureLifecyclePlan = (
		_compile_candidate_lifecycle_plan(
			candidate_models,
			candidate_utilities,
			candidate_systems,
			"hot replace",
			true,
			_create_lifecycle_plan_validity_guard(
				lifecycle_serial,
				topology_transaction,
				transaction
			)
		)
	)
	if (
		candidate_plan == null
		or not _is_topology_mutation_current(topology_transaction)
		or not _is_lifecycle_current(lifecycle_serial)
		or not _runtime.is_ready()
		or _runtime.has_failed()
		or _runtime.is_transaction_invalidated(transaction)
	):
		_rollback_topology_candidate(
			topology_transaction,
			transaction
		)
		return false
	var excluded_instances: Dictionary = {}
	if previous_instance != null:
		excluded_instances[previous_instance] = true
	if not _validate_candidate_plan_stability(
		previous_plan,
		candidate_plan,
		excluded_instances,
		"hot replace"
	):
		_rollback_topology_candidate(
			topology_transaction,
			transaction
		)
		return false
	topology_transaction._candidate_plan = candidate_plan
	if not _stage_topology_external_dependency_leases(
		topology_transaction,
		candidate_plan,
		lifecycle_serial
	):
		_rollback_topology_candidate(
			topology_transaction,
			transaction
		)
		return false
	_module_lifecycle_stages[instance] = 0
	var prepared: bool = await _prepare_replacement_module(instance, lifecycle_serial)
	if (
		not prepared
		or not _is_topology_mutation_current(topology_transaction)
	):
		_rollback_topology_candidate(topology_transaction, transaction)
		return false
	if (
		not _is_lifecycle_current(lifecycle_serial)
		or _runtime.has_failed()
		or _runtime.is_transaction_invalidated(transaction)
	):
		_rollback_topology_candidate(topology_transaction, transaction)
		return false
	if _get_dictionary_object(module_registry.instances, script_cls) != previous_instance:
		_rollback_topology_candidate(topology_transaction, transaction)
		return false
	if module_registry._get_key_for_instance(instance) != null:
		_rollback_topology_candidate(topology_transaction, transaction)
		return false
	_module_lifecycle_stages[instance] = 2
	_call_module_ready(instance)
	if (
		not _is_lifecycle_current(lifecycle_serial)
		or _runtime.has_failed()
		or _runtime.is_transaction_invalidated(transaction)
		or not _is_topology_mutation_current(topology_transaction)
	):
		_rollback_topology_candidate(topology_transaction, transaction)
		return false
	_module_lifecycle_stages[instance] = 3
	topology_transaction._phase = TopologyMutation._PHASE_ACTIVATING
	var activated: bool = await _activate_topology_candidate(
		instance,
		candidate_plan,
		lifecycle_serial,
		true,
		topology_transaction
	)
	if (
		not activated
		or not _is_topology_mutation_current(topology_transaction)
		or not _is_lifecycle_current(lifecycle_serial)
		or _runtime.is_transaction_invalidated(transaction)
	):
		_rollback_topology_candidate(topology_transaction, transaction)
		return false
	if not _validate_topology_service_intents(topology_transaction):
		_rollback_topology_candidate(topology_transaction, transaction)
		return false
	topology_transaction._phase = (
		TopologyMutation._PHASE_QUIESCING_PREVIOUS
	)
	if (
		previous_instance != null
		and not await _quiesce_topology_module(
			previous_instance,
			previous_plan,
			lifecycle_serial,
			topology_transaction
		)
	):
		_cleanup_topology_candidate(topology_transaction)
		_runtime.finish_transaction(transaction)
		if _runtime.is_ready():
			dispose()
		else:
			_fail_topology_mutation(
				topology_transaction,
				"Accepted topology replacement failed while quiescing the previous module."
			)
		return false
	if not _is_topology_mutation_current(topology_transaction):
		_rollback_topology_candidate(topology_transaction, transaction)
		return false
	if not _validate_topology_service_intents(topology_transaction):
		_cleanup_topology_candidate(topology_transaction)
		_runtime.finish_transaction(transaction)
		dispose()
		return false
	topology_transaction._phase = TopologyMutation._PHASE_COMMITTING
	if previous_instance != null:
		module_registry._untrack_instance(previous_instance)
		var _detached_previous_instance: bool = (
			module_registry.instances.erase(script_cls)
		)
	module_registry.instances[script_cls] = instance
	module_registry._track_instance_key(instance, script_cls)
	module_registry._clear_assignable_cache()
	_commit_topology_service_intents(topology_transaction)
	_promote_topology_external_dependency_leases(
		topology_transaction
	)
	_active_lifecycle_plan = candidate_plan
	topology_transaction._candidate_cleanup_state = (
		TopologyMutation._CLEANUP_TRANSFERRED
	)
	topology_transaction._outcome = TopologyMutation._OUTCOME_COMMITTED
	topology_transaction._phase = (
		TopologyMutation._PHASE_CLEANING_DETACHED
	)
	if previous_instance != null:
		_cleanup_uncommitted_module(previous_instance)
	if (
		not _is_lifecycle_current(lifecycle_serial)
		or _runtime.is_transaction_invalidated(transaction)
		or not _is_topology_mutation_current(topology_transaction)
	):
		_runtime.finish_transaction(transaction)
		_fail_topology_mutation(
			topology_transaction,
			"Accepted topology replacement was invalidated during detached cleanup."
		)
		return false
	topology_transaction._phase = TopologyMutation._PHASE_COMMITTED
	_refresh_cached_utility_refs()
	_refresh_tick_caches()
	_runtime.finish_transaction(transaction)
	_finish_topology_mutation(topology_transaction)
	return true


func _get_candidate_registry_dictionary(
	module_registry: ModuleRegistry,
	model_instances: Dictionary,
	utility_instances: Dictionary,
	system_instances: Dictionary
) -> Dictionary:
	if module_registry == _model_registry:
		return model_instances
	if module_registry == _utility_registry:
		return utility_instances
	if module_registry == _system_registry:
		return system_instances
	return {}


func _quiesce_topology_module(
	instance: Object,
	plan: GFArchitectureLifecyclePlan,
	lifecycle_serial: int,
	topology_transaction: TopologyMutation = null
) -> bool:
	if instance == null:
		return true
	var scope: GFAsyncScope = _begin_module_async_scope()
	if _is_topology_mutation_current(topology_transaction):
		topology_transaction._active_scope = scope
	var deadline_msec: int = _make_deadline_msec(
		Time.get_ticks_msec(),
		shutdown_timeout_seconds
	)
	var completion: GFAsyncCompletion = _call_module_begin_quiesce(
		instance,
		scope
	)
	var allowed_instances: Dictionary = {instance: true}
	if plan != null:
		allowed_instances = plan.get_dependency_closure(instance)
	var wait_report: Dictionary = await _await_lifecycle_completion(
		completion,
		scope,
		null,
		deadline_msec,
		allowed_instances,
		lifecycle_serial
	)
	var succeeded: bool = _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(
		wait_report,
		"succeeded",
		false
	)
	if not succeeded:
		push_error(
			"[GFArchitecture] 模块拓扑事务 quiesce 失败：%s：%s" % [
				_get_instance_debug_key(instance),
				_GF_VARIANT_ACCESS_SCRIPT.get_option_string(
					wait_report,
					"reason",
					"quiesce failed"
				),
			]
		)
	if scope.is_active():
		scope.complete()
	_untrack_async_scope(scope)
	if (
		topology_transaction != null
		and topology_transaction._active_scope == scope
	):
		topology_transaction._active_scope = null
	return succeeded


func _cleanup_uncommitted_module_if_unregistered(
	module_registry: ModuleRegistry,
	instance: Object
) -> void:
	if _module_registry_contains_instance(module_registry, instance):
		return
	_cleanup_uncommitted_module(instance)


func _cleanup_uncommitted_module(instance: Object) -> void:
	if not _registration_candidate_is_live(instance):
		return
	var disposed_instances: Dictionary = (
		_module_disposal_claims
		if _module_disposal_session_depth > 0
		else {}
	)
	_dispose_module_once(instance, disposed_instances)
	var _removed_stage: bool = _module_lifecycle_stages.erase(instance)


func _prepare_replacement_module(instance: Object, lifecycle_serial: int) -> bool:
	if not _inject_dependencies_if_needed(instance, lifecycle_serial):
		return false
	_call_module_init(instance)
	if not _is_lifecycle_current(lifecycle_serial) or _runtime.has_failed():
		return false
	var async_initialized: bool = await _await_replacement_module_async_init(instance, lifecycle_serial)
	if not async_initialized:
		return false
	if not _is_lifecycle_current(lifecycle_serial) or _runtime.has_failed():
		return false
	_bind_dependency_scope_if_needed(instance, lifecycle_serial)
	return _is_lifecycle_current(lifecycle_serial) and not _runtime.has_failed()


func _await_replacement_module_async_init(instance: Object, lifecycle_serial: int) -> bool:
	var async_scope: GFAsyncScope = _begin_module_async_scope()
	if module_async_init_timeout_seconds <= 0.0:
		await _call_module_async_init(instance, async_scope)
		return _complete_module_async_scope(async_scope, lifecycle_serial)

	var scene_tree: SceneTree = _get_scene_tree_or_null()
	if scene_tree == null:
		await _call_module_async_init(instance, async_scope)
		return _complete_module_async_scope(async_scope, lifecycle_serial)

	var completion_state: Dictionary = {
		"done": false,
		"write_blocked": false,
	}
	_GF_ASYNC_CALL_SCRIPT.run_detached(Callable(self, &"_complete_replacement_module_async_init"), [instance, completion_state, async_scope])
	var start_msec: int = Time.get_ticks_msec()
	var timeout_msec: int = int(module_async_init_timeout_seconds * 1000.0)
	while not _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(completion_state, "done", false):
		if not _is_lifecycle_current(lifecycle_serial) or _runtime.has_failed():
			_cancel_module_async_scope(async_scope, last_initialization_error)
			return false
		var elapsed_msec: int = Time.get_ticks_msec() - start_msec
		if elapsed_msec >= timeout_msec:
			completion_state["write_blocked"] = true
			_begin_stale_async_write_block()
			push_error("[GFArchitecture] replace_%s 超时：%s 的 async_init() 超过 %.2f 秒，已保留旧实例。" % [
				_get_module_label_for_instance(instance),
				_get_instance_debug_key(instance),
				module_async_init_timeout_seconds,
			])
			_cancel_module_async_scope(async_scope, "[GFArchitecture] replace_%s 超时。" % _get_module_label_for_instance(instance))
			return false
		await scene_tree.process_frame
	return _complete_module_async_scope(async_scope, lifecycle_serial)


func _complete_replacement_module_async_init(instance: Object, completion_state: Dictionary, async_scope: GFAsyncScope) -> void:
	await _call_module_async_init(instance, async_scope)
	if _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(completion_state, "write_blocked", false):
		_end_stale_async_write_block()
	_untrack_async_scope(async_scope)
	completion_state["done"] = true


func _can_mutate_registration_state(context: String) -> bool:
	if _runtime.is_disposed() or _runtime.is_disposing():
		push_error("[GFArchitecture] %s 失败：架构已 dispose，不能继续修改注册表。" % context)
		return false
	if _runtime.is_quiescing():
		push_error("[GFArchitecture] %s 失败：架构正在 quiesce，注册表已经冻结。" % context)
		return false
	if _runtime.has_failed():
		push_error("[GFArchitecture] %s 失败：架构初始化已失败，已拒绝迟到写入。" % context)
		return false
	if _stale_async_write_block_count > 0:
		push_error("[GFArchitecture] %s 失败：架构存在已超时的异步流程尚未结束，已拒绝迟到写入。" % context)
		return false
	if _runtime.is_initializing():
		push_error("[GFArchitecture] %s 失败：生命周期计划已经冻结，初始化期间禁止修改注册表。" % context)
		return false
	if _runtime.is_activating():
		push_error("[GFArchitecture] %s 失败：架构正在 activation，注册表已经冻结。" % context)
		return false
	if not _factory_resolution_context_stack.is_empty():
		var resolution_context: Dictionary = (
			_factory_resolution_context_stack.back()
		)
		_mark_factory_resolution_failed(resolution_context)
		push_error(
			"[GFArchitecture] %s 失败：工厂解析期间禁止重入修改模块拓扑。"
			% context
		)
		return false
	if (
		_runtime.is_ready()
		and _has_live_child_external_dependency_leases(true)
	):
		push_error(
			"[GFArchitecture] %s 失败：活动子架构仍持有父级外部模块依赖租约。"
			% context
		)
		return false
	if _topology_mutation != null:
		push_error("[GFArchitecture] %s 失败：另一项模块拓扑事务尚未完成。" % context)
		return false
	if _lifecycle_hook_depth > 0:
		push_error("[GFArchitecture] %s 失败：生命周期 Hook 内禁止重入修改注册表。" % context)
		return false
	return true


func _fail_active_factory_resolution_contexts() -> void:
	for resolution_context: Dictionary in _factory_resolution_context_stack:
		_mark_factory_resolution_failed(resolution_context)


func _can_mutate_factory_topology(context: String) -> bool:
	if not _runtime.is_ready():
		return true
	push_error(
		"[GFArchitecture] %s 失败：activation 后 factory 拓扑不可变。" % (
			context
		)
	)
	return false


func _can_mutate_runtime(context: String) -> bool:
	if _runtime.is_disposed() or _runtime.is_disposing():
		push_error("[GFArchitecture] %s 失败：架构已 dispose，不能继续修改运行时状态。" % context)
		return false
	if _runtime.is_quiescing():
		push_error("[GFArchitecture] %s 失败：架构正在 quiesce，已拒绝新的运行时写入。" % context)
		return false
	if _runtime.has_failed():
		push_error("[GFArchitecture] %s 失败：架构初始化已失败，已拒绝运行时写入。" % context)
		return false
	return true


func _can_execute_runtime(context: String) -> bool:
	if _runtime.is_disposed() or _runtime.is_disposing():
		push_error("[GFArchitecture] %s 失败：架构已 dispose，不能继续执行。" % context)
		return false
	if _runtime.is_quiescing():
		push_error("[GFArchitecture] %s 失败：架构正在 quiesce，已经关闭新的运行时准入。" % context)
		return false
	if _runtime.has_failed():
		push_error("[GFArchitecture] %s 失败：架构初始化已失败，已拒绝执行。" % context)
		return false
	if _topology_mutation != null:
		push_error("[GFArchitecture] %s 失败：模块拓扑事务尚未完成。" % context)
		return false
	if not _runtime.is_ready():
		push_error("[GFArchitecture] %s 失败：架构尚未完成 activation。" % context)
		return false
	return true


func _is_runtime_execution_admitted() -> bool:
	return _runtime.is_ready() and _topology_mutation == null


func _begin_stale_async_write_block() -> void:
	_stale_async_write_block_count += 1


func _end_stale_async_write_block() -> void:
	_stale_async_write_block_count = maxi(_stale_async_write_block_count - 1, 0)


func _begin_module_async_scope() -> GFAsyncScope:
	var async_scope: GFAsyncScope = GFAsyncScope.new()
	_track_async_scope(async_scope)
	return async_scope


func _complete_module_async_scope(async_scope: GFAsyncScope, lifecycle_serial: int) -> bool:
	if async_scope == null:
		return _is_lifecycle_current(lifecycle_serial) and not _runtime.has_failed()
	var completed: bool = (
		_is_lifecycle_current(lifecycle_serial)
		and not _runtime.has_failed()
		and not async_scope.is_cancel_requested()
	)
	if completed:
		async_scope.complete()
	_untrack_async_scope(async_scope)
	return completed


func _cancel_module_async_scope(async_scope: GFAsyncScope, reason: String) -> void:
	if async_scope == null:
		return
	var cancel_reason: String = reason
	if cancel_reason.is_empty():
		cancel_reason = "[GFArchitecture] 异步生命周期已取消。"
	var _cancelled_scope: bool = async_scope.cancel(cancel_reason)


func _track_async_scope(scope: GFAsyncScope) -> void:
	if scope == null:
		return
	if _runtime.is_disposing() or _runtime.is_disposed():
		var _cancelled_disposed_scope: bool = scope.cancel("[GFArchitecture] 架构已 dispose。")
		return
	if _runtime.has_failed():
		var _cancelled_failed_scope: bool = scope.cancel(last_initialization_error)
		return
	if _active_async_scopes.has(scope):
		return
	_active_async_scopes.append(scope)


func _untrack_async_scope(scope: GFAsyncScope) -> void:
	var scope_index: int = _active_async_scopes.find(scope)
	if scope_index >= 0:
		_active_async_scopes.remove_at(scope_index)


func _cancel_active_async_scopes(reason: String) -> void:
	var scopes: Array[GFAsyncScope] = _active_async_scopes.duplicate()
	_active_async_scopes.clear()
	for scope: GFAsyncScope in scopes:
		if scope != null:
			var _cancelled_scope: bool = scope.cancel(reason)


func _unregister_module(module_registry: ModuleRegistry, script_cls: Script) -> bool:
	if not _can_mutate_registration_state("unregister_%s" % module_registry._label_key()):
		return false
	if script_cls == null:
		return false
	if module_registry._has_direct(script_cls):
		if _runtime.is_ready():
			return await _unregister_active_module(
				module_registry,
				script_cls
			)
		var _removed_instance: Object = _remove_registered_module(module_registry, script_cls, true, true)
		return true
	if module_registry.aliases.has(script_cls):
		push_error("[GFArchitecture] unregister_%s 失败：传入的是 alias，请使用 unregister_%s_alias()。" % [
			module_registry._label_key(),
			module_registry._label_key(),
		])
		return false
	return false


func _unregister_active_module(
	module_registry: ModuleRegistry,
	script_cls: Script
) -> bool:
	var instance: Object = _get_dictionary_object(
		module_registry.instances,
		script_cls
	)
	var topology_transaction: TopologyMutation = _begin_topology_mutation(
		&"unregister",
		module_registry,
		script_cls,
		null,
		instance
	)
	if topology_transaction == null:
		return false
	topology_transaction._previous_plan = _active_lifecycle_plan
	var transaction: Dictionary = _runtime.begin_transaction(
		"unregister_%s" % module_registry._label_key()
	)
	var lifecycle_serial: int = _runtime.get_lifecycle_generation()
	topology_transaction._lifecycle_serial = lifecycle_serial
	var candidate_models: Dictionary = _models.duplicate()
	var candidate_utilities: Dictionary = _utilities.duplicate()
	var candidate_systems: Dictionary = _systems.duplicate()
	var candidate_registry: Dictionary = _get_candidate_registry_dictionary(
		module_registry,
		candidate_models,
		candidate_utilities,
		candidate_systems
	)
	var _removed_candidate: bool = candidate_registry.erase(script_cls)
	var candidate_plan: GFArchitectureLifecyclePlan = (
		_compile_candidate_lifecycle_plan(
			candidate_models,
			candidate_utilities,
			candidate_systems,
			"hot unregister",
			true,
			_create_lifecycle_plan_validity_guard(
				lifecycle_serial,
				topology_transaction,
				transaction
			)
		)
	)
	if (
		candidate_plan == null
		or not _is_topology_mutation_current(topology_transaction)
		or not _is_lifecycle_current(lifecycle_serial)
		or not _runtime.is_ready()
		or _runtime.has_failed()
		or _runtime.is_transaction_invalidated(transaction)
	):
		_rollback_topology_candidate(topology_transaction, transaction)
		return false
	var excluded_instances: Dictionary = {}
	if instance != null:
		excluded_instances[instance] = true
	if not _validate_candidate_plan_stability(
		topology_transaction._previous_plan,
		candidate_plan,
		excluded_instances,
		"hot unregister"
	):
		_rollback_topology_candidate(topology_transaction, transaction)
		return false
	topology_transaction._candidate_plan = candidate_plan
	if not _stage_topology_external_dependency_leases(
		topology_transaction,
		candidate_plan,
		lifecycle_serial
	):
		_rollback_topology_candidate(
			topology_transaction,
			transaction
		)
		return false
	topology_transaction._phase = (
		TopologyMutation._PHASE_QUIESCING_PREVIOUS
	)
	var quiesced: bool = await _quiesce_topology_module(
		instance,
		_active_lifecycle_plan,
		lifecycle_serial,
		topology_transaction
	)
	if (
		not quiesced
		or not _is_topology_mutation_current(topology_transaction)
		or not _is_lifecycle_current(lifecycle_serial)
		or _runtime.is_transaction_invalidated(transaction)
	):
		_runtime.finish_transaction(transaction)
		if _runtime.is_ready():
			dispose()
		else:
			_fail_topology_mutation(
				topology_transaction,
				"Accepted topology unregister failed during quiesce."
			)
		return false
	if _get_dictionary_object(module_registry.instances, script_cls) != instance:
		_runtime.finish_transaction(transaction)
		_finish_topology_mutation(topology_transaction)
		return false
	topology_transaction._phase = TopologyMutation._PHASE_COMMITTING
	_promote_topology_external_dependency_leases(
		topology_transaction
	)
	_active_lifecycle_plan = candidate_plan
	topology_transaction._outcome = TopologyMutation._OUTCOME_COMMITTED
	topology_transaction._phase = (
		TopologyMutation._PHASE_CLEANING_DETACHED
	)
	var _removed_instance: Object = _remove_registered_module(
		module_registry,
		script_cls,
		true,
		true
	)
	if (
		not _is_lifecycle_current(lifecycle_serial)
		or _runtime.is_transaction_invalidated(transaction)
		or not _is_topology_mutation_current(topology_transaction)
	):
		_runtime.finish_transaction(transaction)
		_fail_topology_mutation(
			topology_transaction,
			"Accepted topology unregister was invalidated during detached cleanup."
		)
		return false
	topology_transaction._phase = TopologyMutation._PHASE_COMMITTED
	_runtime.finish_transaction(transaction)
	_finish_topology_mutation(topology_transaction)
	return true


func _remove_registered_module(
	module_registry: ModuleRegistry,
	registered_key: Script,
	dispose_instance: bool,
	remove_aliases: bool
) -> Object:
	var instance: Object = _get_dictionary_object(module_registry.instances, registered_key)
	module_registry._untrack_instance(instance)
	var _removed_instance: bool = module_registry.instances.erase(registered_key)
	if remove_aliases:
		_remove_aliases_for(module_registry, registered_key)
	module_registry._clear_assignable_cache()
	if instance != null and dispose_instance:
		var disposed_instances: Dictionary = (
			_module_disposal_claims
			if _module_disposal_session_depth > 0
			else {}
		)
		_dispose_module_once(instance, disposed_instances)
	elif instance != null:
		_event_system.unregister_owner(instance)
		_unregister_services_for_owner(instance)
		_release_module_dependencies(instance)
	if instance != null:
		var _removed_stage: bool = _module_lifecycle_stages.erase(instance)
	return instance


func _inject_dependencies_if_needed(
	instance: Object,
	lifecycle_serial: int = -1,
	execution_context: bool = false
) -> bool:
	if instance == null:
		return true
	if not _registration_candidate_is_live(instance):
		return false
	if not _is_dependency_injection_current(lifecycle_serial):
		return false
	var execution_scope_bound: bool = false
	if execution_context and instance.has_method("_gf_begin_execution_scope"):
		var begin_result: Variant = instance.call("_gf_begin_execution_scope", self, lifecycle_serial)
		if not _registration_candidate_is_live(instance):
			return false
		if not _GF_VARIANT_ACCESS_SCRIPT.to_bool(begin_result):
			return false
		execution_scope_bound = true
	if not execution_scope_bound:
		_bind_dependency_scope_if_needed(instance, lifecycle_serial)
		if not _registration_candidate_is_live(instance):
			return false
	if instance.has_method("inject_dependencies"):
		var _inject_dependencies_result: Variant = instance.call("inject_dependencies", self)
		if not _registration_candidate_is_live(instance):
			return false
		if not _is_dependency_injection_current(lifecycle_serial):
			return false
	if instance.has_method("inject"):
		var _inject_result: Variant = instance.call("inject", self)
		if not _registration_candidate_is_live(instance):
			return false
	return (
		_registration_candidate_is_live(instance)
		and _is_dependency_injection_current(lifecycle_serial)
	)


func _is_dependency_injection_current(lifecycle_serial: int) -> bool:
	if lifecycle_serial < 0:
		return (
			not _runtime.has_failed()
			and not _runtime.is_disposing()
			and not _runtime.is_disposed()
		)
	return (
		_is_lifecycle_current(lifecycle_serial)
		and _runtime.is_lifecycle_active()
		and not _runtime.has_failed()
		and not _runtime.is_disposing()
		and not _runtime.is_disposed()
	)


func _bind_dependency_scope_if_needed(instance: Object, lifecycle_serial: int = -1) -> void:
	if (
		not _registration_candidate_is_live(instance)
		or not instance.has_method("_gf_set_dependency_scope")
	):
		return
	if instance is GFModel or instance is GFSystem or instance is GFUtility or instance is GFCommand or instance is GFQuery:
		instance.call("_gf_set_dependency_scope", self, lifecycle_serial)
		return
	instance.call("_gf_set_dependency_scope", self)


func _clear_injected_scope(instance: Object) -> void:
	if not _registration_candidate_is_live(instance):
		return
	if instance.has_method("_gf_set_dependency_scope"):
		instance.call("_gf_set_dependency_scope", null)
	elif instance.has_method("_release_dependency_scope"):
		instance.call("_release_dependency_scope")


func _release_module_dependencies(instance: Object) -> void:
	if not _registration_candidate_is_live(instance):
		return
	_lifecycle_hook_depth += 1
	_call_module_release_dependencies(instance)
	_clear_injected_scope(instance)
	_lifecycle_hook_depth -= 1


func _stop_project_installers_after_failure() -> bool:
	var was_running: bool = _project_installers_running
	_project_installers_applied = false
	_project_installers_running = false
	return was_running


func _inject_node_tree(node: Node) -> void:
	var _injected_dependencies: bool = _inject_dependencies_if_needed(node)
	for child: Node in node.get_children(true):
		_inject_node_tree(child)


func _validate_registration(script_cls: Script, instance: Object, label: String) -> bool:
	if script_cls == null:
		push_error("[GFArchitecture] register_%s 失败：脚本类型为空。" % label.to_lower())
		return false
	if instance == null:
		push_error("[GFArchitecture] register_%s 失败：实例为空。" % label.to_lower())
		return false
	if not _registration_candidate_is_live(instance):
		push_error("[GFArchitecture] register_%s 失败：实例已经失效或等待释放。" % label.to_lower())
		return false
	if not _instance_matches_registration_label(instance, label):
		push_error("[GFArchitecture] register_%s 失败：实例类型必须继承 GF%s。" % [label.to_lower(), label])
		return false
	var instance_script: Script = _get_instance_script(instance)
	if instance_script == null:
		push_error("[GFArchitecture] register_%s 失败：实例未附加脚本。" % label.to_lower())
		return false
	if not GFScriptTypeInspector.script_extends_or_equals(instance_script, script_cls):
		push_error("[GFArchitecture] register_%s 失败：实例脚本必须继承或等于注册脚本类型。" % label.to_lower())
		return false

	return true


func _registration_candidate_is_live(candidate: Variant) -> bool:
	if candidate == null or not is_instance_valid(candidate):
		return false
	if not candidate is Object:
		return false
	if candidate is Node:
		var node: Node = candidate
		return not node.is_queued_for_deletion()
	return true


func _get_instance_script_or_null(instance: Object, context: String) -> Script:
	if instance == null:
		push_error("[GFArchitecture] %s 失败：实例为空。" % context)
		return null

	var script: Script = _get_instance_script(instance)
	if script == null:
		push_error("[GFArchitecture] %s 失败：实例未附加脚本。" % context)
		return null

	return script


func _instance_matches_registration_label(instance: Object, label: String) -> bool:
	match label:
		"Model":
			return instance is GFModel

		"System":
			return instance is GFSystem

		"Utility":
			return instance is GFUtility

		_:
			return true


func _refresh_cached_utility_refs() -> void:
	_time_provider = _get_local_registered_instance(_utility_registry, GFTimeProviderBase)


func _get_time_provider() -> Object:
	var current: GFArchitecture = self
	var visited: Dictionary = _create_parent_lookup_visited()
	while current != null:
		var time_provider: Object = current._get_local_time_provider()
		if time_provider != null:
			return time_provider
		current = _get_next_parent_for_lookup(current, visited, "_get_time_provider")
	return null


func _get_local_time_provider() -> Object:
	if _time_provider == null:
		_refresh_cached_utility_refs()
	if _time_provider != null:
		return _time_provider
	return null


func _get_command_history_store() -> Object:
	return _get_service_with_parent_lookup(SERVICE_COMMAND_HISTORY_STORE, true)


func _get_service_with_parent_lookup(service_key: StringName, include_parent: bool) -> Object:
	var current: GFArchitecture = self
	var visited: Dictionary = _create_parent_lookup_visited()
	while current != null:
		var service_provider: Object = current._get_local_service(service_key)
		if service_provider != null:
			return service_provider
		if not include_parent:
			return null
		current = _get_next_parent_for_lookup(current, visited, "get_service")
	return null


func _get_local_service(service_key: StringName) -> Object:
	if not _services.has(service_key):
		return null
	var service_provider: Object = _get_dictionary_object(_services, service_key)
	if service_provider == null:
		var _removed_released_service: bool = _services.erase(service_key)
		return null
	if not is_instance_valid(service_provider):
		var _removed_invalid_service: bool = _services.erase(service_key)
		return null
	return service_provider


func _unregister_services_for_owner(owner: Object) -> void:
	if owner == null:
		return
	for service_key: Variant in _services.keys():
		var service_provider: Object = _get_dictionary_object(_services, service_key)
		if service_provider == owner:
			var _removed_service: bool = _services.erase(service_key)


func _refresh_tick_caches() -> void:
	_tick_scheduler.refresh()


func _get_active_lifecycle_serial_or_unbound() -> int:
	if is_lifecycle_active():
		return _runtime.get_lifecycle_generation()
	return -1


func _is_lifecycle_current(lifecycle_serial: int) -> bool:
	return _runtime.is_generation_current(lifecycle_serial)


func _get_module_label_for_instance(instance: Object) -> String:
	if instance is GFModel:
		return "model"
	if instance is GFSystem:
		return "system"
	if instance is GFUtility:
		return "utility"
	return "module"


func _is_module_ready_for_lookup(instance: Object) -> bool:
	return _is_committed_module_at_lifecycle_stage(instance, 3)


func _is_committed_module_at_lifecycle_stage(
	instance: Object,
	target_stage: int
) -> bool:
	return (
		_get_module_registry_for_instance(instance) != null
		and _has_module_reached_lifecycle_stage(instance, target_stage)
	)


func _has_module_reached_lifecycle_stage(instance: Object, target_stage: int) -> bool:
	return (
		instance != null
		and _runtime.is_lifecycle_active()
		and _GF_VARIANT_ACCESS_SCRIPT.get_option_int(
			_module_lifecycle_stages,
			instance,
			0
		) >= target_stage
	)


func _register_module_alias(
	module_registry: ModuleRegistry,
	alias_cls: Script,
	target_cls: Script
) -> bool:
	if not _can_mutate_registration_state("register_%s_alias" % module_registry._label_key()):
		return false
	if _runtime.is_ready():
		push_error(
			"[GFArchitecture] register_%s_alias 失败：activation 后 alias 拓扑不可变。" % (
				module_registry._label_key()
			)
		)
		return false
	if alias_cls == null or target_cls == null:
		push_error("[GFArchitecture] register_%s_alias 失败：alias 或 target 为空。" % module_registry._label_key())
		return false
	if not GFScriptTypeInspector.script_extends_or_equals(target_cls, alias_cls):
		push_error("[GFArchitecture] register_%s_alias 失败：target 必须继承或等于 alias。" % module_registry._label_key())
		return false
	if not module_registry._has_direct(target_cls):
		push_warning("[GFArchitecture] register_%s_alias：目标类型尚未注册，仍会记录别名。" % module_registry._label_key())
	module_registry.aliases[alias_cls] = target_cls
	module_registry._clear_assignable_cache()
	return module_registry.aliases.has(alias_cls)


func _unregister_module_alias(module_registry: ModuleRegistry, alias_cls: Script) -> bool:
	if not _can_mutate_registration_state("unregister_%s_alias" % module_registry._label_key()):
		return false
	if _runtime.is_ready():
		push_error(
			"[GFArchitecture] unregister_%s_alias 失败：activation 后 alias 拓扑不可变。" % (
				module_registry._label_key()
			)
		)
		return false
	if alias_cls == null:
		push_error("[GFArchitecture] unregister_%s_alias 失败：alias 为空。" % module_registry._label_key())
		return false
	if not module_registry.aliases.has(alias_cls):
		return false
	var _removed_alias: bool = module_registry.aliases.erase(alias_cls)
	module_registry._clear_assignable_cache()
	return true


func _resolve_registered_key(module_registry: ModuleRegistry, script_cls: Script) -> Script:
	if script_cls == null:
		return null
	if module_registry._has_direct(script_cls):
		return script_cls
	if module_registry.aliases.has(script_cls):
		var target_cls: Script = _get_dictionary_script(module_registry.aliases, script_cls)
		if target_cls != null and module_registry._has_direct(target_cls):
			return target_cls
		_report_unresolved_alias(module_registry, script_cls, target_cls)
	return null


func _get_local_registered_instance(module_registry: ModuleRegistry, script_cls: Script) -> Object:
	var registered_key: Script = _resolve_registered_key(module_registry, script_cls)
	if registered_key != null:
		return _get_dictionary_object(module_registry.instances, registered_key)
	if _has_unresolved_alias(module_registry, script_cls):
		return null
	registered_key = _resolve_assignable_cached_key(module_registry, script_cls)
	if registered_key != null:
		return _get_dictionary_object(module_registry.instances, registered_key)
	registered_key = _find_assignable_registered_key(module_registry, script_cls)
	if registered_key != null:
		module_registry.assignable_cache[script_cls] = registered_key
		return _get_dictionary_object(module_registry.instances, registered_key)
	return null


func _report_strict_lookup_miss(script_cls: Script, label: String) -> void:
	push_error("[GFArchitecture] strict_dependency_lookup：当前架构未注册 %s：%s" % [
		label,
		_get_script_debug_key(script_cls),
	])


func _remove_aliases_for(module_registry: ModuleRegistry, registered_key: Script) -> void:
	var keys_to_remove: Array = []
	for alias_cls: Script in module_registry.aliases:
		if module_registry.aliases[alias_cls] == registered_key:
			keys_to_remove.append(alias_cls)
	for alias_cls: Script in keys_to_remove:
		var _removed_alias: bool = module_registry.aliases.erase(alias_cls)


func _has_unresolved_alias(module_registry: ModuleRegistry, script_cls: Script) -> bool:
	if script_cls == null or not module_registry.aliases.has(script_cls):
		return false
	var target_cls: Script = _get_dictionary_script(module_registry.aliases, script_cls)
	return target_cls == null or not module_registry._has_direct(target_cls)


func _report_unresolved_alias(module_registry: ModuleRegistry, alias_cls: Script, target_cls: Script) -> void:
	push_error("[GFArchitecture] get_%s(%s) 失败：alias 指向的目标未注册：%s。" % [
		module_registry._label_key(),
		_get_script_debug_key(alias_cls),
		_get_script_debug_key(target_cls),
	])


func _resolve_assignable_cached_key(module_registry: ModuleRegistry, script_cls: Script) -> Script:
	if script_cls == null or not module_registry.assignable_cache.has(script_cls):
		return null
	var cached_key: Script = _get_dictionary_script(module_registry.assignable_cache, script_cls)
	if cached_key != null and module_registry._has_direct(cached_key):
		return cached_key
	var _removed_cached_key: bool = module_registry.assignable_cache.erase(script_cls)
	return null


func _find_assignable_registered_key(module_registry: ModuleRegistry, script_cls: Script) -> Script:
	if script_cls == null:
		return null
	var matches: Array[Script] = []
	for registered_script: Script in module_registry.instances:
		if GFScriptTypeInspector.script_extends_or_equals(registered_script, script_cls):
			matches.append(registered_script)
	if matches.size() == 1:
		return matches[0]
	if matches.size() > 1:
		push_warning("[GFArchitecture] get_%s(%s) 匹配到多个本地实例，本次查询不会回退父架构；请使用显式 alias 注册以消除歧义。" % [
			module_registry._label_key(),
			script_cls.resource_path,
		])
	return null


func _has_assignable_instance(module_registry: ModuleRegistry, script_cls: Script) -> bool:
	if script_cls == null:
		return false
	for registered_script: Script in module_registry.instances:
		if GFScriptTypeInspector.script_extends_or_equals(registered_script, script_cls):
			return true
	return false


# --- 内部类 ---

## TopologyMutation: 已接纳模块拓扑事务的所有权与终态描述符。
##
## shutdown 可在 deadline 或取消时同步接管未提交候选；原 coroutine 保留同一
## 描述符并通过 identity guard 识别失效，不能再提交候选。
## [br]
## @api framework_internal
## [br]
## @layer kernel/core
class TopologyMutation:
	extends RefCounted

	const _PHASE_PREPARING: StringName = &"preparing"
	const _PHASE_ACTIVATING: StringName = &"activating"
	const _PHASE_QUIESCING_PREVIOUS: StringName = &"quiescing_previous"
	const _PHASE_COMMITTING: StringName = &"committing"
	const _PHASE_CLEANING_DETACHED: StringName = &"cleaning_detached"
	const _PHASE_COMMITTED: StringName = &"committed"
	const _PHASE_ABORTED: StringName = &"aborted"
	const _PHASE_FINISHED: StringName = &"finished"
	const _OWNER_CONTINUATION: StringName = &"continuation"
	const _OWNER_SHUTDOWN: StringName = &"shutdown"
	const _OUTCOME_PENDING: StringName = &"pending"
	const _OUTCOME_COMMITTED: StringName = &"committed"
	const _OUTCOME_ROLLED_BACK: StringName = &"rolled_back"
	const _OUTCOME_ABORTED: StringName = &"aborted"
	const _OUTCOME_FATAL: StringName = &"fatal"
	const _CLEANUP_NOT_REQUIRED: StringName = &"not_required"
	const _CLEANUP_PENDING: StringName = &"pending"
	const _CLEANUP_CLAIMED: StringName = &"claimed"
	const _CLEANUP_DONE: StringName = &"done"
	const _CLEANUP_TRANSFERRED: StringName = &"transferred"

	var _id: int = 0
	var _operation: StringName = &""
	var _module_registry: Variant = null
	var _script_cls: Script = null
	var _candidate: Object = null
	var _previous: Object = null
	var _previous_plan: GFArchitectureLifecyclePlan = null
	var _candidate_plan: GFArchitectureLifecyclePlan = null
	var _lifecycle_serial: int = -1
	var _phase: StringName = _PHASE_PREPARING
	var _owner: StringName = _OWNER_CONTINUATION
	var _outcome: StringName = _OUTCOME_PENDING
	var _gate: GFAsyncCompletion = GFAsyncCompletion.new()
	var _active_scope: GFAsyncScope = null
	var _candidate_cleanup_state: StringName = _CLEANUP_NOT_REQUIRED
	var _service_intents: Dictionary = {}
	var _expected_service_presence: Dictionary = {}
	var _expected_service_providers: Dictionary = {}
	var _candidate_external_dependency_leases: Array[Dictionary] = []

	func _init(
		p_id: int,
		p_operation: StringName,
		p_module_registry: Variant,
		p_script_cls: Script,
		p_candidate: Object,
		p_previous: Object
	) -> void:
		_id = p_id
		_operation = p_operation
		_module_registry = p_module_registry
		_script_cls = p_script_cls
		_candidate = p_candidate
		_previous = p_previous
## DependencyDiagnosticsReport: 架构依赖诊断报告构建器。
## [br]
## @api framework_internal
## [br]
## @layer kernel/core
class DependencyDiagnosticsReport:
	extends RefCounted

	const _GF_VARIANT_ACCESS_SCRIPT = preload("res://addons/gf/kernel/core/gf_variant_access.gd")

	## 诊断报告主体名称。
	## [br]
	## @api framework_internal
	var subject: String = ""

	## 诊断条目列表。
	## [br]
	## @api framework_internal
	## [br]
	## @schema issues: Array of Dictionary dependency diagnostic entries.
	var issues: Array[Dictionary] = []

	func _init(p_subject: String = "") -> void:
		subject = p_subject

	## 添加一个 warning 级别的依赖诊断条目。
	## [br]
	## @api framework_internal
	## [br]
	## @param kind: 诊断类型。
	## [br]
	## @param message: 面向维护者的诊断说明。
	## [br]
	## @param key: 可选的关联键，例如脚本类、别名或设置名。
	## [br]
	## @schema key: Variant diagnostic key stored unchanged when present.
	## [br]
	## @param path: 可选的关联资源路径。
	## [br]
	## @param metadata: 可选的附加诊断数据。
	## [br]
	## @schema metadata: Dictionary copied into the metadata field when not empty.
	## [br]
	## @return 新增的诊断条目。
	## [br]
	## @schema return: Dictionary issue entry appended to issues.
	func add_warning(
		kind: StringName,
		message: String,
		key: Variant = null,
		path: String = "",
		metadata: Dictionary = {}
	) -> Dictionary:
		return _add_issue("warning", kind, message, key, path, metadata)

	## 添加一个 error 级别的依赖诊断条目。
	## [br]
	## @api framework_internal
	## [br]
	## @param kind: 诊断类型。
	## [br]
	## @param message: 面向维护者的诊断说明。
	## [br]
	## @param key: 可选的关联键，例如脚本类、别名或设置名。
	## [br]
	## @schema key: Variant diagnostic key stored unchanged when present.
	## [br]
	## @param path: 可选的关联资源路径。
	## [br]
	## @param metadata: 可选的附加诊断数据。
	## [br]
	## @schema metadata: Dictionary copied into the metadata field when not empty.
	## [br]
	## @return 新增的诊断条目。
	## [br]
	## @schema return: Dictionary issue entry appended to issues.
	func add_error(
		kind: StringName,
		message: String,
		key: Variant = null,
		path: String = "",
		metadata: Dictionary = {}
	) -> Dictionary:
		return _add_issue("error", kind, message, key, path, metadata)

	## 汇总诊断条目并转换为可序列化字典。
	## [br]
	## @api framework_internal
	## [br]
	## @param additional_fields: 合并到结果中的额外字段。
	## [br]
	## @schema additional_fields: Dictionary copied into the output before summary fields are added.
	## [br]
	## @param options: 可选输出控制项，例如 include_info_count、include_issue_count、next_action。
	## [br]
	## @schema options: Dictionary controlling summary fields and next action text.
	## [br]
	## @return 诊断报告字典。
	## [br]
	## @schema return: Dictionary containing ok, healthy, counts, summary, next_action, and issues.
	func to_dict(additional_fields: Dictionary = {}, options: Dictionary = {}) -> Dictionary:
		var result: Dictionary = additional_fields.duplicate(true)
		var error_count: int = 0
		var warning_count: int = 0
		var info_count: int = 0
		var issue_counts_by_kind: Dictionary = {}
		for issue: Dictionary in issues:
			var severity: String = _GF_VARIANT_ACCESS_SCRIPT.get_option_string(issue, "severity", "error")
			match severity:
				"error":
					error_count += 1
				"warning":
					warning_count += 1
				"info":
					info_count += 1

			var kind_key: String = _GF_VARIANT_ACCESS_SCRIPT.get_option_string(issue, "kind", "unknown")
			issue_counts_by_kind[kind_key] = _GF_VARIANT_ACCESS_SCRIPT.get_option_int(issue_counts_by_kind, kind_key, 0) + 1

		var include_info_count: bool = _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(options, "include_info_count", true)
		var include_issue_count: bool = _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(options, "include_issue_count", true)
		result["ok"] = error_count == 0
		result["healthy"] = error_count == 0 and warning_count == 0
		result["error_count"] = error_count
		result["warning_count"] = warning_count
		if include_info_count:
			result["info_count"] = info_count
		if include_issue_count:
			result["issue_count"] = issues.size()
		result["issue_counts_by_kind"] = issue_counts_by_kind
		result["summary"] = _make_summary(error_count, warning_count)
		result["next_action"] = _get_next_action(options)
		result["issues"] = issues.duplicate(true)
		return result

	func _add_issue(
		severity: String,
		kind: StringName,
		message: String,
		key: Variant,
		path: String,
		metadata: Dictionary
	) -> Dictionary:
		var issue: Dictionary = {
			"severity": severity,
			"kind": String(kind),
			"message": message,
		}
		if key != null:
			issue["key"] = key
		if not path.is_empty():
			issue["path"] = path
		if not metadata.is_empty():
			issue["metadata"] = metadata.duplicate(true)
		issues.append(issue)
		return issue

	func _make_summary(error_count: int, warning_count: int) -> String:
		var label: String = subject
		if label.is_empty():
			label = "Validation report"
		if error_count > 0:
			return "%s has %d error(s) and %d warning(s)." % [label, error_count, warning_count]
		if warning_count > 0:
			return "%s has %d warning(s)." % [label, warning_count]
		return "%s is healthy." % label

	func _get_next_action(options: Dictionary) -> String:
		var next_actions: Dictionary = _GF_VARIANT_ACCESS_SCRIPT.get_option_dictionary(options, "next_actions", {})
		var fallback_action: String = _GF_VARIANT_ACCESS_SCRIPT.get_option_string(options, "fallback_action", "Review the first reported issue.")
		var no_action: String = _GF_VARIANT_ACCESS_SCRIPT.get_option_string(options, "no_action", "No action required.")
		var issue: Dictionary = _get_first_issue_by_priority()
		if issue.is_empty():
			return no_action
		var kind_key: String = _GF_VARIANT_ACCESS_SCRIPT.get_option_string(issue, "kind", "unknown")
		if next_actions.has(kind_key):
			return _GF_VARIANT_ACCESS_SCRIPT.to_text(next_actions[kind_key])
		var kind_name: StringName = StringName(kind_key)
		if next_actions.has(kind_name):
			return _GF_VARIANT_ACCESS_SCRIPT.to_text(next_actions[kind_name])
		return fallback_action

	func _get_first_issue_by_priority() -> Dictionary:
		for issue: Dictionary in issues:
			if _GF_VARIANT_ACCESS_SCRIPT.get_option_string(issue, "severity", "") == "error":
				return issue
		for issue: Dictionary in issues:
			if _GF_VARIANT_ACCESS_SCRIPT.get_option_string(issue, "severity", "") == "warning":
				return issue
		if not issues.is_empty():
			return issues[0]
		return {}


## ModuleRegistry: 架构模块注册表。
## [br]
## @api framework_internal
## [br]
## @layer kernel/core
class ModuleRegistry:
	## 注册表显示名称。
	## [br]
	## @api framework_internal
	var label: String = ""

	## 直接注册的模块实例映射。
	## [br]
	## @api framework_internal
	## [br]
	## @schema instances: Dictionary keyed by Script, storing registered module instances.
	var instances: Dictionary = {}

	## 别名到直接注册脚本的映射。
	## [br]
	## @api framework_internal
	## [br]
	## @schema aliases: Dictionary keyed by alias Script, storing target Script.
	var aliases: Dictionary = {}

	## 可赋值查询缓存。
	## [br]
	## @api framework_internal
	## [br]
	## @schema assignable_cache: Dictionary keyed by requested Script, storing resolved registered Script.
	var assignable_cache: Dictionary = {}

	## 实例 ID 到直接注册脚本的反向索引。
	## [br]
	## @api framework_internal
	## [br]
	## @schema instance_keys: Dictionary keyed by Object instance id, storing registered Script.
	var instance_keys: Dictionary = {}

	func _init(p_label: String) -> void:
		label = p_label

	func _label_key() -> String:
		return label.to_lower()

	func _has_direct(script_cls: Script) -> bool:
		return script_cls != null and instances.has(script_cls)

	func _clear_assignable_cache() -> void:
		assignable_cache.clear()

	func _track_instance_key(instance: Object, script_cls: Script) -> void:
		if instance == null or script_cls == null:
			return
		instance_keys[instance.get_instance_id()] = script_cls

	func _untrack_instance(instance: Object) -> void:
		if instance == null:
			return
		var _removed_instance_key: bool = instance_keys.erase(instance.get_instance_id())

	func _get_key_for_instance(instance: Object) -> Script:
		if instance == null:
			return null
		var instance_id: int = instance.get_instance_id()
		if not instance_keys.has(instance_id):
			return null
		var script_cls: Script = _get_script_from_variant(instance_keys[instance_id])
		if script_cls == null or not instances.has(script_cls):
			var _removed_stale_key: bool = instance_keys.erase(instance_id)
			return null
		if instances[script_cls] != instance:
			var _removed_mismatched_key: bool = instance_keys.erase(instance_id)
			return null
		return script_cls

	func _clear() -> void:
		instances.clear()
		aliases.clear()
		assignable_cache.clear()
		instance_keys.clear()

	func _get_script_from_variant(value: Variant) -> Script:
		if value is Script:
			var script_cls: Script = value
			return script_cls
		return null
