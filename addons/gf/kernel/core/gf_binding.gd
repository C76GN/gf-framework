## GFBinding: 描述一个工厂绑定的来源、生命周期与依赖注入策略。
## [br]
## @api framework_internal
class_name GFBinding
extends RefCounted


# --- 常量 ---

## 绑定生命周期枚举脚本缓存。
## [br]
## @api framework_internal
const GFBindingLifetimesBase = preload("res://addons/gf/kernel/core/gf_binding_lifetimes.gd")

## 用于检查绑定实例脚本继承关系的辅助脚本。
## [br]
## @api private
const _SCRIPT_TYPE_INSPECTOR = preload("res://addons/gf/kernel/core/gf_script_type_inspector.gd")

## 解析上下文中绑定记录所使用的键名。
## [br]
## @api private
const _RESOLUTION_CONTEXT_BINDING_KEY: String = "binding"

## 解析上下文中新建 Singleton 列表所使用的键名。
## [br]
## @api private
const _RESOLUTION_CONTEXT_CREATED_SINGLETONS_KEY: String = "created_singletons"

## 解析上下文失败标志所使用的键名。
## [br]
## @api private
const _RESOLUTION_CONTEXT_FAILED_KEY: String = "failed"

## 解析上下文中实例记录所使用的键名。
## [br]
## @api private
const _RESOLUTION_CONTEXT_INSTANCE_KEY: String = "instance"


# --- 公共变量 ---

## 绑定键，通常为脚本类型。
## [br]
## @api framework_internal
## [br]
## @schema key: {"type": "Variant", "description": "通常为 Script 类型，也可由内部绑定实现扩展。"}
var key: Variant

## 绑定来源，可以是 Callable 工厂或 Object 实例。
## [br]
## @api framework_internal
## [br]
## @schema provider: {"type": "Variant", "description": "Callable 工厂或 Object 实例。"}
var provider: Variant

## 生命周期策略。
## [br]
## @api framework_internal
var lifetime: int = GFBindingLifetimesBase.Lifetime.TRANSIENT


# --- 私有变量 ---

## 创建此绑定的 Architecture。
## [br]
## @api private
var _owner_architecture: GFArchitecture = null

## Singleton 生命周期当前缓存的实例。
## [br]
## @api private
var _cached_instance: Object = null

## 标记 Singleton 缓存是否已设置实例。
## [br]
## @api private
var _has_cached_instance: bool = false

## 控制解析实例时是否调用依赖注入入口。
## [br]
## @api private
var _should_auto_inject: bool = true

## 控制清理缓存或拒绝工厂实例时是否调用 dispose()；拒绝的无父节点 Node 也受此开关控制是否释放。
## [br]
## @api private
var _should_dispose_cached_instance: bool = true

## 标记当前是否正在解析 Singleton 工厂。
## [br]
## @api private
var _is_resolving_singleton: bool = false


# --- Godot 生命周期方法 ---

## 捕获架构登记的工厂来源及生命周期策略，实例创建与注入延后到解析阶段。
## [br]
## @api framework_internal
## [br]
## @param p_key: 绑定匹配键。
## [br]
## @param p_provider: Callable 工厂或现成对象来源。
## [br]
## @param p_owner_architecture: 拥有该绑定的架构。
## [br]
## @param p_lifetime: GFBindingLifetimesBase.Lifetime 策略值。
## [br]
## @param p_should_auto_inject: 解析实例时是否注入依赖。
## [br]
## @param p_should_dispose_cached_instance: 清理缓存或拒绝实例时是否由绑定承担销毁。
## [br]
## @return 无返回值。
## [br]
## @schema p_key: Variant，架构通常使用 Script 作为绑定键。
## [br]
## @schema p_provider: Variant，支持 Callable 工厂或 Object 实例；在解析阶段校验实际结果。
func _init(
	p_key: Variant,
	p_provider: Variant,
	p_owner_architecture: GFArchitecture,
	p_lifetime: int = GFBindingLifetimesBase.Lifetime.TRANSIENT,
	p_should_auto_inject: bool = true,
	p_should_dispose_cached_instance: bool = true
) -> void:
	key = p_key
	provider = p_provider
	_owner_architecture = p_owner_architecture
	lifetime = p_lifetime
	_should_auto_inject = p_should_auto_inject
	_should_dispose_cached_instance = p_should_dispose_cached_instance


# --- 框架内部方法 ---

## 返回当前 Binding 是否仍保留指定实例作为固定 provider 或 Singleton 缓存。
## [br]
## @api framework_internal
## [br]
## @since 11.0.0
## [br]
## @param instance: 要检查的候选实例。
## [br]
## @return Binding 仍引用该实例时返回 true；不表示框架拥有调用其 dispose() 的权限。
func retains_instance_for_framework(instance: Object) -> bool:
	if instance == null or not is_instance_valid(instance):
		return false
	if provider is Object and is_same(provider, instance):
		return true
	return (
		_has_cached_instance
		and is_instance_valid(_cached_instance)
		and is_same(_cached_instance, instance)
	)


## 按当前生命周期解析实例。
## [br]
## @api framework_internal
## [br]
## @param requesting_architecture: 发起解析的架构。Transient 会优先注入它，Singleton 始终注入拥有该绑定的架构；两种生命周期都会固定并复核真实 requester 的准入 generation。
## [br]
## @param resolution_context: 当前工厂解析上下文，用于跨 Binding 失败链路回滚。
## [br]
## @schema resolution_context: {"type": "Dictionary", "description": "GFArchitecture 内部维护的解析上下文。"}
## [br]
## @return 解析出的 Object 实例；失败时返回 null。
func get_instance(requesting_architecture: GFArchitecture = null, resolution_context: Dictionary = {}) -> Object:
	match lifetime:
		GFBindingLifetimesBase.Lifetime.SINGLETON:
			if _has_cached_instance and _cached_instance_is_valid():
				return _cached_instance
			if _is_resolving_singleton:
				_mark_resolution_context_failed(resolution_context)
				push_error("[GFBinding][binding.singleton_dependency_cycle] A circular dependency was detected while resolving the Singleton factory.")
				return null

			clear_cached_instance()
			_is_resolving_singleton = true
			var provided_instance: Object = _provide(
				_owner_architecture,
				requesting_architecture,
				resolution_context
			)
			_is_resolving_singleton = false
			if provided_instance == null:
				return null
			if _resolution_context_has_failed(resolution_context):
				_release_rejected_factory_instance(
					provided_instance,
					true,
					_owner_architecture
				)
				return null

			_cached_instance = provided_instance
			_has_cached_instance = true
			_register_created_singleton_in_resolution_context(resolution_context, _cached_instance)
			return _cached_instance

		GFBindingLifetimesBase.Lifetime.TRANSIENT:
			var injection_architecture: GFArchitecture = requesting_architecture
			if injection_architecture == null:
				injection_architecture = _owner_architecture
			return _provide(
				injection_architecture,
				requesting_architecture,
				resolution_context
			)

		_:
			_mark_resolution_context_failed(resolution_context)
			push_error("[GFBinding][binding.lifetime_unknown] Unknown lifetime: %s." % str(lifetime))
			return null


## 清理 Singleton 生命周期缓存的实例引用，并释放框架注入作用域。
## [br]
## @api framework_internal
func clear_cached_instance() -> void:
	var instance: Object = _cached_instance
	_cached_instance = null
	_has_cached_instance = false

	if is_instance_valid(instance):
		if _owner_architecture != null:
			_owner_architecture.unregister_owner_events(instance)
		_release_instance_scope(instance)


## 拒绝并释放当前仍由 Binding 持有的 Singleton 缓存实例。
## 已由架构关闭流程清空或已经换代的缓存不会再次取得释放权。
## [br]
## @api framework_internal
## [br]
## @param instance: 需要拒绝的实例；为空时拒绝当前缓存实例。
## [br]
## @schema instance: {"type": "Object", "description": "失败解析链路中创建的 Singleton 实例。"}
func reject_cached_instance(instance: Object = null) -> void:
	var rejected_instance: Object = instance
	if rejected_instance == null:
		rejected_instance = _cached_instance

	if (
		_cached_instance == null
		or rejected_instance == null
		or not is_same(_cached_instance, rejected_instance)
	):
		return
	_cached_instance = null
	_has_cached_instance = false

	_release_rejected_factory_instance(
		rejected_instance,
		true,
		_owner_architecture
	)


## 释放 Singleton 生命周期缓存实例的框架归属。
## [br]
## @api framework_internal
func dispose_cached_instance() -> void:
	var instance: Object = _cached_instance
	_cached_instance = null
	_has_cached_instance = false

	if not is_instance_valid(instance):
		return

	if _owner_architecture != null:
		_owner_architecture.unregister_owner_events(instance)
	if _should_dispose_cached_instance and is_instance_valid(instance) and instance.has_method("dispose"):
		instance.call("dispose")
	if is_instance_valid(instance):
		_release_instance_scope(instance)


# --- 私有/辅助方法 ---

## 在所属与请求架构的准入代次内调用提供者，校验实例、键及注入后的生命周期；失败会标记解析上下文，并按所有权与是否已注入清理被拒实例。
## [br]
## @api private
func _provide(
	injection_architecture: GFArchitecture,
	requesting_architecture: GFArchitecture,
	resolution_context: Dictionary = {}
) -> Object:
	var admitted_requester: GFArchitecture = requesting_architecture
	if admitted_requester == null:
		admitted_requester = injection_architecture
	var owner_lifecycle_generation: int = (
		_get_admitted_lifecycle_generation(_owner_architecture)
	)
	var requester_lifecycle_generation: int = (
		_get_admitted_lifecycle_generation(admitted_requester)
	)
	if (
		owner_lifecycle_generation < 0
		or requester_lifecycle_generation < 0
	):
		_mark_resolution_context_failed(resolution_context)
		return null
	var value: Variant
	if provider is Callable:
		var provider_callable: Callable = provider
		value = provider_callable.call()
	else:
		value = provider

	if typeof(value) == TYPE_OBJECT and not is_instance_valid(value):
		if _resolution_context_has_failed(resolution_context):
			return null
		_mark_resolution_context_failed(resolution_context)
		push_error("[GFBinding][binding.source_object_invalid] The binding source returned an invalid Object instance.")
		return null
	if not value is Object:
		if _resolution_context_has_failed(resolution_context):
			return null
		_mark_resolution_context_failed(resolution_context)
		push_error("[GFBinding][binding.source_not_object] The binding source must return an Object instance.")
		return null

	var instance: Object = value
	if not _instance_is_live(instance):
		_mark_resolution_context_failed(resolution_context)
		push_error("[GFBinding][binding.source_object_invalid] The binding source returned an invalid Object instance.")
		return null
	if (
		_resolution_context_has_failed(resolution_context)
		or not _is_admission_guard_current(
			admitted_requester,
			owner_lifecycle_generation,
			requester_lifecycle_generation
		)
	):
		_mark_resolution_context_failed(resolution_context)
		_release_rejected_factory_instance(instance, false)
		return null
	if not _instance_matches_key(instance):
		_mark_resolution_context_failed(resolution_context)
		push_error("[GFBinding][binding.source_script_mismatch] The binding source instance script must extend or equal the binding key.")
		_release_rejected_factory_instance(instance, false)
		return null

	if _should_auto_inject:
		if not _inject_if_needed(
			instance,
			injection_architecture,
			admitted_requester,
			owner_lifecycle_generation,
			requester_lifecycle_generation,
			resolution_context
		):
			_mark_resolution_context_failed(resolution_context)
			_release_rejected_factory_instance(
				instance,
				true,
				injection_architecture
			)
			return null
	if (
		not _is_resolution_step_current(
			instance,
			admitted_requester,
			owner_lifecycle_generation,
			requester_lifecycle_generation,
			resolution_context
		)
	):
		_mark_resolution_context_failed(resolution_context)
		_release_rejected_factory_instance(
			instance,
			true,
			injection_architecture
		)
		return null

	return instance


## 仅在架构接受运行时工作时返回其生命周期 generation，否则返回 -1。
## [br]
## @api private
func _get_admitted_lifecycle_generation(
	architecture: GFArchitecture
) -> int:
	if (
		architecture == null
		or not architecture.is_accepting_runtime_work()
	):
		return -1
	return architecture.get_lifecycle_generation()


## 检查绑定所属架构与请求架构是否仍处于捕获的生命周期 generation。
## [br]
## @api private
func _is_admission_guard_current(
	requesting_architecture: GFArchitecture,
	owner_lifecycle_generation: int,
	requester_lifecycle_generation: int
) -> bool:
	return (
		_is_architecture_admission_current(
			_owner_architecture,
			owner_lifecycle_generation
		)
		and _is_architecture_admission_current(
			requesting_architecture,
			requester_lifecycle_generation
		)
	)


## 检查架构仍接受运行时工作且其 generation 与捕获值一致。
## [br]
## @api private
func _is_architecture_admission_current(
	architecture: GFArchitecture,
	lifecycle_generation: int
) -> bool:
	return (
		architecture != null
		and lifecycle_generation >= 0
		and architecture.get_lifecycle_generation() == lifecycle_generation
		and architecture.is_accepting_runtime_work()
	)


## 检查实例有效、解析上下文未失败且架构准入状态仍匹配。
## [br]
## @api private
func _is_resolution_step_current(
	instance: Object,
	requesting_architecture: GFArchitecture,
	owner_lifecycle_generation: int,
	requester_lifecycle_generation: int,
	resolution_context: Dictionary
) -> bool:
	return (
		_instance_is_live(instance)
		and not _resolution_context_has_failed(resolution_context)
		and _is_admission_guard_current(
			requesting_architecture,
			owner_lifecycle_generation,
			requester_lifecycle_generation
		)
	)


## 按顺序调用实例实现的依赖作用域和注入入口，并在每次调用后复核解析状态。
## [br]
## @api private
func _inject_if_needed(
	instance: Object,
	architecture: GFArchitecture,
	requesting_architecture: GFArchitecture,
	owner_lifecycle_generation: int,
	requester_lifecycle_generation: int,
	resolution_context: Dictionary
) -> bool:
	if instance == null or architecture == null:
		return false

	if instance.has_method("_gf_set_dependency_scope"):
		instance.call("_gf_set_dependency_scope", architecture)
		if not _is_resolution_step_current(
			instance,
			requesting_architecture,
			owner_lifecycle_generation,
			requester_lifecycle_generation,
			resolution_context
		):
			return false
	if instance.has_method("inject_dependencies"):
		instance.call("inject_dependencies", architecture)
		if not _is_resolution_step_current(
			instance,
			requesting_architecture,
			owner_lifecycle_generation,
			requester_lifecycle_generation,
			resolution_context
		):
			return false
	if instance.has_method("inject"):
		instance.call("inject", architecture)
		if not _is_resolution_step_current(
			instance,
			requesting_architecture,
			owner_lifecycle_generation,
			requester_lifecycle_generation,
			resolution_context
		):
			return false
	return true


## 检查 Object 仍有效，且 Node 尚未排队删除。
## [br]
## @api private
func _instance_is_live(instance: Object) -> bool:
	if not is_instance_valid(instance):
		return false
	if instance is Node:
		var node: Node = instance
		return not node.is_queued_for_deletion()
	return true


## 依次调用仍存活实例的依赖释放与框架作用域解绑入口；每次用户回调后重新检查对象，避免对已释放实例继续调用。
## [br]
## @api private
func _release_instance_scope(instance: Object) -> void:
	if instance == null or not is_instance_valid(instance):
		return

	if instance.has_method("release_dependencies"):
		var _release_dependencies_result: Variant = instance.call("release_dependencies")
	if not _instance_is_live(instance):
		return
	if instance.has_method("_gf_set_dependency_scope"):
		instance.call("_gf_set_dependency_scope", null)
	elif instance.has_method("_release_dependency_scope"):
		instance.call("_release_dependency_scope")


## 按绑定所有权处置被拒工厂实例，可先注销事件并释放已注入作用域；仅对需要销毁且无父节点的未排队 Node 直接 free，外部所有权实例不强制销毁。
## [br]
## @api private
func _release_rejected_factory_instance(
	instance: Object,
	release_injected_scope: bool = true,
	injection_architecture: GFArchitecture = null
) -> void:
	if instance == null or not is_instance_valid(instance):
		return

	var injected_scope_architecture: GFArchitecture = injection_architecture
	if injected_scope_architecture == null:
		injected_scope_architecture = _owner_architecture
	if release_injected_scope and injected_scope_architecture != null:
		injected_scope_architecture.unregister_owner_events(instance)
	if (
		_should_dispose_cached_instance
		and is_instance_valid(instance)
		and instance.has_method("dispose")
	):
		instance.call("dispose")
	if release_injected_scope and is_instance_valid(instance):
		_release_instance_scope(instance)
	if not is_instance_valid(instance):
		return
	if _should_dispose_cached_instance and instance is Node:
		var rejected_node: Node = instance
		if rejected_node.get_parent() == null and not rejected_node.is_queued_for_deletion():
			rejected_node.free()


## 在非空解析上下文中设置失败标志。
## [br]
## @api private
func _mark_resolution_context_failed(resolution_context: Dictionary) -> void:
	if resolution_context.is_empty():
		return
	resolution_context[_RESOLUTION_CONTEXT_FAILED_KEY] = true


## 读取解析上下文失败标志；空上下文视为未失败。
## [br]
## @api private
func _resolution_context_has_failed(resolution_context: Dictionary) -> bool:
	if resolution_context.is_empty():
		return false
	var failed_value: Variant = resolution_context.get(_RESOLUTION_CONTEXT_FAILED_KEY, false)
	return failed_value == true


## 将当前 Binding 与新建实例作为一项记录附加到解析上下文的 Singleton 数组。
## [br]
## @api private
func _register_created_singleton_in_resolution_context(resolution_context: Dictionary, instance: Object) -> void:
	if resolution_context.is_empty() or instance == null:
		return

	var created_value: Variant = resolution_context.get(_RESOLUTION_CONTEXT_CREATED_SINGLETONS_KEY, [])
	if not created_value is Array:
		return
	var created_singletons: Array = created_value
	created_singletons.append({
		_RESOLUTION_CONTEXT_BINDING_KEY: self,
		_RESOLUTION_CONTEXT_INSTANCE_KEY: instance,
	})
	resolution_context[_RESOLUTION_CONTEXT_CREATED_SINGLETONS_KEY] = created_singletons


## 检查缓存实例有效，且若为 Node 则未排队删除。
## [br]
## @api private
func _cached_instance_is_valid() -> bool:
	if not is_instance_valid(_cached_instance):
		return false
	if _cached_instance is Node:
		var cached_node: Node = _cached_instance
		if cached_node.is_queued_for_deletion():
			return false
	return true


## 当绑定键为 Script 时，检查实例脚本与该类型相同或继承自该类型。
## [br]
## @api private
func _instance_matches_key(instance: Object) -> bool:
	if not key is Script:
		return true

	var instance_script: Script = _get_instance_script(instance)
	if instance_script == null:
		return false

	var key_script: Script = key
	return _SCRIPT_TYPE_INSPECTOR.script_extends_or_equals(instance_script, key_script)


## 读取实例的 Script；实例为空或脚本类型不符时返回 null。
## [br]
## @api private
func _get_instance_script(instance: Object) -> Script:
	if instance == null:
		return null
	var raw_script: Variant = instance.get_script()
	if raw_script is Script:
		var script: Script = raw_script
		return script
	return null
