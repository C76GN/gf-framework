## GFBindBuilder: 声明式装配链，用于把脚本绑定为模块或短生命周期工厂。
## [br]
## @api public
## [br]
## @category protocol
## [br]
## @since 3.17.0
class_name GFBindBuilder
extends RefCounted


# --- 枚举 ---

## 绑定目标类别。
## [br]
## @api framework_internal
enum TargetKind {
	MODEL,
	SYSTEM,
	UTILITY,
	FACTORY,
}

## 绑定来源类别。
## [br]
## @api framework_internal
enum SourceKind {
	SELF,
	FACTORY,
	INSTANCE,
}


# --- 私有变量 ---

## 绑定生命周期枚举脚本缓存。
## [br]
## @api framework_internal
const GFBindingLifetimesBase = preload("res://addons/gf/kernel/core/gf_binding_lifetimes.gd")

var _architecture: GFArchitecture = null
var _target_kind: TargetKind = TargetKind.FACTORY
var _script_cls: Script = null
var _source_kind: SourceKind = SourceKind.SELF
var _factory: Callable = Callable()
var _instance: Object = null
var _alias_cls: Script = null


# --- Godot 生命周期方法 ---

func _init(architecture: GFArchitecture, target_kind: TargetKind, script_cls: Script) -> void:
	_architecture = architecture
	_target_kind = target_kind
	_script_cls = script_cls


# --- 公共方法 ---

## 使用 Callable 作为绑定来源。
## [br]
## @api public
## [br]
## @param factory: 返回 Object 实例的工厂。
## [br]
## @return 当前 Builder，便于继续声明生命周期。
func from_factory(factory: Callable) -> GFBindBuilder:
	_source_kind = SourceKind.FACTORY
	_factory = factory
	return self


## 使用已有实例作为绑定来源。
## [br]
## @api public
## [br]
## @param instance: 要注册或暴露的实例。
## [br]
## @return 当前 Builder，便于继续声明生命周期。
func from_instance(instance: Object) -> GFBindBuilder:
	_source_kind = SourceKind.INSTANCE
	_instance = instance
	return self


## 额外登记一个查询别名。仅对 Model/System/Utility 有效。
## [br]
## @api public
## [br]
## @param alias_cls: 调用 get_* 时使用的抽象脚本类型。
## [br]
## @return 当前 Builder，便于继续声明生命周期。
func with_alias(alias_cls: Script) -> GFBindBuilder:
	if _target_kind == TargetKind.FACTORY:
		push_warning("[GFBindBuilder] with_alias() 仅对 Model/System/Utility 有效，Factory 绑定会忽略 alias。")
		return self
	_alias_cls = alias_cls
	return self


## 以单例语义完成绑定。
## [br]
## @api public
## [br]
## @since 5.0.0
## [br]
## @return 绑定成功时返回 true。
func as_singleton() -> bool:
	if _architecture == null:
		push_error("[GFBindBuilder] 架构为空，无法完成绑定。")
		return false

	if _target_kind == TargetKind.FACTORY:
		return _bind_factory(GFBindingLifetimesBase.Lifetime.SINGLETON)

	var instance: Object = _create_instance_from_source()
	if instance == null:
		return false

	var registered: bool = await _register_lifecycle_instance(instance)
	if not registered:
		return false
	return _register_alias_if_needed(instance)


## 以瞬态语义完成绑定。仅短生命周期工厂支持 transient。
## [br]
## @api public
## [br]
## @since 5.0.0
## [br]
## @return 绑定成功时返回 true。
func as_transient() -> bool:
	if _architecture == null:
		push_error("[GFBindBuilder] 架构为空，无法完成绑定。")
		return false

	if _target_kind != TargetKind.FACTORY:
		push_error("[GFBindBuilder] Model/System/Utility 是生命周期模块，不支持 as_transient()；请改用 bind_factory()。")
		return false

	return _bind_factory(GFBindingLifetimesBase.Lifetime.TRANSIENT)


# --- 私有/辅助方法 ---

func _create_instance_from_source() -> Object:
	match _source_kind:
		SourceKind.SELF:
			if _script_cls == null or not _script_cls.can_instantiate():
				push_error("[GFBindBuilder] SELF 绑定需要可实例化的脚本类型。")
				return null
			return _instantiate_script_as_object(_script_cls)

		SourceKind.FACTORY:
			if not _factory.is_valid():
				push_error("[GFBindBuilder] from_factory() 收到无效 Callable。")
				return null
			var value: Variant = _factory.call()
			if not value is Object:
				push_error("[GFBindBuilder] from_factory() 必须返回 Object 实例。")
				return null
			var instance: Object = value
			return instance

		SourceKind.INSTANCE:
			if _instance == null:
				push_error("[GFBindBuilder] from_instance() 收到空实例。")
				return null
			return _instance

		_:
			return null


func _register_lifecycle_instance(instance: Object) -> bool:
	match _target_kind:
		TargetKind.MODEL:
			return await _architecture.register_model_instance(instance)

		TargetKind.SYSTEM:
			return await _architecture.register_system_instance(instance)

		TargetKind.UTILITY:
			return await _architecture.register_utility_instance(instance)
	return false


func _register_alias_if_needed(instance: Object) -> bool:
	if _alias_cls == null or instance == null:
		return true

	var script: Script = _get_instance_script(instance)
	if script == null:
		return false

	match _target_kind:
		TargetKind.MODEL:
			_architecture.register_model_alias(_alias_cls, script)
			return true

		TargetKind.SYSTEM:
			_architecture.register_system_alias(_alias_cls, script)
			return true

		TargetKind.UTILITY:
			_architecture.register_utility_alias(_alias_cls, script)
			return true
	return false


func _bind_factory(lifetime: int) -> bool:
	match _source_kind:
		SourceKind.SELF:
			if _script_cls == null or not _script_cls.can_instantiate():
				push_error("[GFBindBuilder] bind_factory() 需要可实例化的脚本类型。")
				return false
			var self_factory: Callable = func() -> Object:
				return _instantiate_script_as_object(_script_cls)
			return _architecture.register_factory(_script_cls, self_factory, lifetime)

		SourceKind.FACTORY:
			return _architecture.register_factory(_script_cls, _factory, lifetime)

		SourceKind.INSTANCE:
			if lifetime == GFBindingLifetimesBase.Lifetime.TRANSIENT:
				push_error("[GFBindBuilder] from_instance() 不支持 as_transient()；请改用 from_factory()。")
				return false
			return _architecture.register_factory_instance(_script_cls, _instance)
	return false


func _get_instance_script(instance: Object) -> Script:
	if instance == null:
		return null
	var raw_script: Variant = instance.get_script()
	if raw_script is Script:
		var script: Script = raw_script
		return script
	return null


func _instantiate_script_as_object(script_cls: Script) -> Object:
	if script_cls == null:
		return null
	var raw_instance: Variant = script_cls.call("new")
	if raw_instance is Object:
		var instance: Object = raw_instance
		return instance
	return null
