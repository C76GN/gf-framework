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
const _SCRIPT_TYPE_INSPECTOR = preload("res://addons/gf/kernel/core/gf_script_type_inspector.gd")
const _RESOLUTION_CONTEXT_BINDING_KEY: String = "binding"
const _RESOLUTION_CONTEXT_CREATED_SINGLETONS_KEY: String = "created_singletons"
const _RESOLUTION_CONTEXT_FAILED_KEY: String = "failed"
const _RESOLUTION_CONTEXT_INSTANCE_KEY: String = "instance"


# --- 公共变量 ---

## 绑定键，通常为脚本类型。
## [br]
## @api framework_internal
## [br]
## @schema key {
##   "type": "Variant",
##   "description": "通常为 Script 类型，也可由内部绑定实现扩展。"
## }
var key: Variant

## 绑定来源，可以是 Callable 工厂或 Object 实例。
## [br]
## @api framework_internal
## [br]
## @schema provider {
##   "type": "Variant",
##   "description": "Callable 工厂或 Object 实例。"
## }
var provider: Variant

## 生命周期策略。
## [br]
## @api framework_internal
var lifetime: int = GFBindingLifetimesBase.Lifetime.TRANSIENT


# --- 私有变量 ---

var _owner_architecture: GFArchitecture = null
var _cached_instance: Object = null
var _has_cached_instance: bool = false
var _should_auto_inject: bool = true
var _should_dispose_cached_instance: bool = true
var _is_resolving_singleton: bool = false


# --- Godot 生命周期方法 ---

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
## @schema resolution_context {
##   "type": "Dictionary",
##   "description": "GFArchitecture 内部维护的解析上下文。"
## }
## [br]
## @return 解析出的 Object 实例；失败时返回 null。
func get_instance(requesting_architecture: GFArchitecture = null, resolution_context: Dictionary = {}) -> Object:
	match lifetime:
		GFBindingLifetimesBase.Lifetime.SINGLETON:
			if _has_cached_instance and _cached_instance_is_valid():
				return _cached_instance
			if _is_resolving_singleton:
				_mark_resolution_context_failed(resolution_context)
				push_error("[GFBinding] Singleton 工厂正在解析中，检测到循环依赖。")
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
			push_error("[GFBinding] 未知生命周期：%s" % str(lifetime))
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
## @schema instance {
##   "type": "Object",
##   "description": "失败解析链路中创建的 Singleton 实例。"
## }
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
		push_error("[GFBinding] 绑定来源返回了已失效的 Object 实例。")
		return null
	if not value is Object:
		if _resolution_context_has_failed(resolution_context):
			return null
		_mark_resolution_context_failed(resolution_context)
		push_error("[GFBinding] 绑定来源必须返回 Object 实例。")
		return null

	var instance: Object = value
	if not _instance_is_live(instance):
		_mark_resolution_context_failed(resolution_context)
		push_error("[GFBinding] 绑定来源返回了已失效的 Object 实例。")
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
		push_error("[GFBinding] 绑定来源返回的实例脚本必须继承或等于绑定键。")
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


func _get_admitted_lifecycle_generation(
	architecture: GFArchitecture
) -> int:
	if (
		architecture == null
		or not architecture.is_accepting_runtime_work()
	):
		return -1
	return architecture.get_lifecycle_generation()


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


func _instance_is_live(instance: Object) -> bool:
	if not is_instance_valid(instance):
		return false
	if instance is Node:
		var node: Node = instance
		return not node.is_queued_for_deletion()
	return true


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


func _mark_resolution_context_failed(resolution_context: Dictionary) -> void:
	if resolution_context.is_empty():
		return
	resolution_context[_RESOLUTION_CONTEXT_FAILED_KEY] = true


func _resolution_context_has_failed(resolution_context: Dictionary) -> bool:
	if resolution_context.is_empty():
		return false
	var failed_value: Variant = resolution_context.get(_RESOLUTION_CONTEXT_FAILED_KEY, false)
	return failed_value == true


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


func _cached_instance_is_valid() -> bool:
	if not is_instance_valid(_cached_instance):
		return false
	if _cached_instance is Node:
		var cached_node: Node = _cached_instance
		if cached_node.is_queued_for_deletion():
			return false
	return true


func _instance_matches_key(instance: Object) -> bool:
	if not key is Script:
		return true

	var instance_script: Script = _get_instance_script(instance)
	if instance_script == null:
		return false

	var key_script: Script = key
	return _SCRIPT_TYPE_INSPECTOR.script_extends_or_equals(instance_script, key_script)


func _get_instance_script(instance: Object) -> Script:
	if instance == null:
		return null
	var raw_script: Variant = instance.get_script()
	if raw_script is Script:
		var script: Script = raw_script
		return script
	return null
