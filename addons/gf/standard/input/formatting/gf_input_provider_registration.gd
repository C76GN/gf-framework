## GFInputProviderRegistration: 输入格式化 provider 注册句柄。
##
## 由 GFInputFormatterRegistry 返回，用于显式释放一次 provider 注册。
## 句柄只管理注册生命周期，不拥有 provider 的业务语义。
## [br]
## @api public
## [br]
## @category runtime_handle
## [br]
## @since 8.0.0
## [br]
## @layer standard/input
class_name GFInputProviderRegistration
extends RefCounted


# --- 公共变量 ---

## Provider 类型。
## [br]
## @api public
## [br]
## @since 8.0.0
var provider_kind: StringName = &""

## 已注册 provider。
## [br]
## @api public
## [br]
## @since 8.0.0
var provider: Resource = null


# --- 私有变量 ---

var _registry_ref: WeakRef = null
var _active: bool = false


# --- 公共方法 ---

## 检查注册是否仍处于活动状态。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @return 活动返回 true。
func is_active() -> bool:
	return _active and provider != null and _get_registry() != null


## 释放注册。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @return 本次调用确实释放了注册时返回 true。
func release() -> bool:
	if not _active:
		return false

	var registry: GFInputFormatterRegistry = _get_registry()
	if registry == null:
		mark_released()
		return false

	return registry.release_registration(self)


# --- 框架内部方法 ---

## 绑定注册句柄到 registry。
## [br]
## @api framework_internal
## [br]
## @layer standard/input
## [br]
## @param registry: 创建注册的 registry。
## [br]
## @param p_provider_kind: Provider 类型。
## [br]
## @param p_provider: Provider 资源。
func setup_from_registry(
	registry: GFInputFormatterRegistry,
	p_provider_kind: StringName,
	p_provider: Resource
) -> void:
	_registry_ref = weakref(registry) if registry != null else null
	provider_kind = p_provider_kind
	provider = p_provider
	_active = registry != null and p_provider != null


## 标记注册已释放。
## [br]
## @api framework_internal
## [br]
## @layer standard/input
func mark_released() -> void:
	_active = false
	_registry_ref = null
	provider = null


# --- 私有/辅助方法 ---

func _get_registry() -> GFInputFormatterRegistry:
	if _registry_ref == null:
		return null
	var registry_value: Object = _registry_ref.get_ref()
	if registry_value is GFInputFormatterRegistry:
		var registry: GFInputFormatterRegistry = registry_value
		return registry
	return null
