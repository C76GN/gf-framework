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
var _resolution_cycle_detected: bool = false


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


# --- 公共方法 ---

## 按当前生命周期解析实例。
## [br]
## @api framework_internal
## [br]
## @param requesting_architecture: 发起解析的架构。Transient 会优先注入它，Singleton 始终注入拥有该绑定的架构。
## [br]
## @return 解析出的 Object 实例；失败时返回 null。
func get_instance(requesting_architecture: GFArchitecture = null) -> Object:
	match lifetime:
		GFBindingLifetimesBase.Lifetime.SINGLETON:
			if _has_cached_instance and _cached_instance_is_valid():
				return _cached_instance
			if _is_resolving_singleton:
				_resolution_cycle_detected = true
				push_error("[GFBinding] Singleton 工厂正在解析中，检测到循环依赖。")
				return null

			clear_cached_instance()
			_is_resolving_singleton = true
			_resolution_cycle_detected = false
			var provided_instance: Object = _provide(_owner_architecture)
			_is_resolving_singleton = false
			if _resolution_cycle_detected:
				_resolution_cycle_detected = false
				return null
			if provided_instance == null:
				return null

			_cached_instance = provided_instance
			_has_cached_instance = true
			return _cached_instance

		GFBindingLifetimesBase.Lifetime.TRANSIENT:
			var injection_architecture: GFArchitecture = requesting_architecture
			if injection_architecture == null:
				injection_architecture = _owner_architecture
			return _provide(injection_architecture)

		_:
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
		_release_instance_scope(instance)


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

func _provide(injection_architecture: GFArchitecture) -> Object:
	var value: Variant
	if provider is Callable:
		var provider_callable: Callable = provider
		value = provider_callable.call()
	else:
		value = provider

	if not value is Object:
		if _resolution_cycle_detected:
			return null
		push_error("[GFBinding] 绑定来源必须返回 Object 实例。")
		return null

	var instance: Object = value
	if not is_instance_valid(instance):
		push_error("[GFBinding] 绑定来源返回了已失效的 Object 实例。")
		return null
	if not _instance_matches_key(instance):
		push_error("[GFBinding] 绑定来源返回的实例脚本必须继承或等于绑定键。")
		return null

	if _should_auto_inject:
		_inject_if_needed(instance, injection_architecture)

	return instance


func _inject_if_needed(instance: Object, architecture: GFArchitecture) -> void:
	if instance == null or architecture == null:
		return

	if instance.has_method("_gf_set_dependency_scope"):
		instance.call("_gf_set_dependency_scope", architecture)
	if instance.has_method("inject_dependencies"):
		instance.call("inject_dependencies", architecture)
	if instance.has_method("inject"):
		instance.call("inject", architecture)


func _release_instance_scope(instance: Object) -> void:
	if instance == null or not is_instance_valid(instance):
		return

	if instance.has_method("release_dependencies"):
		var _release_dependencies_result: Variant = instance.call("release_dependencies")
	if instance.has_method("_gf_set_dependency_scope"):
		instance.call("_gf_set_dependency_scope", null)
	elif instance.has_method("_release_dependency_scope"):
		instance.call("_release_dependency_scope")


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
